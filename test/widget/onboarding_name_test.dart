import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/data/models/app_user.dart';
import 'package:lernova/data/models/user_progress.dart';
import 'package:lernova/features/onboarding/application/user_controller.dart';
import 'package:lernova/main.dart';

Future<LocalStorageService> _storage(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return LocalStorageService.create();
}

Future<void> _boot(WidgetTester tester, LocalStorageService storage) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      child: const LernovaApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
  // Bounded, not pumpAndSettle: booting straight into Home shows its
  // shimmering skeletons while the course catalogue loads, and a
  // repeating animation never settles.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('first-time onboarding', () {
    testWidgets('asks for a name, and will not continue without one', (tester) async {
      final storage = await _storage({});
      await _boot(tester, storage);

      // Welcome -> explainer -> name.
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      // The explainer is a carousel; its CTA advances to the last slide.
      for (var i = 0; i < 6; i++) {
        final cta = find.byType(ElevatedButton);
        if (find.text("What's your name?").evaluate().isNotEmpty) break;
        if (cta.evaluate().isEmpty) break;
        await tester.tap(cta.last);
        await tester.pumpAndSettle();
      }

      expect(find.text("What's your name?"), findsOneWidget);
      expect(find.text('Enter your full name'), findsOneWidget);

      // An empty name is refused, with a reason.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name to continue.'), findsOneWidget);
      expect(find.text("What's your name?"), findsOneWidget, reason: 'still on the name step');

      // Whitespace alone is still empty.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("What's your name?"), findsOneWidget);

      // A real name moves on.
      await tester.enterText(find.byType(TextField), '  Ada Lovelace ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("What's your name?"), findsNothing);
    });
  });

  group('returning learners', () {
    testWidgets('are never asked again once a name is stored', (tester) async {
      final now = DateTime.now();
      final user = AppUser(
        id: 'local',
        name: 'Ada Lovelace',
        email: '',
        avatarSeed: 'Ada Lovelace',
        joinedAt: now,
        selectedLanguageId: 'es',
        currentCourseId: 'course_es',
      );
      final storage = await _storage({
        'lernova.user.local': jsonEncode(user.toJson()),
        'lernova.progress.local':
            jsonEncode(UserProgress.initial(weekId: '2026-W01').toJson()),
        'lernova.onboarding_complete.local': true,
        'lernova.active_account_id': 'local',
      });

      await _boot(tester, storage);

      expect(find.text("What's your name?"), findsNothing);
      // Straight into the app, greeted by name.
      expect(find.textContaining('Ada'), findsWidgets);
    });

    // Someone who finished onboarding before the name step existed is
    // still on the placeholder profile name. They get the one screen —
    // not the whole flow again, which would discard the language, goal
    // and placement they already chose.
    testWidgets('with only the placeholder name are asked once, not re-onboarded',
        (tester) async {
      final now = DateTime.now();
      final user = AppUser(
        id: 'local',
        name: 'Learner',
        email: '',
        avatarSeed: 'Learner',
        joinedAt: now,
        selectedLanguageId: 'es',
        currentCourseId: 'course_es',
      );
      final storage = await _storage({
        'lernova.user.local': jsonEncode(user.toJson()),
        'lernova.progress.local':
            jsonEncode(UserProgress.initial(weekId: '2026-W01').toJson()),
        'lernova.onboarding_complete.local': true,
        'lernova.active_account_id': 'local',
      });

      await _boot(tester, storage);

      expect(find.text("What's your name?"), findsOneWidget);
      // Not the rest of onboarding.
      expect(find.text('Choose a language'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Grace Hopper');
      await tester.pump();
      await tester.tap(find.text('Save'));
      // Bounded pumps, not pumpAndSettle: Home animates continuously
      // (mascot, textured backdrop) and never reaches a settled frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text("What's your name?"), findsNothing);
      expect(storage.loadUser()!.name, 'Grace Hopper');
    });
  });

  group('hasRealName', () {
    test('the placeholder profile name does not count as a name', () {
      AppUser withName(String name) => AppUser(
            id: 'local',
            name: name,
            email: '',
            avatarSeed: name,
            joinedAt: DateTime.now(),
          );

      expect(UserController.hasRealName(withName('Learner')), isFalse);
      expect(UserController.hasRealName(withName('')), isFalse);
      expect(UserController.hasRealName(withName('   ')), isFalse);
      expect(UserController.hasRealName(withName('Ada')), isTrue);
    });
  });
}

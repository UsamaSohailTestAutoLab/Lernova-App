import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/main.dart';

void main() {
  testWidgets(
    'Path tab: renders lesson nodes, opens the free one, and sells the rest',
    (tester) async {
      final now = DateTime.now();
      final user = AppUser(
        id: 'u1',
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        avatarSeed: 'Ada Lovelace',
        joinedAt: now,
        selectedLanguageId: 'es',
        currentCourseId: 'course_es',
      );
      final progress = UserProgress.initial(weekId: '2026-W01');

      SharedPreferences.setMockInitialValues({
        'lernova.user': jsonEncode(user.toJson()),
        'lernova.progress': jsonEncode(progress.toJson()),
        'lernova.onboarding_complete': true,
      });
      final storage = await LocalStorageService.create();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: const LingoQuestApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Path'));
      await tester.pumpAndSettle();

      expect(find.text('Your path'), findsOneWidget);
      expect(find.text('Greetings & Basics'), findsOneWidget);
      // A fresh account's very first lesson is the "current" node.
      expect(find.text('Say Hello'), findsOneWidget);

      // Everything past "Say Hello" is behind the subscription, so a tap
      // opens the paywall rather than a lesson. warnIfMissed: false — the
      // node sits under nested Transforms (the dx offset, and the shake a
      // progression-locked node still uses), which makes flutter_test's
      // own "did we really hit that RenderParagraph" check unreliable
      // even though the tap does reach the node's GestureDetector.
      await tester.tap(find.text('Yes, No, Sorry'), warnIfMissed: false);
      // Bounded pumps, not pumpAndSettle: the Pro screen's mascot
      // animates continuously and would never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('Learn without limits'), findsOneWidget);

      // Back to the path.
      await tester.tap(find.byType(BackButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Your path'), findsOneWidget);

      // The one free lesson opens the lesson itself.
      await tester.tap(find.text('Say Hello'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Your path'), findsNothing);
      expect(find.textContaining('Learn without limits'), findsNothing);
    },
  );
}

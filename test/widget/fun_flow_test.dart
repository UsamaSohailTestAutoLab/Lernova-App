import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/core/widgets/lingoquest_parrot.dart';
import 'package:lingoquest/features/fun/presentation/widgets/water_bubble.dart';
import 'package:lingoquest/main.dart';

void main() {
  testWidgets(
    'Fun tab: hub renders both flagship games, and a round loads with real playable content',
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

      // Splash resolves straight to Home since onboarding is already done.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Bottom nav -> Fun tab.
      await tester.tap(find.text('Fun'));
      await tester.pumpAndSettle();

      expect(find.text('Fun Zone'), findsOneWidget);
      // The hub previously had no mascot at all; it now carries the same
      // one used on Home, Welcome, Splash and Settings.
      expect(find.byType(LingoQuestParrot), findsOneWidget);
      expect(find.text('Word Bubble'), findsOneWidget);
      expect(find.text('Word Rush'), findsOneWidget);
      // Country Challenge was removed — it should not appear at all.
      expect(find.text('Country Challenge'), findsNothing);

      // Enter the flagship falling-words game.
      await tester.tap(find.text('Word Bubble'));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Vocabulary preview step: swipe/tap through every word card until
      // the final "Start Level" CTA appears, then continue into gameplay.
      expect(find.text('Review Words'), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        final forwardButton = find.byIcon(Icons.arrow_forward_rounded);
        if (forwardButton.evaluate().isEmpty) break;
        await tester.tap(forwardButton);
        await tester.pumpAndSettle();
      }
      expect(find.text('Start Level'), findsOneWidget);
      await tester.tap(find.text('Start Level'));
      // Bounded pump: enough to build the gameplay screen and kick off
      // the fall animation, but not enough to let pumpAndSettle simulate
      // the full multi-second fall through to a timeout.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Word Bubble goes straight from the review step into bubbles.
      // The rising-water explainer belongs to Word Survival now, and
      // must not stand in the way of the first game a player opens.
      expect(find.text('Watch out! 🌊'), findsNothing);

      // Gameplay screen: 3 lives showing, and real falling answer bubbles
      // generated from the bundled Fun vocabulary content.
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
      expect(find.byType(WaterBubble), findsWidgets);

      // Let the round's fall animation run to completion, then drain the
      // mood-reset timer it schedules, so nothing is left pending when
      // the test ends.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

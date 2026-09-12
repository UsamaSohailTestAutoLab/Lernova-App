import 'dart:convert';

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
    'Path tab: renders lesson nodes, marks the current one, and blocks locked taps',
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

      // A locked node (nothing completed yet) must not navigate anywhere
      // when tapped — no crash, no route change, just haptic + a snackbar.
      // warnIfMissed: false — the node sits under nested Transforms (the
      // dx offset + the locked-tap shake), which makes flutter_test's own
      // "did we really hit that RenderParagraph" sanity check unreliable
      // even though the tap correctly reaches the node's GestureDetector
      // (proven below: tapping the current node does navigate).
      await tester.tap(find.text('Yes, No, Sorry'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your path'), findsOneWidget);

      // The playable current lesson does open.
      await tester.tap(find.text('Say Hello'));
      await tester.pumpAndSettle();
      expect(find.text('Your path'), findsNothing);
    },
  );
}

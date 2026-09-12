import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/last_activity.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/main.dart';

/// Deliberately its own file, and a single test.
///
/// This one actually navigates into the Fun game's intro screen, which
/// leaves enough asynchronous work running that a following test in the
/// same isolate can no longer reach a settled frame. `flutter test` runs
/// each file in its own isolate, so isolating it here keeps the suite
/// deterministic without giving up the assertion that matters most:
/// that the button really does land on the Fun game.
void main() {
  testWidgets('Continue learning opens the Fun game, not a lesson', (tester) async {
    final user = AppUser(
      id: 'u1',
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      avatarSeed: 'Ada Lovelace',
      joinedAt: DateTime.now(),
      selectedLanguageId: 'es',
      currentCourseId: 'course_es',
    );
    final progress = UserProgress.initial(weekId: '2026-W01').copyWith(
      lastActivity: LastActivity.funGame(
        at: DateTime.now(),
        funModeName: 'fallingWords',
        funLevel: 3,
        title: 'Word Bubble',
        subtitle: 'Level 3',
      ),
    );

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

    // The card sits below the fold on the default test viewport.
    await tester.ensureVisible(find.text('Continue learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue learning'));
    await tester.pumpAndSettle();

    // The Fun game's intro, not a lesson intro.
    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('Word Bubble'), findsWidgets);
    expect(find.text('Start lesson'), findsNothing);
  });
}

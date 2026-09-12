import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/data/repositories/content_providers.dart';
import 'package:lingoquest/features/fun/application/fun_progress_controller.dart';
import 'package:lingoquest/features/languages/application/language_switch_controller.dart';
import 'package:lingoquest/features/languages/presentation/language_switch_screen.dart';
import 'package:lingoquest/features/onboarding/application/user_controller.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';

/// Spanish, three lessons in and partway through Unit 2 — the state the
/// learner must find waiting for them when they come back.
UserProgress _spanishInProgress() =>
    UserProgress.initial(weekId: '2026-W37').copyWith(
      activeLanguageId: 'es',
      totalXp: 900,
      streakCount: 7,
      unlockedUnitIndex: 1,
      completedLessonIds: {'es_u1_l1', 'es_u1_l2', 'es_u1_l3'},
      totalLessonsCompleted: 3,
      vocabStrength: {'es_hola': 4},
    );

Future<ProviderContainer> _pumpScreen(WidgetTester tester) async {
  final user = AppUser(
    id: 'local',
    name: 'Ada Lovelace',
    email: '',
    avatarSeed: 'Ada Lovelace',
    joinedAt: DateTime(2026, 1, 1),
    selectedLanguageId: 'es',
    currentCourseId: 'course_es',
  );

  SharedPreferences.setMockInitialValues({
    'lernova.active_account_id': 'local',
    'lernova.user.local': jsonEncode(user.toJson()),
    'lernova.progress.local': jsonEncode(_spanishInProgress().toJson()),
    'lernova.onboarding_complete.local': true,
  });
  // `SharedPreferences.getInstance()` goes through a platform channel:
  // real I/O, which only resolves under `runAsync`. Awaiting it directly
  // in the test body works for whichever test happens to run first and
  // then hangs for the rest.
  late final LocalStorageService storage;
  await tester.runAsync(() async {
    storage = await LocalStorageService.create();
  });

  final router = GoRouter(
    initialLocation: '/languages',
    routes: [
      GoRoute(
        path: '/languages',
        builder: (context, state) => const LanguageSwitchScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );

  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);

  // Content is read off the asset bundle, which is real I/O that `pump`
  // cannot advance — it only moves fake time. Everything the screen and
  // the switch itself will await is resolved here under `runAsync`, so
  // that afterwards each await lands on a future that has already
  // completed and a pumped frame is enough to carry it.
  await tester.runAsync(() async {
    final summaries = await container.read(languageSummariesProvider.future);
    for (final summary in summaries) {
      await container.read(courseByLanguageProvider(summary.language.id).future);
    }
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  // Bounded rather than pumpAndSettle: the parrot header animates
  // continuously, so a settled frame never arrives.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return container;
}

/// Lets the widget tree rebuild *and* real asynchronous work finish.
///
/// Switching language writes the profile through SharedPreferences,
/// which is a platform channel: fake time cannot advance it, so pumping
/// alone leaves the await hanging forever.
Future<void> _settleWithIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the list shows every language and which one is active',
      (tester) async {
    await _pumpScreen(tester);

    // The active language leads the list, so these are the cards above
    // the fold; the full set of ten is asserted through the provider in
    // the last test rather than by scrolling.
    for (final name in ['Spanish', 'French', 'German']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Learning now'), findsOneWidget);
    // Spanish is three lessons in; the rest have never been opened.
    expect(find.text('Not started'), findsWidgets);

    // A list of languages does not say what tapping one does, so the
    // screen has to: a banner naming the action, and section headings
    // that separate "what I am on" from "what I can move to".
    expect(find.text('Switch your language here'), findsOneWidget);
    expect(find.text('Currently learning'), findsOneWidget);
    expect(find.text('Switch to another language'), findsOneWidget);
  });

  testWidgets('switching parks Spanish and starts French from the beginning',
      (tester) async {
    final container = await _pumpScreen(tester);

    await tester.tap(find.text('French'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The confirmation says what will happen before anything moves.
    expect(find.text('Learn French?'), findsOneWidget);
    expect(
      find.textContaining('Your current progress is saved'),
      findsOneWidget,
    );

    await tester.tap(find.text('Start'));
    await _settleWithIo(tester);

    final progress = container.read(progressProvider);
    expect(container.read(userProvider).selectedLanguageId, 'fr');
    expect(container.read(userProvider).currentCourseId, 'course_fr');

    // French starts clean...
    expect(progress.activeLanguageId, 'fr');
    expect(progress.completedLessonIds, isEmpty);
    expect(progress.unlockedUnitIndex, 0);
    expect(progress.vocabStrength, isEmpty);

    // ...Spanish is kept intact...
    final spanish = progress.sliceForLanguage('es');
    expect(spanish.completedLessonIds, hasLength(3));
    expect(spanish.unlockedUnitIndex, 1);
    expect(spanish.streakCount, 7);
    expect(spanish.xpEarned, 900);

    expect(progress.totalXp, 0, reason: 'French has earned nothing yet');
    expect(progress.streakCount, 0);

    // ...and the account's hearts are untouched.
    expect(progress.hearts, greaterThan(0));
  });

  testWidgets('Fun levels are kept per language too', (tester) async {
    final container = await _pumpScreen(tester);

    container
        .read(funProgressProvider.notifier)
        .debugUnlockAllFunLevels(level: 6);
    expect(container.read(funProgressProvider).levelFor('fallingWords'), 6);

    await tester.tap(find.text('German'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start'));
    await _settleWithIo(tester);

    // German has its own vocabulary, so it starts at level 1 rather than
    // inheriting a level earned against Spanish words.
    expect(container.read(funProgressProvider).levelFor('fallingWords'), 1);
  });

  testWidgets('every listed language actually has a course to open',
      (tester) async {
    final container = await _pumpScreen(tester);

    // Already resolved by the helper, so read the value rather than
    // awaiting a future the fake clock will not advance.
    final summaries = container.read(languageSummariesProvider).requireValue;
    expect(summaries, hasLength(10));
    for (final summary in summaries) {
      expect(summary.isAvailable, isTrue, reason: summary.language.name);
      expect(summary.totalLessons, greaterThanOrEqualTo(9),
          reason: summary.language.name);
    }
  });
}

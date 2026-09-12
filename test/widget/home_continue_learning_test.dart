import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/fun_progress.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/data/models/last_activity.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/data/repositories/content_providers.dart';
import 'package:lingoquest/core/widgets/lingoquest_parrot.dart';
import 'package:lingoquest/core/theme/app_colors.dart';
import 'package:lingoquest/core/widgets/stat_card.dart';
import 'package:lingoquest/features/home/application/motivation_messages.dart';
import 'package:lingoquest/features/home/presentation/home_screen.dart';

Exercise _mc(String id) => Exercise(
      id: id,
      type: ExerciseType.multipleChoice,
      vocabId: 'v_$id',
      payload: const MultipleChoicePayload(
        prompt: 'p',
        options: ['a', 'b'],
        correctIndex: 0,
      ),
    );

final _course = Course(
  id: 'course_es',
  languageId: 'es',
  title: 'Spanish',
  description: '',
  placementQuestions: const [],
  units: [
    CourseUnit(
      id: 'u0',
      title: 'Greetings & Basics',
      description: '',
      lessons: [
        Lesson(id: 'l0', title: 'Say Hello', subtitle: '', exercises: [_mc('e0')]),
      ],
    ),
  ],
);

/// Pumps Home directly rather than booting the whole app.
///
/// A full boot loads the course from a bundled asset, which does not
/// resolve on a second boot inside one test isolate — Home then renders
/// its chrome around an empty body. Overriding the course provider keeps
/// every test in this file honest *and* independent.
Future<void> _pumpHome(
  WidgetTester tester, {
  LastActivity? lastActivity,
  FunProgress? funProgress,
  ThemeData? theme,
}) async {
  final user = AppUser(
    id: 'local',
    name: 'Ada Lovelace',
    email: '',
    avatarSeed: 'Ada Lovelace',
    joinedAt: DateTime(2026, 1, 1),
    selectedLanguageId: 'es',
    currentCourseId: 'course_es',
  );
  final progress = UserProgress.initial(weekId: '2026-W01')
      .copyWith(lastActivity: lastActivity);

  SharedPreferences.setMockInitialValues({
    'lernova.active_account_id': 'local',
    'lernova.user.local': jsonEncode(user.toJson()),
    'lernova.progress.local': jsonEncode(progress.toJson()),
    'lernova.onboarding_complete.local': true,
    if (funProgress != null)
      'lernova.fun_progress.local': jsonEncode(funProgress.toJson()),
  });
  final storage = await LocalStorageService.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        courseByIdProvider('course_es').overrideWith((ref) async => _course),
      ],
      child: MaterialApp(theme: theme ?? AppTheme.light(), home: const HomeScreen()),
    ),
  );

  // Bounded pumps rather than pumpAndSettle: Home runs a continuous
  // animation, so settling never completes (see docs/TESTING.md).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // Regression: the card was hardwired to the Path. Leaving a Fun round
  // and coming Home offered a lesson, with no way back to the game.
  testWidgets('Continue learning offers the Fun game that was left', (tester) async {
    await _pumpHome(
      tester,
      lastActivity: LastActivity.funGame(
        at: DateTime.now(),
        funModeName: 'fallingWords',
        funLevel: 3,
        title: 'Word Bubble',
        subtitle: 'Level 3',
      ),
    );

    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.textContaining('FUN ZONE'), findsOneWidget);
    expect(find.textContaining('Word Bubble'), findsOneWidget);
    // The Path is still one tap away, just not the headline.
    expect(find.textContaining('Or continue the Path'), findsOneWidget);
  });

  testWidgets('Continue learning offers the Path when that was last', (tester) async {
    await _pumpHome(
      tester,
      lastActivity: LastActivity.pathLesson(
        at: DateTime.now(),
        courseId: 'course_es',
        lessonId: 'l0',
        unitIndex: 0,
        lessonIndex: 0,
        title: 'Say Hello',
        subtitle: 'Greetings & Basics',
      ),
    );

    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Say Hello'), findsOneWidget);
    expect(find.textContaining('FUN ZONE'), findsNothing);
    expect(find.textContaining('Or continue the Path'), findsNothing);
  });

  testWidgets('a brand-new learner is pointed at the Path', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Say Hello'), findsOneWidget);
    expect(find.textContaining('FUN ZONE'), findsNothing);
  });

  testWidgets('a Fun mode that no longer exists falls back to the Path', (tester) async {
    await _pumpHome(
      tester,
      lastActivity: LastActivity.funGame(
        at: DateTime.now(),
        funModeName: 'countryChallenge', // removed in an earlier release
        funLevel: 1,
        title: 'Country Challenge',
        subtitle: 'Level 1',
      ),
    );

    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.textContaining('FUN ZONE'), findsNothing);
  });

  // The account level is XP-based and spans both halves of the app, but
  // sitting alone it read as a *Path* level. Both sides are now counted
  // explicitly beside it.
  group('progress tiles', () {
    testWidgets('Path and Fun each get their own count', (tester) async {
      await _pumpHome(tester);

      expect(find.text('Path lessons'), findsOneWidget);
      expect(find.text('Fun levels'), findsOneWidget);
      expect(find.text('XP level'), findsOneWidget);
      expect(find.text('Level'), findsNothing, reason: 'the old ambiguous label');
    });

    testWidgets('a new learner sees zero on both, not a blank', (tester) async {
      await _pumpHome(tester);

      for (final label in ['Path lessons', 'Fun levels']) {
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(StatCard),
        );
        expect(
          find.descendant(of: tile, matching: find.text('0')),
          findsOneWidget,
          reason: '$label should read 0, not be empty',
        );
      }
    });

    testWidgets('cleared Fun levels are counted across modes', (tester) async {
      await _pumpHome(
        tester,
        funProgress: FunProgress.initial().copyWith(
          // On level 3 of one game and level 2 of another: four rounds
          // cleared between them.
          gameLevels: const {'fallingWords': 3, 'wordMatch': 3},
        ),
      );

      final funTile = find.ancestor(
        of: find.text('Fun levels'),
        matching: find.byType(StatCard),
      );
      expect(
        find.descendant(of: funTile, matching: find.text('4')),
        findsOneWidget,
      );
    });
  });

  // Regression: the motivational line was hardcoded to primaryDark
  // (near-black green), which is fine on the card's pale-green wash in
  // light mode but almost invisible once the wash flips to a near-black
  // green in dark mode.
  group('dark mode', () {
    /// The colour the rotating message is actually painted in — located
    /// by its content rather than by counting colours, so it stays exact
    /// as other elements on the card gain their own theming.
    Color? messageColor(WidgetTester tester) {
      final pool = MotivationMessages.forProgress(
        UserProgress.initial(weekId: '2026-W01'),
        courseTitle: 'Spanish',
      );
      for (final line in pool) {
        final finder = find.text(line);
        if (finder.evaluate().isEmpty) continue;
        return tester.widget<Text>(finder).style?.color;
      }
      return null;
    }

    testWidgets('the motivational line switches to a light color', (tester) async {
      await _pumpHome(tester, theme: AppTheme.dark());

      expect(
        messageColor(tester),
        AppColors.green100,
        reason: 'the dark-on-dark color must not survive into dark mode',
      );
    });

    testWidgets('light mode keeps the original dark-on-pale color', (tester) async {
      await _pumpHome(tester, theme: AppTheme.light());

      expect(messageColor(tester), AppColors.primaryDark);
    });

    testWidgets('the greeting heading is gold on dark, deep green on light',
        (tester) async {
      await _pumpHome(tester, theme: AppTheme.dark());
      expect(
        tester.widget<Text>(find.text('Hey Ada!')).style?.color,
        AppColors.goldHeading,
      );

      await _pumpHome(tester, theme: AppTheme.light());
      expect(
        tester.widget<Text>(find.text('Hey Ada!')).style?.color,
        AppColors.primaryDark,
      );
    });
  });

  testWidgets('Home opens with a mascot greeting rather than a wall of numbers',
      (tester) async {
    await _pumpHome(tester);

    expect(find.text('Hey Ada!'), findsOneWidget);
    expect(find.byType(LingoQuestParrot), findsOneWidget);

    // Whichever line it lands on, it is one of the real ones — not a
    // placeholder and not empty.
    final pool = MotivationMessages.forProgress(
      UserProgress.initial(weekId: '2026-W01'),
      courseTitle: 'Spanish',
    );
    expect(
      pool.where((line) => find.text(line).evaluate().isNotEmpty),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}

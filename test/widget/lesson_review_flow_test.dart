import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/features/exercises/application/lesson_session_controller.dart';
import 'package:lingoquest/features/lessons/presentation/lesson_complete_screen.dart';
import 'package:lingoquest/features/lessons/presentation/lesson_review_screen.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';

Exercise _mc(String id, int correctIndex) => Exercise(
      id: id,
      type: ExerciseType.multipleChoice,
      vocabId: 'v_$id',
      payload: MultipleChoicePayload(
        prompt: 'What does “Hola” mean?',
        options: const ['Hello', 'Goodbye'],
        correctIndex: correctIndex,
      ),
    );

Course _course(List<Exercise> exercises) {
  final lesson = Lesson(id: 'l0', title: 'Say Hello', subtitle: '', exercises: exercises);
  return Course(
    id: 'c0',
    languageId: 'es',
    title: 'Spanish',
    description: '',
    placementQuestions: const [],
    units: [CourseUnit(id: 'u0', title: 'Unit', description: '', lessons: [lesson])],
  );
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Widget screen) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
  }

  /// Plays a lesson, getting the first question wrong and the rest right.
  void playWithOneMistake() {
    final course = _course([_mc('e0', 0), _mc('e1', 0)]);
    final controller = container.read(lessonSessionProvider.notifier);
    controller.start(course: course, unitIndex: 0, lesson: course.units[0].lessons[0]);

    controller.submitAnswer(1); // wrong on e0
    controller.continueToNext();
    controller.submitAnswer(0); // right on e1
    controller.continueToNext();
    controller.submitAnswer(0); // right on the e0 retry
    controller.continueToNext();
    controller.finishAndApply();
  }

  /// Burns the whole heart budget on wrong answers.
  void playUntilOutOfHearts() {
    final course = _course([for (var i = 0; i < 8; i++) _mc('e$i', 0)]);
    final controller = container.read(lessonSessionProvider.notifier);
    controller.start(course: course, unitIndex: 0, lesson: course.units[0].lessons[0]);

    while (container.read(progressProvider).hearts > 0) {
      controller.submitAnswer(1);
      controller.continueToNext();
    }
    controller.finishAndApply();
  }

  group('results screen', () {
    testWidgets('a finished lesson with a mistake offers Review mistakes', (tester) async {
      playWithOneMistake();
      await pump(tester, const LessonCompleteScreen());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Lesson complete!'), findsOneWidget);
      expect(find.text('Review mistakes'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    // The whole out-of-hearts experience is now this screen. There is no
    // separate screen, no timer, no ad, no gem refill and no upsell.
    testWidgets('running out of hearts lands on results with Play again', (tester) async {
      playUntilOutOfHearts();
      await pump(tester, const LessonCompleteScreen());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Out of hearts'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
      expect(find.text('Review mistakes'), findsOneWidget);

      for (final banned in [
        'Watch an ad for a free heart',
        'Get unlimited hearts with Premium',
        'Next heart in',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: '"$banned" must be gone');
      }
    });

    testWidgets('a perfect lesson has nothing to review', (tester) async {
      final course = _course([_mc('e0', 0)]);
      final controller = container.read(lessonSessionProvider.notifier);
      controller.start(course: course, unitIndex: 0, lesson: course.units[0].lessons[0]);
      controller.submitAnswer(0);
      controller.continueToNext();
      controller.finishAndApply();

      await pump(tester, const LessonCompleteScreen());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Perfect lesson!'), findsOneWidget);
      expect(find.text('Review mistakes'), findsNothing);
    });
  });

  group('review screen', () {
    testWidgets('shows the answer given next to the answer expected', (tester) async {
      playWithOneMistake();
      await pump(tester, const LessonReviewScreen());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Your answer'), findsOneWidget);
      expect(find.text('Correct answer'), findsOneWidget);
      expect(find.text('Goodbye'), findsOneWidget); // what was picked
      expect(find.text('Hello'), findsOneWidget); // what was right
    });

    testWidgets('defaults to the missed questions and can show them all', (tester) async {
      playWithOneMistake();
      await pump(tester, const LessonReviewScreen());
      await tester.pump(const Duration(milliseconds: 400));

      // One mistake out of two questions.
      expect(find.text('Missed (1)'), findsOneWidget);
      expect(find.text('All (2)'), findsOneWidget);

      await tester.tap(find.text('All (2)'));
      await tester.pump(const Duration(milliseconds: 400));

      // Now both rows render, so the prompt appears twice.
      expect(find.textContaining('What does'), findsNWidgets(2));
    });

    testWidgets('a cleared session degrades to an empty state, never a crash', (tester) async {
      await pump(tester, const LessonReviewScreen());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Nothing to review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

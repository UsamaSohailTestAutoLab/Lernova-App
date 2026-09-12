import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/features/exercises/application/lesson_session_controller.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';

Exercise _mc(String id, int correctIndex) => Exercise(
      id: id,
      type: ExerciseType.multipleChoice,
      vocabId: 'v_$id',
      payload: MultipleChoicePayload(prompt: 'p', options: const ['a', 'b'], correctIndex: correctIndex),
    );

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

  Course course(List<Exercise> exercises) {
    final lesson = Lesson(id: 'l0', title: 'Lesson', subtitle: '', exercises: exercises);
    return Course(
      id: 'c0',
      languageId: 'es',
      title: 'Course',
      description: '',
      placementQuestions: const [],
      units: [CourseUnit(id: 'u0', title: 'Unit', description: '', lessons: [lesson])],
    );
  }

  test('answering everything correctly on the first try completes with full XP', () {
    final exercises = [_mc('e0', 0), _mc('e1', 0)];
    final c = course(exercises);
    final controller = container.read(lessonSessionProvider.notifier);

    controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

    controller.submitAnswer(0);
    expect(container.read(lessonSessionProvider)!.feedback, ExerciseFeedback.correct);
    controller.continueToNext();

    controller.submitAnswer(0);
    controller.continueToNext();

    final state = container.read(lessonSessionProvider)!;
    expect(state.isComplete, isTrue);
    expect(state.xpEarned, 20); // 2 * 10 XP first-try
    expect(state.isPerfect, isTrue);
  });

  test('a wrong answer costs a heart and re-queues the exercise for retry', () {
    final exercises = [_mc('e0', 0), _mc('e1', 0)];
    final c = course(exercises);
    final controller = container.read(lessonSessionProvider.notifier);
    controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

    final heartsBefore = container.read(progressProvider).hearts;
    controller.submitAnswer(1); // wrong
    expect(container.read(lessonSessionProvider)!.feedback, ExerciseFeedback.incorrect);
    expect(container.read(progressProvider).hearts, heartsBefore - 1);

    controller.continueToNext();
    final state = container.read(lessonSessionProvider)!;
    expect(state.isComplete, isFalse);
    expect(state.retriedIds, contains('e0'));
    // e0 should still be in the queue somewhere for a retry.
    expect(state.queue.any((e) => e.id == 'e0'), isTrue);
  });

  test('a retried exercise awards reduced XP once finally correct', () {
    final exercises = [_mc('e0', 0)];
    final c = course(exercises);
    final controller = container.read(lessonSessionProvider.notifier);
    controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

    controller.submitAnswer(1); // wrong first
    controller.continueToNext();

    controller.submitAnswer(0); // correct on retry
    controller.continueToNext();

    final state = container.read(lessonSessionProvider)!;
    expect(state.isComplete, isTrue);
    expect(state.xpEarned, 5); // retry rate
    expect(state.isPerfect, isFalse);
  });

  test('finishAndApply hands the tally to ProgressController exactly once', () {
    final exercises = [_mc('e0', 0)];
    final c = course(exercises);
    final controller = container.read(lessonSessionProvider.notifier);
    controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

    controller.submitAnswer(0);
    controller.continueToNext();

    final xpBefore = container.read(progressProvider).totalXp;
    final result1 = controller.finishAndApply();
    final xpAfter = container.read(progressProvider).totalXp;
    expect(xpAfter - xpBefore, result1.xpEarned);

    final result2 = controller.finishAndApply();
    expect(result2.xpEarned, result1.xpEarned);
    expect(container.read(progressProvider).totalXp, xpAfter); // unchanged on second call
  });

  group('answer capture', () {
    test('every graded answer is recorded with what was given and what was right', () {
      final exercises = [_mc('e0', 0), _mc('e1', 0)];
      final c = course(exercises);
      final controller = container.read(lessonSessionProvider.notifier);
      controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

      controller.submitAnswer(1); // wrong: picked 'b', answer is 'a'
      controller.continueToNext();

      final missed = container.read(lessonSessionProvider)!.missedAttempts;
      expect(missed, hasLength(1));
      expect(missed.single.exerciseId, 'e0');
      expect(missed.single.userAnswerLabel, 'b');
      expect(missed.single.correctLabel, 'a');
      expect(missed.single.wasCorrect, isFalse);
    });

    test('a retry does not erase the miss it is retrying', () {
      // Scoring on the latest attempt would mark every mistake correct,
      // since the session re-queues an exercise until it is answered.
      final exercises = [_mc('e0', 0)];
      final c = course(exercises);
      final controller = container.read(lessonSessionProvider.notifier);
      controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

      controller.submitAnswer(1); // wrong
      controller.continueToNext();
      controller.submitAnswer(0); // right on the retry
      controller.continueToNext();

      final state = container.read(lessonSessionProvider)!;
      expect(state.attempts, hasLength(2));
      expect(state.firstAttempts, hasLength(1));
      expect(state.missedAttempts, hasLength(1), reason: 'the miss still belongs in review');
    });

    test('a skipped exercise is recorded as missed and costs no heart', () {
      final exercises = [_mc('e0', 0), _mc('e1', 0)];
      final c = course(exercises);
      final controller = container.read(lessonSessionProvider.notifier);
      controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

      final heartsBefore = container.read(progressProvider).hearts;
      controller.skipCurrent();
      controller.continueToNext();

      expect(container.read(progressProvider).hearts, heartsBefore);
      final state = container.read(lessonSessionProvider)!;
      expect(state.missedAttempts.single.exerciseId, 'e0');
      expect(
        state.queue.any((e) => e.id == 'e0'),
        isFalse,
        reason: 're-queuing a skip re-creates the trap skipping exists to break',
      );
    });
  });

  group('hearts are a per-attempt life budget', () {
    test('starting a lesson restores the full budget', () {
      final c = course([_mc('e0', 0), _mc('e1', 0)]);
      final controller = container.read(lessonSessionProvider.notifier);
      final lesson = c.units[0].lessons[0];

      controller.start(course: c, unitIndex: 0, lesson: lesson);
      final full = container.read(progressProvider).hearts;
      controller.submitAnswer(1); // wrong
      expect(container.read(progressProvider).hearts, full - 1);

      // A new attempt is a clean slate — no waiting, nothing to buy.
      controller.start(course: c, unitIndex: 0, lesson: lesson);
      expect(container.read(progressProvider).hearts, full);
    });

    test('running out of hearts ends the attempt instead of trapping the learner', () {
      final exercises = [
        for (var i = 0; i < 8; i++) _mc('e$i', 0),
      ];
      final c = course(exercises);
      final controller = container.read(lessonSessionProvider.notifier);
      controller.start(course: c, unitIndex: 0, lesson: c.units[0].lessons[0]);

      while (container.read(progressProvider).hearts > 0) {
        controller.submitAnswer(1); // wrong
        controller.continueToNext();
      }

      final state = container.read(lessonSessionProvider)!;
      expect(state.isComplete, isTrue);
      expect(state.endedEarly, isTrue);
      expect(state.missedAttempts, isNotEmpty, reason: 'there is something to review');
    });

    test('an attempt that ran out of hearts does not complete the lesson', () {
      final exercises = [
        for (var i = 0; i < 8; i++) _mc('e$i', 0),
      ];
      final c = course(exercises);
      final controller = container.read(lessonSessionProvider.notifier);
      final lesson = c.units[0].lessons[0];
      controller.start(course: c, unitIndex: 0, lesson: lesson);

      while (container.read(progressProvider).hearts > 0) {
        controller.submitAnswer(1);
        controller.continueToNext();
      }
      controller.finishAndApply();

      final progress = container.read(progressProvider);
      expect(progress.completedLessonIds, isNot(contains(lesson.id)));
      expect(progress.totalLessonsCompleted, 0);
    });
  });
}

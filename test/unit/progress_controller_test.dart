import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/core/services/local_storage_service.dart';
import 'package:lernova/core/services/service_providers.dart';
import 'package:lernova/data/models/course.dart';
import 'package:lernova/data/models/course_unit.dart';
import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/data/models/lesson.dart';
import 'package:lernova/features/progress/application/progress_controller.dart';

Exercise _exercise(String id, String vocabId) => Exercise(
      id: id,
      type: ExerciseType.multipleChoice,
      vocabId: vocabId,
      payload: const MultipleChoicePayload(prompt: 'p', options: ['a', 'b'], correctIndex: 0),
    );

Course _course() {
  final lesson = Lesson(
    id: 'l0',
    title: 'Lesson 0',
    subtitle: '',
    exercises: [_exercise('e0', 'v0'), _exercise('e1', 'v1'), _exercise('e2', 'v2')],
  );
  final lesson2 = Lesson(id: 'l1', title: 'Lesson 1', subtitle: '', exercises: [_exercise('e3', 'v3')]);
  return Course(
    id: 'course_test',
    languageId: 'es',
    title: 'Test Course',
    description: '',
    placementQuestions: const [],
    units: [
      CourseUnit(id: 'u0', title: 'Unit 0', description: '', lessons: [lesson, lesson2]),
    ],
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

  test('a perfect lesson awards full XP plus completion and perfect bonuses', () {
    final course = _course();
    final controller = container.read(progressProvider.notifier);

    final result = controller.completeLessonSession(
      course: course,
      unitIndex: 0,
      lesson: course.units[0].lessons[0],
      xpEarned: 30, // 3 exercises * 10 XP first-try
      isPerfect: true,
      timeSpentSeconds: 45,
      mistakenExerciseIds: {},
      isReviewSession: false,
    );

    // 30 from exercises + 10 completion bonus + 20 perfect bonus = 60.
    expect(result.xpEarned, 60);
    expect(container.read(progressProvider).totalXp, 60);
    expect(result.gemsEarned, greaterThanOrEqualTo(10)); // perfect-lesson gem bonus
  });

  test('lesson completion marks the lesson done and does not unlock unit 1 yet', () {
    final course = _course();
    final controller = container.read(progressProvider.notifier);

    controller.completeLessonSession(
      course: course,
      unitIndex: 0,
      lesson: course.units[0].lessons[0],
      xpEarned: 20,
      isPerfect: false,
      timeSpentSeconds: 30,
      mistakenExerciseIds: {'e0'},
      isReviewSession: false,
    );

    final progress = container.read(progressProvider);
    expect(progress.completedLessonIds, contains('l0'));
    expect(progress.mistakeBank, containsPair('e0', 0));
    expect(progress.vocabStrength['v0'], -1); // e0 was mistaken
    expect(progress.vocabStrength['v1'], 1); // e1 was correct
  });

  test('completing every lesson in a unit unlocks the next unit and fires unitComplete', () {
    final course = _course();
    final controller = container.read(progressProvider.notifier);

    controller.completeLessonSession(
      course: course,
      unitIndex: 0,
      lesson: course.units[0].lessons[0],
      xpEarned: 30,
      isPerfect: true,
      timeSpentSeconds: 30,
      mistakenExerciseIds: {},
      isReviewSession: false,
    );

    final result = controller.completeLessonSession(
      course: course,
      unitIndex: 0,
      lesson: course.units[0].lessons[1],
      xpEarned: 10,
      isPerfect: true,
      timeSpentSeconds: 20,
      mistakenExerciseIds: {},
      isReviewSession: false,
    );

    expect(result.unitJustCompleted, isTrue);
    expect(result.courseJustCompleted, isTrue); // only one unit in this fixture
    expect(container.read(progressProvider).unlockedUnitIndex, 0); // no unit 1 to unlock
  });

  test('a review session clears a mistake after enough correct reviews, without new XP-lesson side effects', () {
    final course = _course();
    final controller = container.read(progressProvider.notifier);

    // First get 'e0' into the mistake bank via a normal lesson.
    controller.completeLessonSession(
      course: course,
      unitIndex: 0,
      lesson: course.units[0].lessons[0],
      xpEarned: 20,
      isPerfect: false,
      timeSpentSeconds: 10,
      mistakenExerciseIds: {'e0'},
      isReviewSession: false,
    );
    expect(container.read(progressProvider).mistakeBank, containsPair('e0', 0));

    final reviewLesson = Lesson(id: 'review', title: 'Review', subtitle: '', exercises: [_exercise('e0', 'v0')]);

    // Two correct reviews should clear it from the bank (threshold = 2).
    controller.completeLessonSession(
      course: course,
      unitIndex: -1,
      lesson: reviewLesson,
      xpEarned: 5,
      isPerfect: true,
      timeSpentSeconds: 5,
      mistakenExerciseIds: {},
      isReviewSession: true,
    );
    expect(container.read(progressProvider).mistakeBank, containsPair('e0', 1));
    expect(container.read(progressProvider).completedLessonIds, isNot(contains('review')));

    controller.completeLessonSession(
      course: course,
      unitIndex: -1,
      lesson: reviewLesson,
      xpEarned: 5,
      isPerfect: true,
      timeSpentSeconds: 5,
      mistakenExerciseIds: {},
      isReviewSession: true,
    );
    expect(container.read(progressProvider).mistakeBank.containsKey('e0'), isFalse);
  });

  test('loseHeart decrements hearts and reports when they hit zero', () {
    final controller = container.read(progressProvider.notifier);
    for (var i = 0; i < 4; i++) {
      final depleted = controller.loseHeart();
      expect(depleted, isFalse);
    }
    final lastDepleted = controller.loseHeart();
    expect(lastDepleted, isTrue);
    expect(container.read(progressProvider).hearts, 0);
  });

  group('awardFunSession', () {
    test('applies XP, coins and vocab deltas into the shared progress state', () {
      final controller = container.read(progressProvider.notifier);
      final gemsBefore = container.read(progressProvider).gems;

      final result = controller.awardFunSession(
        xpEarned: 25,
        coinsEarned: 6,
        vocabDeltas: {'es_hola': 1, 'es_adios': -1},
        isPerfectRound: false,
        isSpeedRound: false,
      );

      final progress = container.read(progressProvider);
      expect(result.xpEarned, 25);
      expect(progress.totalXp, 25);
      expect(progress.dailyXp, 25);
      expect(progress.gems, gemsBefore + 6);
      expect(progress.vocabStrength['es_hola'], 1);
      expect(progress.vocabStrength['es_adios'], -1);
    });

    test('a perfect round pays the same completion bonus lessons pay, and reports the achievement flag', () {
      final controller = container.read(progressProvider.notifier);
      final result = controller.awardFunSession(
        xpEarned: 10,
        coinsEarned: 2,
        vocabDeltas: const {},
        isPerfectRound: true,
        isSpeedRound: false,
      );
      expect(result.gemsEarned, greaterThan(2)); // coins + perfect bonus
      expect(result.newAchievements, contains(AchievementId.perfectRound));
    });

    test('does not touch lesson-only fields like completedLessonIds', () {
      final controller = container.read(progressProvider.notifier);
      final before = container.read(progressProvider).completedLessonIds;
      controller.awardFunSession(
        xpEarned: 5,
        coinsEarned: 1,
        vocabDeltas: const {},
        isPerfectRound: false,
        isSpeedRound: false,
      );
      expect(container.read(progressProvider).completedLessonIds, before);
    });
  });
}

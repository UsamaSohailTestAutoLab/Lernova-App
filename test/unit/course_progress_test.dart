import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/features/course/application/course_progress.dart';

Course _buildCourse() {
  Lesson lesson(String id) => Lesson(id: id, title: id, subtitle: '', exercises: const []);
  return Course(
    id: 'course_test',
    languageId: 'es',
    title: 'Test Course',
    description: '',
    placementQuestions: const [],
    units: [
      CourseUnit(
        id: 'u0',
        title: 'Unit 0',
        description: '',
        lessons: [lesson('u0_l0'), lesson('u0_l1')],
      ),
      CourseUnit(
        id: 'u1',
        title: 'Unit 1',
        description: '',
        lessons: [lesson('u1_l0'), lesson('u1_l1')],
      ),
    ],
  );
}

UserProgress _progress({
  int unlockedUnitIndex = 0,
  Set<String> completedLessonIds = const {},
  Set<String> perfectLessonIds = const {},
  bool isPremium = false,
}) {
  final now = DateTime(2026, 1, 1);
  return UserProgress(
    unlockedUnitIndex: unlockedUnitIndex,
    completedLessonIds: completedLessonIds,
    perfectLessonIds: perfectLessonIds,
    isPremium: isPremium,
    dailyGoalDate: now,
    lessonsCompletedTodayDate: now,
    weekId: '2026-W01',
  );
}

void main() {
  final course = _buildCourse();

  group('CourseProgress.lessonState', () {
    test('first lesson of the first unit starts as current', () {
      final state = CourseProgress.lessonState(
        course: course,
        unitIndex: 0,
        lessonIndex: 0,
        progress: _progress(),
      );
      expect(state, LessonNodeState.current);
    });

    test('second lesson is locked until the first is completed', () {
      final state = CourseProgress.lessonState(
        course: course,
        unitIndex: 0,
        lessonIndex: 1,
        progress: _progress(),
      );
      expect(state, LessonNodeState.locked);
    });

    test('second lesson becomes current once the first is completed', () {
      final state = CourseProgress.lessonState(
        course: course,
        unitIndex: 0,
        lessonIndex: 1,
        progress: _progress(completedLessonIds: {'u0_l0'}),
      );
      expect(state, LessonNodeState.current);
    });

    test('completed lesson reports completed, or perfect when flagged', () {
      final completedState = CourseProgress.lessonState(
        course: course,
        unitIndex: 0,
        lessonIndex: 0,
        progress: _progress(completedLessonIds: {'u0_l0'}),
      );
      expect(completedState, LessonNodeState.completed);

      final perfectState = CourseProgress.lessonState(
        course: course,
        unitIndex: 0,
        lessonIndex: 0,
        progress: _progress(
          completedLessonIds: {'u0_l0'},
          perfectLessonIds: {'u0_l0'},
        ),
      );
      expect(perfectState, LessonNodeState.perfect);
    });

    test('lessons in an unreached unit are locked', () {
      final state = CourseProgress.lessonState(
        course: course,
        unitIndex: 1,
        lessonIndex: 0,
        progress: _progress(),
      );
      expect(state, LessonNodeState.locked);
    });
  });

  group('CourseProgress.resolveUnlockedUnitIndexAfterCompletion', () {
    test('unlocks the next unit once every lesson in the current one is done', () {
      final progress = _progress(completedLessonIds: {'u0_l0', 'u0_l1'});
      final next = CourseProgress.resolveUnlockedUnitIndexAfterCompletion(
        course: course,
        unitIndex: 0,
        progress: progress,
      );
      expect(next, 1);
    });

    test('does not unlock the next unit while lessons remain', () {
      final progress = _progress(completedLessonIds: {'u0_l0'});
      final next = CourseProgress.resolveUnlockedUnitIndexAfterCompletion(
        course: course,
        unitIndex: 0,
        progress: progress,
      );
      expect(next, 0);
    });
  });

  group('CourseProgress.findCurrentLesson', () {
    test('finds the first lesson when nothing is completed', () {
      expect(CourseProgress.findCurrentLesson(course, _progress()), (0, 0));
    });

    test('finds the next lesson after completing the first', () {
      final progress = _progress(completedLessonIds: {'u0_l0'});
      expect(CourseProgress.findCurrentLesson(course, progress), (0, 1));
    });

    test('returns null once the whole course is complete', () {
      final progress = _progress(
        unlockedUnitIndex: 1,
        completedLessonIds: {'u0_l0', 'u0_l1', 'u1_l0', 'u1_l1'},
      );
      expect(CourseProgress.findCurrentLesson(course, progress), isNull);
    });

    // Regression: finishing the first lesson used to jump the learner to
    // the NEXT UNIT's first lesson whenever unlockedUnitIndex was ahead
    // of the frontier — which the placement test and the debug unlock
    // both cause. It must always be the very next lesson in order.
    test('never skips to a later unit, whatever unlockedUnitIndex says', () {
      for (final unlocked in [0, 1, 999]) {
        final progress = _progress(
          unlockedUnitIndex: unlocked,
          completedLessonIds: {'u0_l0'},
        );
        expect(
          CourseProgress.findCurrentLesson(course, progress),
          (0, 1),
          reason: 'unlockedUnitIndex: $unlocked must still go to u0_l1',
        );
      }
    });

    test('moves through the course one lesson at a time', () {
      final completed = <String>{};
      final expected = [(0, 0), (0, 1), (1, 0), (1, 1)];
      for (final step in expected) {
        final progress = _progress(unlockedUnitIndex: 999, completedLessonIds: {...completed});
        expect(CourseProgress.findCurrentLesson(course, progress), step);
        completed.add(course.units[step.$1].lessons[step.$2].id);
      }
      expect(
        CourseProgress.findCurrentLesson(course, _progress(completedLessonIds: completed)),
        isNull,
      );
    });

    test('exactly one lesson in the whole course is ever "current"', () {
      final progress = _progress(unlockedUnitIndex: 999, completedLessonIds: {'u0_l0'});
      var currentCount = 0;
      for (var u = 0; u < course.units.length; u++) {
        for (var l = 0; l < course.units[u].lessons.length; l++) {
          final state = CourseProgress.lessonState(
            course: course,
            unitIndex: u,
            lessonIndex: l,
            progress: progress,
          );
          if (state == LessonNodeState.current) currentCount++;
        }
      }
      expect(currentCount, 1);
    });
  });

  group('CourseProgress premium bypass', () {
    test('premium opens every lesson, including a locked later unit', () {
      final free = _progress();
      final pro = _progress(isPremium: true);

      final lockedForFree = CourseProgress.lessonState(
        course: course,
        unitIndex: 1,
        lessonIndex: 1,
        progress: free,
      );
      final openForPro = CourseProgress.lessonState(
        course: course,
        unitIndex: 1,
        lessonIndex: 1,
        progress: pro,
      );

      expect(lockedForFree, LessonNodeState.locked);
      expect(CourseProgress.isLessonPlayable(openForPro), isTrue);
    });

    test('premium still points "continue" at the next unfinished lesson', () {
      final progress = _progress(isPremium: true, completedLessonIds: {'u0_l0'});
      expect(CourseProgress.findCurrentLesson(course, progress), (0, 1));
    });

    test('access follows the subscription — it is not persisted', () {
      const completed = {'u0_l0'};
      expect(
        CourseProgress.lessonState(
          course: course,
          unitIndex: 1,
          lessonIndex: 1,
          progress: _progress(isPremium: true, completedLessonIds: completed),
        ),
        isNot(LessonNodeState.locked),
      );
      // Same progress, premium revoked: the lesson locks again.
      expect(
        CourseProgress.lessonState(
          course: course,
          unitIndex: 1,
          lessonIndex: 1,
          progress: _progress(completedLessonIds: completed),
        ),
        LessonNodeState.locked,
      );
    });
  });

  group('CourseProgress.isCourseComplete', () {
    test('false until every unit is fully completed', () {
      final progress = _progress(completedLessonIds: {'u0_l0', 'u0_l1'});
      expect(CourseProgress.isCourseComplete(course, progress), isFalse);
    });

    test('true once every lesson in every unit is completed', () {
      final progress = _progress(
        completedLessonIds: {'u0_l0', 'u0_l1', 'u1_l0', 'u1_l1'},
      );
      expect(CourseProgress.isCourseComplete(course, progress), isTrue);
    });
  });
}

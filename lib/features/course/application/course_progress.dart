import '../../../core/constants/app_enums.dart';
import '../../../data/models/course.dart';
import '../../../data/models/course_unit.dart';
import '../../../data/models/user_progress.dart';

/// Pure lesson/unit unlock rules shared by the learning-path UI and its
/// unit tests. A unit is "reachable" once its index is at or below
/// [UserProgress.unlockedUnitIndex] (normal progression, or a jump
/// granted by the placement test); within a reachable unit, lessons
/// unlock sequentially unless the whole unit was skipped via placement.
class CourseProgress {
  CourseProgress._();

  static bool isUnitReachable(int unitIndex, UserProgress progress) {
    if (progress.isPremium) return true;
    return unitIndex <= progress.unlockedUnitIndex;
  }

  /// Can this lesson be opened at all? The single gate every lock in the
  /// app resolves through — unit reachability, then sequential order
  /// within the frontier unit. Premium opens everything, as a read-time
  /// override rather than a persisted unlock, so access follows the
  /// subscription instead of outliving it.
  static bool _isAccessible(
    Course course,
    int unitIndex,
    int lessonIndex,
    UserProgress progress,
  ) {
    if (progress.isPremium) return true;
    if (!isUnitReachable(unitIndex, progress)) return false;
    // A unit fully behind the frontier (skipped via placement) is open.
    if (unitIndex < progress.unlockedUnitIndex) return true;
    if (lessonIndex == 0) return true;
    final previous = course.units[unitIndex].lessons[lessonIndex - 1];
    return progress.completedLessonIds.contains(previous.id);
  }

  static bool isUnitFullyCompleted(CourseUnit unit, UserProgress progress) {
    return unit.lessons.every((l) => progress.completedLessonIds.contains(l.id));
  }

  static LessonNodeState lessonState({
    required Course course,
    required int unitIndex,
    required int lessonIndex,
    required UserProgress progress,
  }) {
    final lesson = course.units[unitIndex].lessons[lessonIndex];

    if (progress.completedLessonIds.contains(lesson.id)) {
      return progress.perfectLessonIds.contains(lesson.id)
          ? LessonNodeState.perfect
          : LessonNodeState.completed;
    }

    if (!_isAccessible(course, unitIndex, lessonIndex, progress)) {
      return LessonNodeState.locked;
    }

    // "Current" is whatever [findCurrentLesson] picks — one lesson for
    // the whole course. Deciding it per-unit (as this used to) marked
    // lesson 0 of every later unit as current too, so finishing a
    // lesson could jump the learner into the next unit entirely.
    final current = findCurrentLesson(course, progress);
    final isCurrent =
        current != null && current.$1 == unitIndex && current.$2 == lessonIndex;
    return isCurrent ? LessonNodeState.current : LessonNodeState.unlocked;
  }

  static bool isLessonPlayable(LessonNodeState state) {
    return state == LessonNodeState.current ||
        state == LessonNodeState.unlocked ||
        state == LessonNodeState.completed ||
        state == LessonNodeState.perfect;
  }

  /// Next unit index to unlock after finishing every lesson in
  /// [unitIndex] — no-op if the unit isn't actually complete yet, or if
  /// a later unit is already unlocked (placement jump).
  static int resolveUnlockedUnitIndexAfterCompletion({
    required Course course,
    required int unitIndex,
    required UserProgress progress,
  }) {
    final unit = course.units[unitIndex];
    if (!isUnitFullyCompleted(unit, progress)) return progress.unlockedUnitIndex;
    final next = unitIndex + 1;
    if (next >= course.units.length) return progress.unlockedUnitIndex;
    return next > progress.unlockedUnitIndex ? next : progress.unlockedUnitIndex;
  }

  static bool isCourseComplete(Course course, UserProgress progress) {
    return course.units.every((u) => isUnitFullyCompleted(u, progress));
  }

  /// Locates the "continue learning" lesson: the first lesson, in course
  /// order, that isn't finished yet and can actually be opened. Null
  /// once every lesson is complete.
  ///
  /// This is the source of truth for [LessonNodeState.current] — walking
  /// in order guarantees the learner is always sent to the very next
  /// lesson and never skipped past one.
  static (int unitIndex, int lessonIndex)? findCurrentLesson(
    Course course,
    UserProgress progress,
  ) {
    for (var u = 0; u < course.units.length; u++) {
      for (var l = 0; l < course.units[u].lessons.length; l++) {
        if (progress.completedLessonIds.contains(course.units[u].lessons[l].id)) {
          continue;
        }
        if (_isAccessible(course, u, l, progress)) return (u, l);
      }
    }
    return null;
  }
}

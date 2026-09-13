import '../../../core/constants/app_enums.dart';
import '../../../data/models/course.dart';
import '../../../data/models/user_progress.dart';
import '../../course/application/course_progress.dart';

/// Why a lesson can or cannot be opened right now.
///
/// Deliberately separate from [LessonNodeState], which answers a
/// different question: how far the learner has progressed. Progression
/// and entitlement are independent — a lesson can be earned and still be
/// behind the subscription — and keeping them apart is what lets
/// [CourseProgress] stay pure progression logic with its own tests.
enum LessonAccess {
  /// Playable now.
  open,

  /// Not reached yet. An earlier lesson comes first.
  locked,

  /// Behind the subscription. Tapping this opens the paywall, not a
  /// "finish the previous lesson" message — the subscription is the
  /// actual barrier, and saying anything else wastes the tap.
  requiresPro,
}

/// The same question for a Fun game.
enum FunAccess { open, requiresPro }

/// What the free tier includes.
///
/// One Path lesson and one Fun level: enough to show a learner what both
/// halves of the app feel like, and no more. Everything past that needs
/// an active subscription.
///
/// The entitlement is read from [UserProgress.isPremium], which
/// [ProgressController.applyEntitlement] keeps in step with the store.
/// That makes access a read-time decision rather than a persisted
/// unlock, so it follows the subscription instead of outliving it — if
/// somebody cancels, the next build of the path screen locks back up on
/// its own.
class Entitlements {
  Entitlements._();

  /// The one lesson anybody can play: the first of the course. Held as a
  /// position, not a lesson id, so it means "the opening lesson" in
  /// every language rather than only Spanish's `es_u1_l1`.
  static const int freeUnitIndex = 0;
  static const int freeLessonIndex = 0;

  /// The one Fun game anybody can play, and how far into it.
  static const FunGameMode freeFunMode = FunGameMode.fallingWords;
  static const int freeFunLevel = 1;

  static bool isLessonFree(int unitIndex, int lessonIndex) =>
      unitIndex == freeUnitIndex && lessonIndex == freeLessonIndex;

  static bool isFunLevelFree(FunGameMode mode, int level) =>
      mode == freeFunMode && level <= freeFunLevel;

  /// Composes progression with entitlement.
  ///
  /// For a subscriber this is exactly [CourseProgress]: play what you
  /// have earned. For everybody else the free lesson follows the same
  /// rule and every other lesson reports [LessonAccess.requiresPro] —
  /// including lessons that progression has not reached either. That is
  /// deliberate: to somebody who has not paid, "finish Say Hello first"
  /// is not the real reason lesson 3 will not open, and offering a
  /// sequence of different excuses on the way down the path is worse
  /// than naming the one barrier that is actually there.
  static LessonAccess resolveLessonAccess({
    required Course course,
    required int unitIndex,
    required int lessonIndex,
    required UserProgress progress,
  }) {
    if (progress.isPremium || isLessonFree(unitIndex, lessonIndex)) {
      final state = CourseProgress.lessonState(
        course: course,
        unitIndex: unitIndex,
        lessonIndex: lessonIndex,
        progress: progress,
      );
      return CourseProgress.isLessonPlayable(state)
          ? LessonAccess.open
          : LessonAccess.locked;
    }
    return LessonAccess.requiresPro;
  }

  /// Whether this Fun mode, at the level the learner has reached in it,
  /// can be played.
  ///
  /// Note this takes the level the learner is *on*, not the level they
  /// have cleared. Clearing Word Bubble level 1 moves them to level 2,
  /// which is where the free tier ends — so the paywall arrives the
  /// moment the free level is finished, without needing a separate
  /// "have they finished it yet" flag.
  static FunAccess resolveFunAccess({
    required FunGameMode mode,
    required int level,
    required UserProgress progress,
  }) {
    if (progress.isPremium) return FunAccess.open;
    return isFunLevelFree(mode, level) ? FunAccess.open : FunAccess.requiresPro;
  }
}

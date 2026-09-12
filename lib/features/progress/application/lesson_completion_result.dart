import '../../../core/constants/app_enums.dart';

/// Everything the post-lesson result screens (XP reward, streak, daily
/// goal, achievement unlock) need to render — computed once by
/// [ProgressController.completeLessonSession] so the UI never
/// recomputes gamification math itself.
class LessonCompletionResult {
  final int xpEarned;
  final int newTotalXp;
  final bool leveledUp;
  final int newLevel;
  final bool streakContinued;
  final int newStreakCount;
  final bool dailyGoalJustReached;
  final List<AchievementId> newAchievements;
  final bool unitJustCompleted;
  final bool courseJustCompleted;
  final bool outOfHearts;

  const LessonCompletionResult({
    required this.xpEarned,
    required this.newTotalXp,
    required this.leveledUp,
    required this.newLevel,
    required this.streakContinued,
    required this.newStreakCount,
    required this.dailyGoalJustReached,
    required this.newAchievements,
    required this.unitJustCompleted,
    required this.courseJustCompleted,
    required this.outOfHearts,
  });
}

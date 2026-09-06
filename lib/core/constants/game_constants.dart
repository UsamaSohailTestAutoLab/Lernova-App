/// Centralized gamification formula constants — every number that drives
/// XP/hearts/streak/level math lives here so it's testable in one place
/// and never duplicated inline.
class GameConstants {
  GameConstants._();

  static const int xpPerCorrectFirstTry = 10;
  static const int xpPerCorrectRetry = 5;
  static const int lessonCompletionBonus = 10;
  static const int perfectLessonBonus = 20;

  static const int xpPerLevel = 500;

  static const int maxHearts = 5;
  static const Duration heartRegenInterval = Duration(hours: 4);

  static const int mistakeReviewClearThreshold = 2;

  static const int streakFreezeGemCost = 200;
  static const int mascotOutfitGemCost = 500;

  static const int gemsPerAchievement = 50;
  static const int gemsPerPerfectLesson = 10;
}

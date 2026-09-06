import '../constants/game_constants.dart';

/// Pure XP/level math shared by the progress controller and unit tests.
class XpUtils {
  XpUtils._();

  static int xpForAnswer({required bool isRetry}) {
    return isRetry
        ? GameConstants.xpPerCorrectRetry
        : GameConstants.xpPerCorrectFirstTry;
  }

  static int lessonBonusXp({required bool isPerfect}) {
    return GameConstants.lessonCompletionBonus +
        (isPerfect ? GameConstants.perfectLessonBonus : 0);
  }

  static int levelForXp(int totalXp) {
    return (totalXp ~/ GameConstants.xpPerLevel) + 1;
  }

  /// XP remaining until the next level boundary.
  static int xpToNextLevel(int totalXp) {
    final currentLevel = levelForXp(totalXp);
    final nextLevelFloor = currentLevel * GameConstants.xpPerLevel;
    return nextLevelFloor - totalXp;
  }

  /// Progress (0.0-1.0) through the current level.
  static double levelProgress(int totalXp) {
    final withinLevel = totalXp % GameConstants.xpPerLevel;
    return withinLevel / GameConstants.xpPerLevel;
  }
}

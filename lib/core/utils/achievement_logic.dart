import '../../data/models/fun/phrase.dart';
import '../../data/models/user_progress.dart';
import '../constants/app_enums.dart';

/// Pure rule evaluation: given the current progress snapshot plus a few
/// event flags from the action that just happened, return achievement
/// ids that just became unlocked (and weren't already).
class AchievementLogic {
  AchievementLogic._();

  static List<AchievementId> evaluateNewlyUnlocked(
    UserProgress progress, {
    bool isPerfectLesson = false,
    bool unitJustCompleted = false,
    bool courseJustCompleted = false,
    bool isPerfectFunRound = false,
    bool isSpeedRound = false,
  }) {
    final already = progress.unlockedAchievementIds;
    final newlyUnlocked = <AchievementId>[];

    void check(AchievementId id, bool condition) {
      if (condition && !already.contains(id.name)) {
        newlyUnlocked.add(id);
      }
    }

    final wordsLearned = progress.vocabStrength.entries
        .where((e) => e.value >= 1 && !e.key.contains(Phrase.idMarker))
        .length;
    final phrasesLearned = progress.vocabStrength.entries
        .where((e) => e.value >= 1 && e.key.contains(Phrase.idMarker))
        .length;

    check(AchievementId.firstLesson, progress.totalLessonsCompleted >= 1);
    check(AchievementId.streak3, progress.streakCount >= 3);
    check(AchievementId.streak7, progress.streakCount >= 7);
    check(AchievementId.streak30, progress.streakCount >= 30);
    check(AchievementId.xp100, progress.totalXp >= 100);
    check(AchievementId.xp500, progress.totalXp >= 500);
    check(AchievementId.xp1000, progress.totalXp >= 1000);
    check(AchievementId.perfectLesson, isPerfectLesson);
    check(AchievementId.fiveLessonsInADay, progress.lessonsCompletedToday >= 5);
    check(AchievementId.unitComplete, unitJustCompleted);
    check(AchievementId.courseComplete, courseJustCompleted);
    check(AchievementId.wordMaster, wordsLearned >= 100);
    check(AchievementId.phraseMaster, phrasesLearned >= 50);
    check(AchievementId.speedLearner, isSpeedRound);
    check(AchievementId.perfectRound, isPerfectFunRound);

    return newlyUnlocked;
  }
}

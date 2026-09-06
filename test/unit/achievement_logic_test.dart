import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/core/utils/achievement_logic.dart';
import 'package:lernova/data/models/user_progress.dart';

void main() {
  UserProgress progress({
    int totalXp = 0,
    int streakCount = 0,
    int totalLessonsCompleted = 0,
    int lessonsCompletedToday = 0,
    Set<String> unlockedAchievementIds = const {},
    Map<String, int> vocabStrength = const {},
  }) {
    final now = DateTime(2026, 1, 1);
    return UserProgress(
      totalXp: totalXp,
      streakCount: streakCount,
      totalLessonsCompleted: totalLessonsCompleted,
      lessonsCompletedToday: lessonsCompletedToday,
      unlockedAchievementIds: unlockedAchievementIds,
      vocabStrength: vocabStrength,
      dailyGoalDate: now,
      lessonsCompletedTodayDate: now,
      weekId: '2026-W01',
    );
  }

  test('first lesson completion unlocks firstLesson', () {
    final result = AchievementLogic.evaluateNewlyUnlocked(
      progress(totalLessonsCompleted: 1),
    );
    expect(result, contains(AchievementId.firstLesson));
  });

  test('does not re-unlock an achievement already earned', () {
    final result = AchievementLogic.evaluateNewlyUnlocked(
      progress(
        totalLessonsCompleted: 1,
        unlockedAchievementIds: {AchievementId.firstLesson.name},
      ),
    );
    expect(result, isNot(contains(AchievementId.firstLesson)));
  });

  test('streak thresholds unlock the matching achievements', () {
    final result = AchievementLogic.evaluateNewlyUnlocked(progress(streakCount: 7));
    expect(result, containsAll([AchievementId.streak3, AchievementId.streak7]));
    expect(result, isNot(contains(AchievementId.streak30)));
  });

  test('xp thresholds unlock the matching achievements', () {
    final result = AchievementLogic.evaluateNewlyUnlocked(progress(totalXp: 500));
    expect(result, containsAll([AchievementId.xp100, AchievementId.xp500]));
    expect(result, isNot(contains(AchievementId.xp1000)));
  });

  test('event-flag achievements only unlock when the flag is set', () {
    final base = progress();
    expect(
      AchievementLogic.evaluateNewlyUnlocked(base, isPerfectLesson: true),
      contains(AchievementId.perfectLesson),
    );
    expect(
      AchievementLogic.evaluateNewlyUnlocked(base, unitJustCompleted: true),
      contains(AchievementId.unitComplete),
    );
    expect(
      AchievementLogic.evaluateNewlyUnlocked(base, courseJustCompleted: true),
      contains(AchievementId.courseComplete),
    );
    expect(AchievementLogic.evaluateNewlyUnlocked(base), isEmpty);
  });

  test('five lessons in a day unlocks fiveLessonsInADay', () {
    final result =
        AchievementLogic.evaluateNewlyUnlocked(progress(lessonsCompletedToday: 5));
    expect(result, contains(AchievementId.fiveLessonsInADay));
  });

  test('wordMaster counts only mastered plain words, not phrases', () {
    final vocabStrength = {
      for (var i = 0; i < 100; i++) 'es_word_$i': 1,
      for (var i = 0; i < 10; i++) 'es_phrase_$i': 1, // should not count
      'es_unlearned': 0, // strength 0 should not count
    };
    final result =
        AchievementLogic.evaluateNewlyUnlocked(progress(vocabStrength: vocabStrength));
    expect(result, contains(AchievementId.wordMaster));
  });

  test('wordMaster does not unlock below 100 mastered words', () {
    final vocabStrength = {for (var i = 0; i < 99; i++) 'es_word_$i': 1};
    final result =
        AchievementLogic.evaluateNewlyUnlocked(progress(vocabStrength: vocabStrength));
    expect(result, isNot(contains(AchievementId.wordMaster)));
  });

  test('phraseMaster counts only mastered phrases, not plain words', () {
    final vocabStrength = {
      for (var i = 0; i < 50; i++) 'es_phrase_$i': 1,
      for (var i = 0; i < 10; i++) 'es_word_$i': 1, // should not count
    };
    final result =
        AchievementLogic.evaluateNewlyUnlocked(progress(vocabStrength: vocabStrength));
    expect(result, contains(AchievementId.phraseMaster));
  });

  test('speedLearner and perfectRound only unlock via their Fun event flags', () {
    final base = progress();
    expect(
      AchievementLogic.evaluateNewlyUnlocked(base, isSpeedRound: true),
      contains(AchievementId.speedLearner),
    );
    expect(
      AchievementLogic.evaluateNewlyUnlocked(base, isPerfectFunRound: true),
      contains(AchievementId.perfectRound),
    );
    expect(AchievementLogic.evaluateNewlyUnlocked(base), isEmpty);
  });
}

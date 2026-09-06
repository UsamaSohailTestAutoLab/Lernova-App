import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/game_constants.dart';
import '../../../core/services/service_providers.dart';
import '../../../core/utils/achievement_logic.dart';
import '../../../core/utils/daily_goal_logic.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/hearts_logic.dart';
import '../../../core/utils/league_logic.dart';
import '../../../core/utils/streak_logic.dart';
import '../../../core/utils/xp_utils.dart';
import '../../../data/models/course.dart';
import '../../../data/models/last_activity.dart';
import '../../../data/models/lesson.dart';
import '../../../data/models/user_progress.dart';
import '../../course/application/course_progress.dart';
import 'lesson_completion_result.dart';

/// The gamification engine: XP, hearts, streak, daily goal, unlocks,
/// mistake bank, vocab strength, achievements and league standing all
/// live behind this one controller so every screen reads a single
/// consistent, persisted truth.
class ProgressController extends Notifier<UserProgress> {
  @override
  UserProgress build() {
    final storage = ref.read(localStorageServiceProvider);
    final now = DateTime.now();
    final loaded = storage.loadProgress() ??
        UserProgress.initial(weekId: AppDateUtils.isoWeekId(now));
    final reconciled = _reconcile(loaded, now);
    if (reconciled != loaded) {
      storage.saveProgress(reconciled);
    }
    return reconciled;
  }

  UserProgress _reconcile(UserProgress progress, DateTime now) {
    var next = HeartsLogic.regenerate(progress, now);
    next = StreakLogic.reconcileOnResume(next, now);
    next = DailyGoalLogic.reconcileOnResume(next, now);
    next = _reconcileWeekRollover(next, now);
    return next;
  }

  UserProgress _reconcileWeekRollover(UserProgress progress, DateTime now) {
    final currentWeekId = AppDateUtils.isoWeekId(now);
    if (progress.weekId == currentWeekId) return progress;

    final oldCohort =
        ref.read(leaderboardRepositoryProvider).generateCohort(progress.weekId);
    final nextTier = LeagueLogic.resolveNextTier(
      currentTier: progress.leagueTier,
      userWeeklyXp: progress.weeklyXp,
      cohortWeeklyXp: oldCohort.map((e) => e.weeklyXp).toList(),
    );

    return progress.copyWith(
      weekId: currentWeekId,
      weeklyXp: 0,
      leagueTier: nextTier,
    );
  }

  void _persist(UserProgress next) {
    state = next;
    ref.read(localStorageServiceProvider).saveProgress(next);
  }

  void initializeForOnboarding({
    required int dailyGoalXp,
    required int unlockedUnitIndex,
  }) {
    final now = DateTime.now();
    final fresh = UserProgress.initial(weekId: AppDateUtils.isoWeekId(now))
        .copyWith(dailyGoalXp: dailyGoalXp, unlockedUnitIndex: unlockedUnitIndex);
    _persist(fresh);
  }

  /// Remembers what the learner just opened, so Home's "Continue
  /// learning" resumes the thing they were actually doing.
  ///
  /// Written on *start* rather than on completion: an abandoned session
  /// is exactly the one worth offering to resume, and it would otherwise
  /// never be recorded at all.
  void noteActivityStarted(LastActivity activity) {
    _persist(state.copyWith(lastActivity: activity));
  }

  /// Records that this level's Review Words step has been seen through
  /// once, which is what makes it skippable on later attempts.
  void markLevelPreviewed(String previewKey) {
    if (state.previewedLevelIds.contains(previewKey)) return;
    _persist(
      state.copyWith(
        previewedLevelIds: {...state.previewedLevelIds, previewKey},
      ),
    );
  }

  /// Called immediately when an exercise is answered incorrectly.
  /// Returns true if hearts are now depleted (the session ends).
  ///
  /// Premium deliberately has no effect here. Hearts are a per-session
  /// attempt budget that refills at the start of every lesson (see
  /// [refillHeartsForSession]) — they are not a resource anyone can be
  /// sold out of, so "unlimited hearts" is not something Pro grants.
  bool loseHeart() {
    if (state.hearts <= 0) return true;

    final wasFull = state.hearts >= GameConstants.maxHearts;
    final newHearts = state.hearts - 1;
    _persist(
      state.copyWith(
        hearts: newHearts,
        lastHeartLostAt: wasFull ? DateTime.now() : state.lastHeartLostAt,
      ),
    );
    return newHearts <= 0;
  }

  /// Restores the full heart budget. Called at the start of every lesson
  /// session, which is what makes hearts a per-attempt life system rather
  /// than a timed resource: running out ends *that attempt*, and the
  /// learner can immediately play again. There is deliberately no timer,
  /// no ad, no gem refill and no paywall attached to hearts.
  void refillHeartsForSession() {
    if (state.hearts >= GameConstants.maxHearts && state.lastHeartLostAt == null) {
      return;
    }
    _persist(state.copyWith(hearts: GameConstants.maxHearts, clearLastHeartLostAt: true));
  }

  bool spendGemsForStreakFreeze() {
    if (state.gems < GameConstants.streakFreezeGemCost) return false;
    _persist(
      state.copyWith(
        gems: state.gems - GameConstants.streakFreezeGemCost,
        streakFreezeAvailable: true,
      ),
    );
    return true;
  }

  bool spendGemsForMascotOutfit() {
    if (state.gems < GameConstants.mascotOutfitGemCost) return false;
    _persist(state.copyWith(gems: state.gems - GameConstants.mascotOutfitGemCost));
    return true;
  }

  void setDailyGoalXp(int xp) {
    _persist(state.copyWith(dailyGoalXp: xp));
  }

  /// Premium controls which levels/content are unlocked. It is
  /// deliberately not wired to hearts.
  void setPremium(bool value) {
    _persist(state.copyWith(isPremium: value));
  }

  /// Testing aid only: pushes `unlockedUnitIndex` far past any real
  /// course's length. `CourseProgress.lessonState` treats every unit
  /// below the frontier unit as freely accessible regardless of
  /// completion, so this opens every unit/lesson in the Path without
  /// touching the actual unlock *rules* — a fresh install still
  /// progresses normally.
  void debugUnlockAllPathLevels() {
    _persist(state.copyWith(unlockedUnitIndex: 999, hearts: GameConstants.maxHearts));
  }

  /// Applies the outcome of a finished lesson or review session in one
  /// atomic update and reports everything the result screens need.
  LessonCompletionResult completeLessonSession({
    required Course course,
    required int unitIndex,
    required Lesson lesson,
    required int xpEarned,
    required bool isPerfect,
    required int timeSpentSeconds,
    required Set<String> mistakenExerciseIds,
    required bool isReviewSession,

    /// False for an attempt that ended before the lesson did (running out
    /// of hearts). XP, mistake-bank and vocab-strength updates still
    /// apply — they were earned — but the lesson is not marked complete
    /// and nothing new unlocks. Defaults true so every ordinary
    /// completion path is unchanged.
    bool countsAsLessonCompletion = true,
  }) {
    final before = state;

    final creditsLesson = !isReviewSession && countsAsLessonCompletion;

    // Review sessions are practice, not a "lesson", and neither is an
    // attempt that ran out of hearts — only real lesson completions earn
    // the completion/perfect bonus on top of the XP already tallied per
    // exercise.
    final totalXpEarned = creditsLesson
        ? xpEarned + XpUtils.lessonBonusXp(isPerfect: isPerfect)
        : xpEarned;

    var next = before.copyWith(
      totalXp: before.totalXp + totalXpEarned,
      dailyXp: before.dailyXp + totalXpEarned,
      weeklyXp: before.weeklyXp + totalXpEarned,
      totalTimeSpentSeconds: before.totalTimeSpentSeconds + timeSpentSeconds,
    );

    // Mistake bank + vocab strength, shared by both modes.
    final mistakeBank = Map<String, int>.from(next.mistakeBank);
    final vocabStrength = Map<String, int>.from(next.vocabStrength);
    for (final exercise in lesson.exercises) {
      final wasMistaken = mistakenExerciseIds.contains(exercise.id);
      if (wasMistaken) {
        mistakeBank[exercise.id] = 0;
        vocabStrength[exercise.vocabId] =
            ((vocabStrength[exercise.vocabId] ?? 0) - 1).clamp(-2, 5);
      } else {
        vocabStrength[exercise.vocabId] =
            ((vocabStrength[exercise.vocabId] ?? 0) + 1).clamp(-2, 5);
        if (isReviewSession && mistakeBank.containsKey(exercise.id)) {
          final reviews = (mistakeBank[exercise.id] ?? 0) + 1;
          if (reviews >= GameConstants.mistakeReviewClearThreshold) {
            mistakeBank.remove(exercise.id);
          } else {
            mistakeBank[exercise.id] = reviews;
          }
        }
      }
    }
    next = next.copyWith(mistakeBank: mistakeBank, vocabStrength: vocabStrength);

    bool unitJustCompleted = false;
    bool courseJustCompleted = false;

    if (creditsLesson) {
      final unit = course.units[unitIndex];
      final wasUnitCompleteBefore = CourseProgress.isUnitFullyCompleted(unit, before);
      final wasCourseCompleteBefore = CourseProgress.isCourseComplete(course, before);

      final completedLessonIds = {...next.completedLessonIds, lesson.id};
      final perfectLessonIds = isPerfect
          ? {...next.perfectLessonIds, lesson.id}
          : next.perfectLessonIds;

      next = next.copyWith(
        completedLessonIds: completedLessonIds,
        perfectLessonIds: perfectLessonIds,
        totalLessonsCompleted: next.totalLessonsCompleted + 1,
        lessonsCompletedToday: next.lessonsCompletedToday + 1,
      );

      final isUnitCompleteNow = CourseProgress.isUnitFullyCompleted(unit, next);
      unitJustCompleted = !wasUnitCompleteBefore && isUnitCompleteNow;

      next = next.copyWith(
        unlockedUnitIndex: CourseProgress.resolveUnlockedUnitIndexAfterCompletion(
          course: course,
          unitIndex: unitIndex,
          progress: next,
        ),
      );

      final isCourseCompleteNow = CourseProgress.isCourseComplete(course, next);
      courseJustCompleted = !wasCourseCompleteBefore && isCourseCompleteNow;

      if (isPerfect) {
        next = next.copyWith(gems: next.gems + GameConstants.gemsPerPerfectLesson);
      }
    }

    final gemsEarnedSoFar = isPerfect && creditsLesson
        ? GameConstants.gemsPerPerfectLesson
        : 0;

    return _finalizeAward(
      before: before,
      next: next,
      totalXpEarned: totalXpEarned,
      gemsEarnedSoFar: gemsEarnedSoFar,
      isPerfectLesson: isPerfect && creditsLesson,
      unitJustCompleted: unitJustCompleted,
      courseJustCompleted: courseJustCompleted,
    );
  }

  /// Applies the outcome of a finished Fun-game round: XP/coins go into
  /// the same totals lessons use, and [vocabDeltas] (vocabId -> +1/-1)
  /// update the same `vocabStrength` map lessons read and write — Fun
  /// and lessons are one shared mastery system, not two.
  LessonCompletionResult awardFunSession({
    required int xpEarned,
    required int coinsEarned,
    required Map<String, int> vocabDeltas,
    required bool isPerfectRound,
    required bool isSpeedRound,
  }) {
    final before = state;

    var next = before.copyWith(
      totalXp: before.totalXp + xpEarned,
      dailyXp: before.dailyXp + xpEarned,
      weeklyXp: before.weeklyXp + xpEarned,
      gems: before.gems + coinsEarned,
    );

    final vocabStrength = Map<String, int>.from(next.vocabStrength);
    vocabDeltas.forEach((id, delta) {
      vocabStrength[id] = ((vocabStrength[id] ?? 0) + delta).clamp(-2, 5);
    });
    next = next.copyWith(vocabStrength: vocabStrength);

    var gemsEarnedSoFar = coinsEarned;
    if (isPerfectRound) {
      gemsEarnedSoFar += GameConstants.gemsPerPerfectLesson;
      next = next.copyWith(gems: next.gems + GameConstants.gemsPerPerfectLesson);
    }

    return _finalizeAward(
      before: before,
      next: next,
      totalXpEarned: xpEarned,
      gemsEarnedSoFar: gemsEarnedSoFar,
      isPerfectFunRound: isPerfectRound,
      isSpeedRound: isSpeedRound,
    );
  }

  /// Shared tail of [completeLessonSession] and [awardFunSession]:
  /// streak crediting, daily-goal-just-reached detection, achievement
  /// evaluation/payout, persistence, and building the one result type
  /// both result-screen chains read.
  LessonCompletionResult _finalizeAward({
    required UserProgress before,
    required UserProgress next,
    required int totalXpEarned,
    required int gemsEarnedSoFar,
    bool isPerfectLesson = false,
    bool unitJustCompleted = false,
    bool courseJustCompleted = false,
    bool isPerfectFunRound = false,
    bool isSpeedRound = false,
  }) {
    final now = DateTime.now();
    final oldLevel = XpUtils.levelForXp(before.totalXp);
    final dailyGoalMetBefore = DailyGoalLogic.isGoalMet(before);

    final streakCountBefore = next.streakCount;
    next = StreakLogic.creditIfGoalMet(next, now);
    final streakContinued = next.streakCount > streakCountBefore;
    final dailyGoalJustReached =
        !dailyGoalMetBefore && DailyGoalLogic.isGoalMet(next);

    final newAchievements = AchievementLogic.evaluateNewlyUnlocked(
      next,
      isPerfectLesson: isPerfectLesson,
      unitJustCompleted: unitJustCompleted,
      courseJustCompleted: courseJustCompleted,
      isPerfectFunRound: isPerfectFunRound,
      isSpeedRound: isSpeedRound,
    );
    var gemsEarned = gemsEarnedSoFar;
    if (newAchievements.isNotEmpty) {
      gemsEarned += newAchievements.length * GameConstants.gemsPerAchievement;
      next = next.copyWith(
        unlockedAchievementIds: {
          ...next.unlockedAchievementIds,
          ...newAchievements.map((a) => a.name),
        },
        gems: next.gems + newAchievements.length * GameConstants.gemsPerAchievement,
      );
    }

    final newLevel = XpUtils.levelForXp(next.totalXp);

    _persist(next);

    return LessonCompletionResult(
      xpEarned: totalXpEarned,
      gemsEarned: gemsEarned,
      newTotalXp: next.totalXp,
      leveledUp: newLevel > oldLevel,
      newLevel: newLevel,
      streakContinued: streakContinued,
      newStreakCount: next.streakCount,
      dailyGoalJustReached: dailyGoalJustReached,
      newAchievements: newAchievements,
      unitJustCompleted: unitJustCompleted,
      courseJustCompleted: courseJustCompleted,
      outOfHearts: next.hearts <= 0,
    );
  }
}

final progressProvider = NotifierProvider<ProgressController, UserProgress>(
  ProgressController.new,
);

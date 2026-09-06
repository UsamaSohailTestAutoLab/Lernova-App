import '../../data/models/fun_progress.dart';
import 'date_utils.dart';

/// Pure reconcile-on-resume for the daily Fun word challenge — same
/// shape as [DailyGoalLogic] so the two rollover behaviors stay
/// consistent even though they track different things.
class FunDailyChallengeLogic {
  FunDailyChallengeLogic._();

  static const targetWordCount = 10;

  static FunProgress reconcileOnResume(FunProgress progress, DateTime now) {
    if (AppDateUtils.isSameDay(progress.dailyChallengeDate, now)) return progress;
    return progress.copyWith(
      dailyChallengeDate: AppDateUtils.dateOnly(now),
      dailyChallengeWordIds: const {},
      dailyChallengeCompletedToday: false,
    );
  }

  static bool isComplete(FunProgress progress) =>
      progress.dailyChallengeWordIds.length >= targetWordCount;

  static double progressRatio(FunProgress progress) {
    return (progress.dailyChallengeWordIds.length / targetWordCount).clamp(0, 1);
  }
}

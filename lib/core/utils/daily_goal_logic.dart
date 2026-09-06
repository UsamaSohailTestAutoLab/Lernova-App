import '../../data/models/user_progress.dart';
import 'date_utils.dart';

class DailyGoalLogic {
  DailyGoalLogic._();

  /// Resets the daily counters when the calendar day has rolled over.
  static UserProgress reconcileOnResume(UserProgress progress, DateTime now) {
    var next = progress;
    if (!AppDateUtils.isSameDay(progress.dailyGoalDate, now)) {
      next = next.copyWith(dailyXp: 0, dailyGoalDate: AppDateUtils.dateOnly(now));
    }
    if (!AppDateUtils.isSameDay(progress.lessonsCompletedTodayDate, now)) {
      next = next.copyWith(
        lessonsCompletedToday: 0,
        lessonsCompletedTodayDate: AppDateUtils.dateOnly(now),
      );
    }
    return next;
  }

  static bool isGoalMet(UserProgress progress) =>
      progress.dailyXp >= progress.dailyGoalXp;

  static double progressRatio(UserProgress progress) {
    if (progress.dailyGoalXp <= 0) return 1;
    return (progress.dailyXp / progress.dailyGoalXp).clamp(0, 1);
  }
}

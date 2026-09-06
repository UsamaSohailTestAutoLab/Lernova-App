import '../../data/models/user_progress.dart';
import 'date_utils.dart';

/// Pure streak reconciliation: decides, purely from dates, whether a
/// streak survives a day boundary, gets consumed by a freeze, or breaks.
class StreakLogic {
  StreakLogic._();

  /// Called once when the app resumes / progress is loaded, before any
  /// new XP is earned today.
  static UserProgress reconcileOnResume(UserProgress progress, DateTime now) {
    if (progress.lastStreakDate == null) return progress;

    if (AppDateUtils.isSameDay(progress.lastStreakDate!, now)) {
      return progress; // already credited today
    }
    if (AppDateUtils.isYesterday(progress.lastStreakDate!, now)) {
      return progress; // still within grace, not broken yet
    }

    // More than one day has passed since the streak was last credited.
    if (progress.streakFreezeAvailable) {
      return progress.copyWith(
        streakFreezeAvailable: false,
        lastStreakDate: AppDateUtils.dateOnly(now).subtract(const Duration(days: 1)),
      );
    }

    return progress.copyWith(streakCount: 0, clearLastStreakDate: true);
  }

  /// Called after XP is added for the day; increments the streak the
  /// first time the daily goal is met on a given calendar day.
  static UserProgress creditIfGoalMet(UserProgress progress, DateTime now) {
    if (progress.dailyXp < progress.dailyGoalXp) return progress;
    if (progress.lastStreakDate != null &&
        AppDateUtils.isSameDay(progress.lastStreakDate!, now)) {
      return progress; // already credited today
    }
    return progress.copyWith(
      streakCount: progress.streakCount + 1,
      lastStreakDate: AppDateUtils.dateOnly(now),
    );
  }
}

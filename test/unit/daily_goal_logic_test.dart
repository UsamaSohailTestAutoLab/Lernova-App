import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/utils/daily_goal_logic.dart';
import 'package:lernova/data/models/user_progress.dart';

void main() {
  UserProgress progress({
    required DateTime dailyGoalDate,
    int dailyXp = 0,
    int dailyGoalXp = 20,
    int lessonsCompletedToday = 0,
    required DateTime lessonsCompletedTodayDate,
  }) {
    return UserProgress(
      dailyXp: dailyXp,
      dailyGoalXp: dailyGoalXp,
      dailyGoalDate: dailyGoalDate,
      lessonsCompletedToday: lessonsCompletedToday,
      lessonsCompletedTodayDate: lessonsCompletedTodayDate,
      weekId: '2026-W02',
    );
  }

  group('DailyGoalLogic.reconcileOnResume', () {
    test('keeps counters when still the same day', () {
      final today = DateTime(2026, 1, 10);
      final p = progress(
        dailyGoalDate: today,
        dailyXp: 15,
        lessonsCompletedToday: 2,
        lessonsCompletedTodayDate: today,
      );
      final result = DailyGoalLogic.reconcileOnResume(p, today);
      expect(result.dailyXp, 15);
      expect(result.lessonsCompletedToday, 2);
    });

    test('resets dailyXp and lesson count once the day rolls over', () {
      final yesterday = DateTime(2026, 1, 9);
      final today = DateTime(2026, 1, 10);
      final p = progress(
        dailyGoalDate: yesterday,
        dailyXp: 40,
        lessonsCompletedToday: 4,
        lessonsCompletedTodayDate: yesterday,
      );
      final result = DailyGoalLogic.reconcileOnResume(p, today);
      expect(result.dailyXp, 0);
      expect(result.lessonsCompletedToday, 0);
      expect(result.dailyGoalDate, today);
    });
  });

  group('DailyGoalLogic.isGoalMet / progressRatio', () {
    test('goal not met below target', () {
      final today = DateTime(2026, 1, 10);
      final p = progress(
        dailyGoalDate: today,
        dailyXp: 10,
        dailyGoalXp: 20,
        lessonsCompletedTodayDate: today,
      );
      expect(DailyGoalLogic.isGoalMet(p), isFalse);
      expect(DailyGoalLogic.progressRatio(p), 0.5);
    });

    test('goal met at or above target, ratio clamped to 1', () {
      final today = DateTime(2026, 1, 10);
      final p = progress(
        dailyGoalDate: today,
        dailyXp: 30,
        dailyGoalXp: 20,
        lessonsCompletedTodayDate: today,
      );
      expect(DailyGoalLogic.isGoalMet(p), isTrue);
      expect(DailyGoalLogic.progressRatio(p), 1.0);
    });
  });
}

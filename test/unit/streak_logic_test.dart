import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/utils/streak_logic.dart';
import 'package:lingoquest/data/models/user_progress.dart';

UserProgress _progress({
  int streakCount = 0,
  DateTime? lastStreakDate,
  bool streakFreezeAvailable = false,
  int dailyXp = 0,
  int dailyGoalXp = 20,
}) {
  final now = DateTime(2026, 1, 10);
  return UserProgress(
    streakCount: streakCount,
    lastStreakDate: lastStreakDate,
    streakFreezeAvailable: streakFreezeAvailable,
    dailyXp: dailyXp,
    dailyGoalXp: dailyGoalXp,
    dailyGoalDate: now,
    lessonsCompletedTodayDate: now,
    weekId: '2026-W02',
  );
}

void main() {
  group('StreakLogic.reconcileOnResume', () {
    test('untouched when streak already credited today', () {
      final today = DateTime(2026, 1, 10);
      final p = _progress(streakCount: 5, lastStreakDate: today);
      final result = StreakLogic.reconcileOnResume(p, today);
      expect(result.streakCount, 5);
    });

    test('untouched when last credited yesterday (still within grace)', () {
      final today = DateTime(2026, 1, 10);
      final yesterday = DateTime(2026, 1, 9);
      final p = _progress(streakCount: 5, lastStreakDate: yesterday);
      final result = StreakLogic.reconcileOnResume(p, today);
      expect(result.streakCount, 5);
    });

    test('breaks the streak after a fully missed day with no freeze', () {
      final today = DateTime(2026, 1, 10);
      final twoDaysAgo = DateTime(2026, 1, 8);
      final p = _progress(streakCount: 5, lastStreakDate: twoDaysAgo);
      final result = StreakLogic.reconcileOnResume(p, today);
      expect(result.streakCount, 0);
      expect(result.lastStreakDate, isNull);
    });

    test('a streak freeze consumes itself instead of breaking the streak', () {
      final today = DateTime(2026, 1, 10);
      final twoDaysAgo = DateTime(2026, 1, 8);
      final p = _progress(
        streakCount: 5,
        lastStreakDate: twoDaysAgo,
        streakFreezeAvailable: true,
      );
      final result = StreakLogic.reconcileOnResume(p, today);
      expect(result.streakCount, 5);
      expect(result.streakFreezeAvailable, isFalse);
    });
  });

  group('StreakLogic.creditIfGoalMet', () {
    test('does not credit when the goal is not met', () {
      final today = DateTime(2026, 1, 10);
      final p = _progress(streakCount: 2, dailyXp: 5, dailyGoalXp: 20);
      final result = StreakLogic.creditIfGoalMet(p, today);
      expect(result.streakCount, 2);
    });

    test('credits once when the goal is met and not yet credited today', () {
      final today = DateTime(2026, 1, 10);
      final p = _progress(streakCount: 2, dailyXp: 25, dailyGoalXp: 20);
      final result = StreakLogic.creditIfGoalMet(p, today);
      expect(result.streakCount, 3);
      expect(result.lastStreakDate, DateTime(2026, 1, 10));
    });

    test('does not double-credit the same day', () {
      final today = DateTime(2026, 1, 10);
      final p = _progress(
        streakCount: 3,
        dailyXp: 40,
        dailyGoalXp: 20,
        lastStreakDate: today,
      );
      final result = StreakLogic.creditIfGoalMet(p, today);
      expect(result.streakCount, 3);
    });
  });
}

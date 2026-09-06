import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/utils/hearts_logic.dart';
import 'package:lernova/data/models/user_progress.dart';

UserProgress _progress({
  int hearts = 5,
  DateTime? lastHeartLostAt,
  bool isPremium = false,
}) {
  final now = DateTime(2026, 1, 1);
  return UserProgress(
    hearts: hearts,
    lastHeartLostAt: lastHeartLostAt,
    isPremium: isPremium,
    dailyGoalDate: now,
    lessonsCompletedTodayDate: now,
    weekId: '2026-W01',
  );
}

void main() {
  group('HeartsLogic.regenerate', () {
    test('does nothing when hearts are already full', () {
      final p = _progress(hearts: 5);
      final result = HeartsLogic.regenerate(p, DateTime(2026, 1, 1, 12));
      expect(result.hearts, 5);
    });

    test('does nothing before a full interval has passed', () {
      final lostAt = DateTime(2026, 1, 1, 10);
      final p = _progress(hearts: 3, lastHeartLostAt: lostAt);
      final result = HeartsLogic.regenerate(p, lostAt.add(const Duration(hours: 2)));
      expect(result.hearts, 3);
    });

    test('regenerates one heart after exactly one interval', () {
      final lostAt = DateTime(2026, 1, 1, 10);
      final p = _progress(hearts: 3, lastHeartLostAt: lostAt);
      final result = HeartsLogic.regenerate(p, lostAt.add(const Duration(hours: 4)));
      expect(result.hearts, 4);
    });

    test('caps regeneration at max hearts and clears the timestamp', () {
      final lostAt = DateTime(2026, 1, 1, 10);
      final p = _progress(hearts: 3, lastHeartLostAt: lostAt);
      final result = HeartsLogic.regenerate(p, lostAt.add(const Duration(hours: 20)));
      expect(result.hearts, 5);
      expect(result.lastHeartLostAt, isNull);
    });

    // Pro unlocks content, not hearts. A premium learner regenerates on
    // exactly the same terms as everyone else — which costs them nothing,
    // since every attempt starts with a full budget regardless.
    test('premium is not a heart perk', () {
      final lostAt = DateTime(2026, 1, 1, 10);
      final free = _progress(hearts: 1, lastHeartLostAt: lostAt);
      final pro = _progress(hearts: 1, lastHeartLostAt: lostAt, isPremium: true);
      final at = lostAt.add(const Duration(hours: 4));

      expect(
        HeartsLogic.regenerate(pro, at).hearts,
        HeartsLogic.regenerate(free, at).hearts,
      );
    });
  });

  group('HeartsLogic.nextHeartAt', () {
    test('null when hearts are full', () {
      expect(HeartsLogic.nextHeartAt(_progress(hearts: 5)), isNull);
    });

    test('null when nothing has been lost yet', () {
      expect(HeartsLogic.nextHeartAt(_progress(hearts: 1)), isNull);
    });

    test('returns lastHeartLostAt + interval otherwise', () {
      final lostAt = DateTime(2026, 1, 1, 10);
      final next = HeartsLogic.nextHeartAt(_progress(hearts: 2, lastHeartLostAt: lostAt));
      expect(next, lostAt.add(const Duration(hours: 4)));
    });
  });
}

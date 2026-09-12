import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/utils/league_logic.dart';

void main() {
  group('LeagueLogic.resolveNextTier', () {
    test('top-3-of-10 promotes to the next tier', () {
      final result = LeagueLogic.resolveNextTier(
        currentTier: LeagueTier.silver,
        userWeeklyXp: 500,
        cohortWeeklyXp: [100, 90, 80, 70, 60, 50, 40, 30, 20],
      );
      expect(result, LeagueTier.gold);
    });

    test('bottom-3-of-10 demotes to the previous tier', () {
      final result = LeagueLogic.resolveNextTier(
        currentTier: LeagueTier.silver,
        userWeeklyXp: 1,
        cohortWeeklyXp: [100, 90, 80, 70, 60, 50, 40, 30, 20],
      );
      expect(result, LeagueTier.bronze);
    });

    test('middle of the pack holds the same tier', () {
      final result = LeagueLogic.resolveNextTier(
        currentTier: LeagueTier.gold,
        userWeeklyXp: 55,
        cohortWeeklyXp: [100, 90, 80, 70, 60, 50, 40, 30, 20],
      );
      expect(result, LeagueTier.gold);
    });

    test('cannot promote past diamond', () {
      final result = LeagueLogic.resolveNextTier(
        currentTier: LeagueTier.diamond,
        userWeeklyXp: 500,
        cohortWeeklyXp: [100, 90, 80, 70, 60, 50, 40, 30, 20],
      );
      expect(result, LeagueTier.diamond);
    });

    test('cannot demote past bronze', () {
      final result = LeagueLogic.resolveNextTier(
        currentTier: LeagueTier.bronze,
        userWeeklyXp: 0,
        cohortWeeklyXp: [100, 90, 80, 70, 60, 50, 40, 30, 20],
      );
      expect(result, LeagueTier.bronze);
    });
  });
}

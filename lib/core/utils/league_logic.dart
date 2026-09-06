import '../constants/app_enums.dart';

/// Pure weekly league promotion/demotion: given the user's placement
/// among the bot cohort, decide the next tier. Top-3-of-10 promotes,
/// bottom-3-of-10 demotes, the middle holds.
class LeagueLogic {
  LeagueLogic._();

  static LeagueTier resolveNextTier({
    required LeagueTier currentTier,
    required int userWeeklyXp,
    required List<int> cohortWeeklyXp,
  }) {
    final all = [...cohortWeeklyXp, userWeeklyXp]..sort((a, b) => b.compareTo(a));
    final rank = all.indexOf(userWeeklyXp) + 1;
    final total = all.length;

    final promoteCutoff = (total * 0.3).ceil();
    final demoteCutoff = total - (total * 0.3).ceil();

    if (rank <= promoteCutoff) {
      return currentTier.next ?? currentTier;
    }
    if (rank > demoteCutoff) {
      return currentTier.previous ?? currentTier;
    }
    return currentTier;
  }
}

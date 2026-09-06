import '../models/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// A deterministic bot cohort for the given week — same seed always
  /// produces the same names/XP so it doesn't feel random.
  List<LeaderboardEntry> generateCohort(String weekId);
}

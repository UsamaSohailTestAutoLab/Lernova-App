import 'dart:math';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';

/// Generates a believable weekly league cohort without a backend. The
/// bot roster and their XP are derived deterministically from the week
/// id, so the same week always reproduces the same leaderboard and it
/// only changes when a new ISO week begins.
class LocalLeaderboardRepository implements LeaderboardRepository {
  static const _names = [
    'Maya R.', 'Theo K.', 'Priya S.', 'Noah B.', 'Elena V.',
    'Kofi A.', 'Sana M.', 'Lucas F.', 'Ingrid H.', 'Tomas Q.',
    'Aiko N.', 'Diego P.',
  ];

  @override
  List<LeaderboardEntry> generateCohort(String weekId) {
    final seed = weekId.hashCode;
    final random = Random(seed);
    final shuffled = List<String>.from(_names)..shuffle(random);
    final bots = shuffled.take(9).toList();

    return List.generate(bots.length, (i) {
      final baseXp = 180 - (i * 14);
      final jitter = random.nextInt(25);
      return LeaderboardEntry(
        id: 'bot_${bots[i].hashCode}',
        name: bots[i],
        avatarSeed: bots[i],
        weeklyXp: (baseXp + jitter).clamp(5, 400),
      );
    });
  }
}

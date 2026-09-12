/// Fun-tab-only progress: per-game-mode level/combo/star tallies and the
/// daily word challenge. Deliberately separate from [UserProgress] (which
/// owns XP/streak/vocab-mastery — Fun reuses those directly) since
/// this is purely "how far has this player gotten in each mini-game."
class FunProgress {
  final Map<String, int> gameLevels;
  final Map<String, int> gameBestCombo;
  final Map<String, int> gameStars;
  final DateTime dailyChallengeDate;
  final Set<String> dailyChallengeWordIds;
  final bool dailyChallengeCompletedToday;

  const FunProgress({
    this.gameLevels = const {},
    this.gameBestCombo = const {},
    this.gameStars = const {},
    required this.dailyChallengeDate,
    this.dailyChallengeWordIds = const {},
    this.dailyChallengeCompletedToday = false,
  });

  factory FunProgress.initial() {
    final today = DateTime.now();
    return FunProgress(dailyChallengeDate: DateTime(today.year, today.month, today.day));
  }

  int levelFor(String gameModeId) => gameLevels[gameModeId] ?? 1;
  int bestComboFor(String gameModeId) => gameBestCombo[gameModeId] ?? 0;
  int starsFor(String gameModeId) => gameStars[gameModeId] ?? 0;

  /// Fun levels actually cleared, summed across every mode.
  ///
  /// A mode's stored level is the one you are *on*, not the number you
  /// have beaten — a mode sitting at level 1 has cleared none. Modes
  /// never played are simply absent and contribute nothing.
  int get levelsCleared => gameLevels.values
      .fold(0, (sum, level) => sum + (level - 1).clamp(0, level));

  /// How many different Fun games have been played at least once.
  int get modesPlayed => gameLevels.values.where((level) => level > 1).length;

  FunProgress copyWith({
    Map<String, int>? gameLevels,
    Map<String, int>? gameBestCombo,
    Map<String, int>? gameStars,
    DateTime? dailyChallengeDate,
    Set<String>? dailyChallengeWordIds,
    bool? dailyChallengeCompletedToday,
  }) {
    return FunProgress(
      gameLevels: gameLevels ?? this.gameLevels,
      gameBestCombo: gameBestCombo ?? this.gameBestCombo,
      gameStars: gameStars ?? this.gameStars,
      dailyChallengeDate: dailyChallengeDate ?? this.dailyChallengeDate,
      dailyChallengeWordIds: dailyChallengeWordIds ?? this.dailyChallengeWordIds,
      dailyChallengeCompletedToday:
          dailyChallengeCompletedToday ?? this.dailyChallengeCompletedToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'gameLevels': gameLevels,
        'gameBestCombo': gameBestCombo,
        'gameStars': gameStars,
        'dailyChallengeDate': dailyChallengeDate.toIso8601String(),
        'dailyChallengeWordIds': dailyChallengeWordIds.toList(),
        'dailyChallengeCompletedToday': dailyChallengeCompletedToday,
      };

  factory FunProgress.fromJson(Map<String, dynamic> json) {
    return FunProgress(
      gameLevels: (json['gameLevels'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as int),
      ),
      gameBestCombo: (json['gameBestCombo'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as int),
      ),
      gameStars: (json['gameStars'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, v as int),
      ),
      dailyChallengeDate: DateTime.parse(json['dailyChallengeDate'] as String),
      dailyChallengeWordIds:
          (json['dailyChallengeWordIds'] as List? ?? []).cast<String>().toSet(),
      dailyChallengeCompletedToday:
          json['dailyChallengeCompletedToday'] as bool? ?? false,
    );
  }
}

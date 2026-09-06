import '../../../core/constants/app_enums.dart';

/// Difficulty knobs for a single Fun-game round, produced by
/// `FunLevelCatalog.configFor`.
class FunLevelConfig {
  final int level;
  final int wordCount;

  /// How many *pairs* a grid-shaped mode deals per round (Word Match,
  /// Memory Match). Grows with level — a bigger grid is genuinely
  /// harder there, and nothing overlaps because the layout is a grid.
  final int choiceCount;

  /// How many answer bubbles a single question offers. Deliberately
  /// capped at 2–3 at every level: a screenful of bubbles is clutter,
  /// not difficulty. Bubble games get harder through vocabulary, speed
  /// and distractor quality instead.
  final int bubbleOptionCount;

  final Duration fallDuration;
  final List<FunQuestionType> allowedTypes;
  final bool comboEnabled;
  final int maxLives;

  const FunLevelConfig({
    required this.level,
    required this.wordCount,
    required this.choiceCount,
    this.bubbleOptionCount = 3,
    required this.fallDuration,
    required this.allowedTypes,
    required this.comboEnabled,
    required this.maxLives,
  });
}

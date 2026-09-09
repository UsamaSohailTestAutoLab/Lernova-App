import '../../../core/constants/app_enums.dart';
import '../../../data/models/fun/fun_level_config.dart';

/// Produces a [FunLevelConfig] from a level number by formula, not a
/// hardcoded table — the spec explicitly wants difficulty to keep
/// scaling indefinitely past level 10, which a fixed table can't do.
/// [mode] applies each mode's own tuning/type restriction on top of the
/// same underlying curve — Word Rush is faster with combo always on,
/// Listen & Catch is audio-only, Phrase Builder is phrase-only, Meaning
/// Shooter uses the normal progressive type set.
///
/// Fall speed is intentionally held constant for every mode except Word
/// Rush (whose whole identity is speed) — difficulty for the rest comes
/// entirely from requiring more correct words per round, with lives
/// scaling up alongside word count so a longer round doesn't become
/// disproportionately risky purely from having more chances to miss.
class FunLevelCatalog {
  FunLevelCatalog._();

  static FunLevelConfig configFor(int level, {FunGameMode mode = FunGameMode.fallingWords}) {
    final clampedLevel = level < 1 ? 1 : level;
    final isRush = mode == FunGameMode.wordRush;

    final wordCount =
        isRush ? rushWordCountForLevel(clampedLevel) : wordCountForLevel(clampedLevel);
    final choiceCount = (3 + (clampedLevel ~/ 2)).clamp(3, 6);

    // Bubble games stay at 2–3 options forever. Piling more bubbles on
    // screen at higher levels made the board unreadable (and, at 5–6,
    // physically unlayoutable on a phone) without making the *language*
    // any harder — that job belongs to the word pool, the timer and the
    // quality of the distractors.
    final bubbleOptionCount = clampedLevel <= 1 ? 2 : 3;

    // Word Rush is *fast*, but it does not get faster.
    //
    // It used to shave 250ms off every level down to a 1300ms floor,
    // which by level 8 left barely a second to read a word — the mode
    // stopped being a language game and became a reaction test, and
    // failure came from not seeing the word rather than not knowing it.
    // Its difficulty now comes from round length, like every other mode:
    // the same brisk speed, more words to get through.
    final fallMs = isRush ? rushFallMs : 6000;

    final types = _typesFor(mode, clampedLevel);

    return FunLevelConfig(
      level: clampedLevel,
      wordCount: wordCount,
      choiceCount: choiceCount,
      bubbleOptionCount: bubbleOptionCount,
      fallDuration: Duration(milliseconds: fallMs),
      allowedTypes: types,
      comboEnabled: isRush || clampedLevel >= 6,
      // Lives follow word count in Word Rush too, now that its rounds
      // grow. Three lives across fourteen words is brisk; three across
      // sixty is a coin toss, and the same reasoning that scales lives
      // everywhere else applies once the round length is what moves.
      maxLives: _livesFor(wordCount),
    );
  }

  /// Word Rush's constant fall speed — twice as quick as the other
  /// modes' 6000ms, which is what makes it "rush", and unchanging so the
  /// mode stays readable at every level.
  static const int rushFallMs = 3000;

  /// Words a Word Rush round asks for at [level]: 14 to start, six more
  /// each level, capped at the authored word bank like every other mode.
  ///
  /// A gentler curve than [wordCountForLevel]'s doubling — these words
  /// arrive twice as fast, so the same count is a good deal more work.
  static int rushWordCountForLevel(int level) {
    final count = 14 + (level - 1) * 6;
    return count > maxWordsPerRound ? maxWordsPerRound : count;
  }

  /// Words a round asks for at [level]: 10 to start, doubling each
  /// level, capped at [maxWordsPerRound]. The cap is deliberate — past
  /// the size of the authored word bank a longer round can only pad
  /// itself by repeating the same words, which isn't more learning.
  /// Shared with Learner Mate so both surfaces grow on one curve.
  static int wordCountForLevel(int level) {
    if (level >= 4) return maxWordsPerRound; // 10 * 2^3 already hits the cap
    return 10 * (1 << (level - 1));
  }

  /// Ceiling on one round's length, sized to the largest authored word
  /// bank (Spanish, 79 words). Raise this when more vocabulary lands.
  static const int maxWordsPerRound = 80;

  /// Lives budget grows in step with round length so mistakes stay a
  /// roughly constant *fraction* of the round instead of an increasingly
  /// tight absolute cap.
  static int _livesFor(int wordCount) {
    if (wordCount <= 8) return 3;
    if (wordCount <= 16) return 4;
    if (wordCount <= 24) return 5;
    if (wordCount <= 32) return 6;
    if (wordCount <= 48) return 7;
    if (wordCount <= 64) return 8;
    return 9;
  }

  static List<FunQuestionType> _typesFor(FunGameMode mode, int level) {
    if (mode == FunGameMode.listenAndCatch) {
      return const [FunQuestionType.audioToMeaning];
    }
    if (mode == FunGameMode.phraseBuilder) {
      return const [FunQuestionType.phraseToMeaning, FunQuestionType.meaningToPhrase];
    }

    final types = <FunQuestionType>[
      FunQuestionType.wordToMeaning,
      FunQuestionType.meaningToWord,
    ];
    if (level >= 3) {
      types.addAll([FunQuestionType.imageToWord, FunQuestionType.wordToImage]);
    }
    if (level >= 4) {
      types.addAll([FunQuestionType.phraseToMeaning, FunQuestionType.meaningToPhrase]);
    }
    if (level >= 5) {
      types.add(FunQuestionType.audioToMeaning);
    }
    if (level >= 7) {
      types.addAll([FunQuestionType.wordToSynonym, FunQuestionType.wordToOpposite]);
    }
    return types;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/features/fun/application/fun_level_catalog.dart';

void main() {
  group('FunLevelCatalog.configFor', () {
    test('level 1 starts at 10 words, few choices, slow fall', () {
      final config = FunLevelCatalog.configFor(1);
      expect(config.wordCount, 10);
      expect(config.choiceCount, 3);
      expect(config.fallDuration, const Duration(milliseconds: 6000));
      expect(config.comboEnabled, isFalse);
    });

    test('word count doubles each level from 10', () {
      expect(FunLevelCatalog.configFor(1).wordCount, 10);
      expect(FunLevelCatalog.configFor(2).wordCount, 20);
      expect(FunLevelCatalog.configFor(3).wordCount, 40);
    });

    test('word count caps at the authored word bank rather than padding with repeats', () {
      expect(FunLevelCatalog.configFor(4).wordCount, FunLevelCatalog.maxWordsPerRound);
      expect(FunLevelCatalog.configFor(10).wordCount, FunLevelCatalog.maxWordsPerRound);
      expect(FunLevelCatalog.configFor(100).wordCount, FunLevelCatalog.maxWordsPerRound);
    });

    test('difficulty scales up with level via word/choice count, not speed', () {
      final level1 = FunLevelCatalog.configFor(1);
      final level2 = FunLevelCatalog.configFor(2);
      final level3 = FunLevelCatalog.configFor(3);

      expect(level2.wordCount, greaterThan(level1.wordCount));
      expect(level3.wordCount, greaterThan(level2.wordCount));
      // Choice count keeps climbing past the word-count cap.
      expect(FunLevelCatalog.configFor(10).choiceCount,
          greaterThanOrEqualTo(level1.choiceCount));
    });

    // Regression: bubble counts used to climb to 6, which on a 360dp
    // phone made bubbles wider than their own lanes — and a screenful of
    // options isn't harder language, just a messier board.
    test('bubble games never show more than three options, at any level', () {
      for (final level in [1, 2, 3, 5, 10, 50, 100]) {
        final config = FunLevelCatalog.configFor(level);
        expect(
          config.bubbleOptionCount,
          inInclusiveRange(2, 3),
          reason: 'level $level offered ${config.bubbleOptionCount} bubbles',
        );
      }
    });

    test('every mode keeps the 2-3 bubble cap', () {
      for (final mode in FunGameMode.values) {
        for (final level in [1, 4, 9, 30]) {
          expect(
            FunLevelCatalog.configFor(level, mode: mode).bubbleOptionCount,
            inInclusiveRange(2, 3),
            reason: '${mode.name} at level $level',
          );
        }
      }
    });

    test('grid modes still deal more pairs as levels climb', () {
      // The cap is about bubbles on a playfield, not about grids, where
      // more pairs is genuinely harder and nothing can overlap.
      expect(
        FunLevelCatalog.configFor(10).choiceCount,
        greaterThan(FunLevelCatalog.configFor(1).choiceCount),
      );
    });

    test('fall duration stays constant across levels for non-Rush modes', () {
      final level1 = FunLevelCatalog.configFor(1);
      final level10 = FunLevelCatalog.configFor(10);
      final level100 = FunLevelCatalog.configFor(100);
      expect(level1.fallDuration.inMilliseconds, 6000);
      expect(level10.fallDuration.inMilliseconds, 6000);
      expect(level100.fallDuration.inMilliseconds, 6000);
    });

    test('Word Rush fall duration still ramps up and never drops below its floor', () {
      final rush1 = FunLevelCatalog.configFor(1, mode: FunGameMode.wordRush);
      final rush100 = FunLevelCatalog.configFor(100, mode: FunGameMode.wordRush);
      expect(rush100.fallDuration.inMilliseconds, lessThan(rush1.fallDuration.inMilliseconds));
      expect(rush100.fallDuration.inMilliseconds, greaterThanOrEqualTo(1300));
    });

    test('lives scale up with word count so longer rounds stay survivable', () {
      expect(FunLevelCatalog.configFor(1).maxLives, 4); // wordCount 10
      expect(FunLevelCatalog.configFor(2).maxLives, 5); // wordCount 20
      expect(FunLevelCatalog.configFor(3).maxLives, 7); // wordCount 40
      expect(FunLevelCatalog.configFor(4).maxLives, 9); // wordCount 80 (cap)

      // Never fewer lives as a round gets longer.
      final lives = [1, 2, 3, 4].map((l) => FunLevelCatalog.configFor(l).maxLives).toList();
      final sorted = [...lives]..sort();
      expect(lives, sorted);
    });

    test('Word Rush keeps a fixed 3 lives regardless of level', () {
      expect(FunLevelCatalog.configFor(1, mode: FunGameMode.wordRush).maxLives, 3);
      expect(FunLevelCatalog.configFor(20, mode: FunGameMode.wordRush).maxLives, 3);
    });

    test('question types unlock cumulatively as level increases', () {
      final level1 = FunLevelCatalog.configFor(1);
      expect(level1.allowedTypes, isNot(contains(FunQuestionType.imageToWord)));
      expect(level1.allowedTypes, isNot(contains(FunQuestionType.audioToMeaning)));
      expect(level1.allowedTypes, isNot(contains(FunQuestionType.wordToSynonym)));

      final level3 = FunLevelCatalog.configFor(3);
      expect(level3.allowedTypes, contains(FunQuestionType.imageToWord));
      expect(level3.allowedTypes, contains(FunQuestionType.wordToImage));

      final level5 = FunLevelCatalog.configFor(5);
      expect(level5.allowedTypes, contains(FunQuestionType.audioToMeaning));

      final level7 = FunLevelCatalog.configFor(7);
      expect(level7.allowedTypes, contains(FunQuestionType.wordToSynonym));
      expect(level7.allowedTypes, contains(FunQuestionType.wordToOpposite));
    });

    test('combo unlocks from level 6 onward', () {
      expect(FunLevelCatalog.configFor(5).comboEnabled, isFalse);
      expect(FunLevelCatalog.configFor(6).comboEnabled, isTrue);
    });

    test('levels below 1 clamp to level 1', () {
      expect(FunLevelCatalog.configFor(0).level, 1);
      expect(FunLevelCatalog.configFor(-5).level, 1);
    });

    test('Word Rush is always fast with combo enabled regardless of level', () {
      final rushLevel1 = FunLevelCatalog.configFor(1, mode: FunGameMode.wordRush);
      expect(rushLevel1.comboEnabled, isTrue);
      expect(rushLevel1.fallDuration.inMilliseconds, lessThan(6000));
    });

    test('Listen & Catch is restricted to audio-only questions at any level', () {
      final config = FunLevelCatalog.configFor(8, mode: FunGameMode.listenAndCatch);
      expect(config.allowedTypes, [FunQuestionType.audioToMeaning]);
    });

    test('Phrase Builder is restricted to phrase questions at any level', () {
      final config = FunLevelCatalog.configFor(1, mode: FunGameMode.phraseBuilder);
      expect(
        config.allowedTypes,
        containsAll([FunQuestionType.phraseToMeaning, FunQuestionType.meaningToPhrase]),
      );
      expect(config.allowedTypes, isNot(contains(FunQuestionType.wordToMeaning)));
    });
  });
}

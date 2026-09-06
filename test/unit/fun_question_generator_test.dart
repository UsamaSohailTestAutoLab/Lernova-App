import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/data/models/fun/fun_level_config.dart';
import 'package:lernova/data/models/fun/phrase.dart';
import 'package:lernova/data/models/fun/vocab_word.dart';
import 'package:lernova/features/fun/application/fun_question_generator.dart';

List<VocabWord> _words() => const [
      VocabWord(id: 'w1', word: 'Hola', translation: 'Hello', languageId: 'es', category: 'g', emoji: '👋'),
      VocabWord(id: 'w2', word: 'Adiós', translation: 'Goodbye', languageId: 'es', category: 'g', emoji: '👋'),
      VocabWord(id: 'w3', word: 'Gracias', translation: 'Thanks', languageId: 'es', category: 'g'),
      VocabWord(
        id: 'w4',
        word: 'Feliz',
        translation: 'Happy',
        languageId: 'es',
        category: 'd',
        synonyms: ['w5'],
        antonyms: ['w6'],
      ),
      VocabWord(id: 'w5', word: 'Contento', translation: 'Glad', languageId: 'es', category: 'd'),
      VocabWord(id: 'w6', word: 'Triste', translation: 'Sad', languageId: 'es', category: 'd'),
    ];

List<Phrase> _phrases() => const [
      Phrase(id: 'p1', phrase: '¿Cómo estás?', meaning: 'How are you?', languageId: 'es', category: 'q'),
      Phrase(id: 'p2', phrase: 'Buen viaje', meaning: 'Have a good trip', languageId: 'es', category: 't'),
    ];

void main() {
  group('answer options carry their illustration', () {
    test('an emoji is attached to whichever side of the pair is rendered', () {
      final config = FunLevelConfig(
        level: 1,
        wordCount: 6,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 5),
        allowedTypes: const [FunQuestionType.wordToMeaning, FunQuestionType.meaningToWord],
        comboEnabled: false,
        maxLives: 3,
      );
      final questions = FunQuestionGenerator.generateRound(
        words: _words(),
        phrases: const [],
        level: config,
        vocabStrength: const {},
        random: Random(7),
      );

      for (final q in questions) {
        // Aligned index-for-index, so an option can never wear another
        // option's picture.
        expect(q.optionEmojis, hasLength(q.options.length));
        for (var i = 0; i < q.options.length; i++) {
          final option = q.options[i];
          final expected = option == 'Hola' ||
                  option == 'Hello' ||
                  option == 'Adiós' ||
                  option == 'Goodbye'
              ? '👋'
              : null;
          expect(q.emojiFor(i), expected, reason: 'option "$option"');
        }
      }
    });

    test('words with no emoji simply have none — the label still renders', () {
      final config = FunLevelConfig(
        level: 1,
        wordCount: 6,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 5),
        allowedTypes: const [FunQuestionType.wordToMeaning],
        comboEnabled: false,
        maxLives: 3,
      );
      final questions = FunQuestionGenerator.generateRound(
        words: _words(),
        phrases: const [],
        level: config,
        vocabStrength: const {},
        random: Random(3),
      );

      final all = questions.expand((q) => q.optionEmojis).toList();
      expect(all, contains(null));
      expect(questions.every((q) => q.options.every((o) => o.isNotEmpty)), isTrue);
    });

    test('a practice round illustrates its options too', () {
      final questions = FunQuestionGenerator.generatePracticeRound(
        words: _words(),
        vocabIds: const ['w1'],
        choiceCount: 3,
        random: Random(1),
      );
      final q = questions.single;
      expect(q.optionEmojis, hasLength(q.options.length));
      expect(q.emojiFor(q.correctIndex), '👋');
    });
  });

  group('FunQuestionGenerator.generateRound', () {
    test('produces the requested number of questions when the pool allows it', () {
      final config = FunLevelConfig(
        level: 1,
        wordCount: 4,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 5),
        allowedTypes: const [FunQuestionType.wordToMeaning, FunQuestionType.meaningToWord],
        comboEnabled: false,
        maxLives: 3,
      );
      final questions = FunQuestionGenerator.generateRound(
        words: _words(),
        phrases: const [],
        level: config,
        vocabStrength: const {},
        random: Random(42),
      );
      expect(questions.length, 4);
    });

    test('every question only uses allowed types', () {
      final config = FunLevelConfig(
        level: 1,
        wordCount: 6,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 5),
        allowedTypes: const [FunQuestionType.wordToMeaning],
        comboEnabled: false,
        maxLives: 3,
      );
      final questions = FunQuestionGenerator.generateRound(
        words: _words(),
        phrases: const [],
        level: config,
        vocabStrength: const {},
        random: Random(1),
      );
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q.type, FunQuestionType.wordToMeaning);
      }
    });

    test('never puts the correct answer as a duplicate distractor', () {
      final config = FunLevelConfig(
        level: 1,
        wordCount: 6,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 5),
        allowedTypes: const [FunQuestionType.wordToMeaning],
        comboEnabled: false,
        maxLives: 3,
      );
      final questions = FunQuestionGenerator.generateRound(
        words: _words(),
        phrases: const [],
        level: config,
        vocabStrength: const {},
        random: Random(7),
      );
      for (final q in questions) {
        final occurrences = q.options.where((o) => o == q.correctAnswer).length;
        expect(occurrences, 1);
        expect(q.options[q.correctIndex], q.correctAnswer);
      }
    });

    test('skips synonym/antonym types for words without that data', () {
      final config = FunLevelConfig(
        level: 7,
        wordCount: 6,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 3),
        allowedTypes: const [FunQuestionType.wordToSynonym, FunQuestionType.wordToOpposite],
        comboEnabled: true,
        maxLives: 3,
      );
      final questions = FunQuestionGenerator.generateRound(
        words: _words(),
        phrases: const [],
        level: config,
        vocabStrength: const {},
        random: Random(3),
      );
      // Only 'Feliz' (w4) has synonym/antonym data; every generated
      // question must be about that word.
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q.vocabId, 'w4');
      }
    });

    test('adaptively favors low-strength words over many rounds', () {
      final config = FunLevelConfig(
        level: 1,
        wordCount: 1,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 5),
        allowedTypes: const [FunQuestionType.wordToMeaning],
        comboEnabled: false,
        maxLives: 3,
      );
      // w1 is mastered (high strength), w2 is struggling (low strength).
      final vocabStrength = {'w1': 5, 'w2': -2, 'w3': 5, 'w4': 5, 'w5': 5, 'w6': 5};

      var w2Count = 0;
      const trials = 300;
      for (var i = 0; i < trials; i++) {
        final questions = FunQuestionGenerator.generateRound(
          words: _words(),
          phrases: const [],
          level: config,
          vocabStrength: vocabStrength,
          random: Random(i),
        );
        if (questions.isNotEmpty && questions.first.vocabId == 'w2') w2Count++;
      }
      // w2 should come up noticeably more than 1/6 of the time (uniform
      // baseline), since it's weighted far higher than the others.
      expect(w2Count / trials, greaterThan(1 / 6));
    });

    test('mixes in phrase questions when phrase types are allowed', () {
      final config = FunLevelConfig(
        level: 4,
        wordCount: 20,
        choiceCount: 3,
        fallDuration: const Duration(seconds: 4),
        allowedTypes: const [
          FunQuestionType.wordToMeaning,
          FunQuestionType.phraseToMeaning,
          FunQuestionType.meaningToPhrase,
        ],
        comboEnabled: false,
        maxLives: 3,
      );

      // Randomness decides exactly which slots become phrases; check
      // across several seeds so the test isn't pinned to one lucky draw.
      var sawPhraseQuestion = false;
      for (var seed = 0; seed < 10 && !sawPhraseQuestion; seed++) {
        final questions = FunQuestionGenerator.generateRound(
          words: _words(),
          phrases: _phrases(),
          level: config,
          vocabStrength: const {},
          random: Random(seed),
        );
        sawPhraseQuestion = questions.any(
          (q) =>
              q.type == FunQuestionType.phraseToMeaning ||
              q.type == FunQuestionType.meaningToPhrase,
        );
      }
      expect(sawPhraseQuestion, isTrue);
    });
  });

  group('FunQuestionGenerator.generatePracticeRound', () {
    test('builds one word-to-meaning question per requested id', () {
      final questions = FunQuestionGenerator.generatePracticeRound(
        words: _words(),
        vocabIds: ['w1', 'w2'],
        choiceCount: 3,
        random: Random(5),
      );
      expect(questions.length, 2);
      expect(questions.every((q) => q.type == FunQuestionType.wordToMeaning), isTrue);
      expect(questions.map((q) => q.vocabId).toSet(), {'w1', 'w2'});
    });
  });
}

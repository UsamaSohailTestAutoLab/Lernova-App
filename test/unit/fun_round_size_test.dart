import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/data/models/fun/phrase.dart';
import 'package:lernova/data/models/fun/vocab_word.dart';
import 'package:lernova/features/fun/application/fun_level_catalog.dart';
import 'package:lernova/features/fun/application/fun_question_generator.dart';

List<T> _load<T>(String path, T Function(Map<String, dynamic>) fromJson) =>
    (jsonDecode(File(path).readAsStringSync()) as List)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();

void main() {
  final words = _load('assets/data/fun/vocab_es.json', VocabWord.fromJson);
  final phrases = _load('assets/data/fun/phrases_es.json', Phrase.fromJson);

  group('Phrase Builder rounds', () {
    // Phrase Builder allows only phrase question types, so the mixed
    // word/phrase loop spent a 30%-of-round phrase budget and then found
    // no word type to ask for the rest: a level-1 round of 10 came out
    // as 3 questions, and the Review Words step showed 3 cards.
    test('a round is as long as the level asks for, not a 30% slice', () {
      for (final level in [1, 2, 3]) {
        final config = FunLevelCatalog.configFor(level, mode: FunGameMode.phraseBuilder);
        final questions = FunQuestionGenerator.generateRound(
          words: words,
          phrases: phrases,
          level: config,
          vocabStrength: const {},
          random: Random(level),
        );
        final expected =
            config.wordCount < phrases.length ? config.wordCount : phrases.length;
        expect(questions.length, expected, reason: 'level $level');
      }
    });

    test('a round never repeats a phrase', () {
      final config = FunLevelCatalog.configFor(2, mode: FunGameMode.phraseBuilder);
      final questions = FunQuestionGenerator.generateRound(
        words: words,
        phrases: phrases,
        level: config,
        vocabStrength: const {},
        random: Random(7),
      );
      final ids = questions.map((q) => q.vocabId).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('a round can never be longer than the authored phrase pool', () {
      // Level 4+ asks for 80 items; there are far fewer phrases, and
      // padding the round could only repeat them.
      final config = FunLevelCatalog.configFor(6, mode: FunGameMode.phraseBuilder);
      final questions = FunQuestionGenerator.generateRound(
        words: words,
        phrases: phrases,
        level: config,
        vocabStrength: const {},
        random: Random(3),
      );
      expect(questions.length, phrases.length);
    });

    test('no phrases authored means no round rather than a broken one', () {
      final config = FunLevelCatalog.configFor(1, mode: FunGameMode.phraseBuilder);
      expect(
        FunQuestionGenerator.generateRound(
          words: words,
          phrases: const [],
          level: config,
          vocabStrength: const {},
          random: Random(1),
        ),
        isEmpty,
      );
    });
  });

  group('mixed word/phrase modes are unchanged', () {
    test('Meaning Shooter still fills its round from the word pool', () {
      final config = FunLevelCatalog.configFor(1, mode: FunGameMode.meaningShooter);
      final questions = FunQuestionGenerator.generateRound(
        words: words,
        phrases: phrases,
        level: config,
        vocabStrength: const {},
        random: Random(11),
      );
      expect(questions.length, config.wordCount);
    });
  });
}

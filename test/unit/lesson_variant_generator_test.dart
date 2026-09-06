import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/data/models/fun/vocab_word.dart';
import 'package:lernova/data/models/lesson.dart';
import 'package:lernova/features/lessons/application/lesson_variant_generator.dart';

const _words = [
  VocabWord(
    id: 'es_hola',
    word: 'Hola',
    translation: 'Hello',
    languageId: 'es',
    category: 'greetings',
    emoji: '👋',
  ),
  VocabWord(
    id: 'es_gracias',
    word: 'Gracias',
    translation: 'Thank you',
    languageId: 'es',
    category: 'greetings',
    emoji: '🙏',
  ),
  VocabWord(
    id: 'es_adios',
    word: 'Adiós',
    translation: 'Goodbye',
    languageId: 'es',
    category: 'greetings',
    emoji: '👋',
  ),
  VocabWord(
    id: 'es_por_favor',
    word: 'Por favor',
    translation: 'Please',
    languageId: 'es',
    category: 'greetings',
    emoji: '🙇',
  ),
  VocabWord(
    id: 'es_si',
    word: 'Sí',
    translation: 'Yes',
    languageId: 'es',
    category: 'basics',
    emoji: '✅',
  ),
];

Exercise _mc(String id, String vocabId) => Exercise(
      id: id,
      type: ExerciseType.multipleChoice,
      vocabId: vocabId,
      payload: const MultipleChoicePayload(
        prompt: "Which word means 'Hello'?",
        options: ['Hola', 'Gracias'],
        correctIndex: 0,
      ),
    );

final _lesson = Lesson(
  id: 'es_u1_l1',
  title: 'Say Hello',
  subtitle: 'Greetings',
  exercises: [
    _mc('e1', 'es_hola'),
    _mc('e2', 'es_gracias'),
    _mc('e3', 'es_adios'),
    _mc('e4', 'es_por_favor'),
    const Exercise(
      id: 'e5',
      type: ExerciseType.wordMatching,
      vocabId: 'es_greetings_set1',
      payload: WordMatchingPayload(
        prompt: 'Match each word to its meaning',
        pairs: [
          WordPair(left: 'Hola', right: 'Hello'),
          WordPair(left: 'Gracias', right: 'Thank you'),
        ],
      ),
    ),
    const Exercise(
      id: 'e6',
      type: ExerciseType.sentenceArrangement,
      vocabId: 'es_gracias',
      payload: SentenceArrangementPayload(
        prompt: 'Put the words in the right order',
        shuffledChips: ['gracias', 'Muchas'],
        correctSentence: ['Muchas', 'gracias'],
      ),
    ),
  ],
);

void main() {
  group('order', () {
    test('a replay does not present the exercises in the authored order', () {
      // Two different seeds, so this asserts the shuffle happens at all
      // rather than that one particular seed reorders.
      final orders = <List<String>>{};
      for (var seed = 0; seed < 12; seed++) {
        final session = LessonVariantGenerator.buildSession(
          lesson: _lesson,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        orders.add(session.exercises.map((e) => e.id).toList());
      }
      expect(orders.length, greaterThan(1), reason: 'replays should not be identical');
    });

    test('the word-matching summary stays at the end', () {
      // It rounds up everything the lesson taught, so leading with it
      // would be worse than not shuffling at all.
      for (var seed = 0; seed < 12; seed++) {
        final ordered = LessonVariantGenerator.shuffleOrder(_lesson.exercises, Random(seed));
        expect(ordered.last.type, ExerciseType.wordMatching);
      }
    });

    // A retry — after running out of hearts, or just a replay — should
    // open with what the learner actually got wrong, not with what they
    // already know.
    test('previously-missed exercises lead the round', () {
      for (var seed = 0; seed < 12; seed++) {
        final ordered = LessonVariantGenerator.shuffleOrder(
          _lesson.exercises,
          Random(seed),
          prioritizeIds: {'e3', 'e4'},
        );
        expect(ordered.take(2).map((e) => e.id).toSet(), {'e3', 'e4'});
      }
    });

    test('prioritized exercises are not themselves in a fixed order', () {
      final firsts = <String>{};
      for (var seed = 0; seed < 12; seed++) {
        final ordered = LessonVariantGenerator.shuffleOrder(
          _lesson.exercises,
          Random(seed),
          prioritizeIds: {'e1', 'e2', 'e3'},
        );
        firsts.add(ordered.first.id);
      }
      expect(firsts.length, greaterThan(1));
    });

    test('no exercise is lost or duplicated by the shuffle', () {
      final ordered = LessonVariantGenerator.shuffleOrder(_lesson.exercises, Random(3));
      expect(
        ordered.map((e) => e.id).toList()..sort(),
        _lesson.exercises.map((e) => e.id).toList()..sort(),
      );
    });
  });

  group('type variation', () {
    test('the same word is asked in different forms across attempts', () {
      final seen = <ExerciseType>{};
      for (var seed = 0; seed < 20; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: _lesson.exercises,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        seen.addAll(
          varied.where((e) => e.id == 'e1').map((e) => e.type),
        );
      }
      expect(
        seen.length,
        greaterThan(1),
        reason: '"Hola" should not always be a multiple-choice question',
      );
    });

    test('the authored exercise id and vocab id always survive', () {
      // Everything that tracks progress — the mistake bank, perfect
      // lessons, the in-session retry queue — keys off these.
      for (var seed = 0; seed < 20; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: _lesson.exercises,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        for (var i = 0; i < varied.length; i++) {
          expect(varied[i].id, _lesson.exercises[i].id);
          expect(varied[i].vocabId, _lesson.exercises[i].vocabId);
        }
      }
    });

    test('hand-authored types are never synthesized over', () {
      for (var seed = 0; seed < 20; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: _lesson.exercises,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        expect(varied[4].type, ExerciseType.wordMatching);
        expect(varied[5].type, ExerciseType.sentenceArrangement);
      }
    });

    test('an unresolvable vocab id keeps its authored form', () {
      final exercises = [_mc('e1', 'not_in_any_pool')];
      for (var seed = 0; seed < 10; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: exercises,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        expect(varied.single.type, ExerciseType.multipleChoice);
        expect(
          (varied.single.payload as MultipleChoicePayload).prompt,
          "Which word means 'Hello'?",
        );
      }
    });

    test('some of the lesson stays as authored — a replay is not a new lesson', () {
      final varied = LessonVariantGenerator.varyTypes(
        exercises: _lesson.exercises,
        words: _words,
        languageId: 'es',
        random: Random(7),
      );
      final unchanged = [
        for (var i = 0; i < varied.length; i++)
          if (identical(varied[i], _lesson.exercises[i])) i,
      ];
      expect(unchanged, isNotEmpty);
    });

    test('an empty word pool is a no-op rather than a crash', () {
      final varied = LessonVariantGenerator.varyTypes(
        exercises: _lesson.exercises,
        words: const [],
        languageId: 'es',
        random: Random(1),
      );
      expect(varied, _lesson.exercises);
    });

    test('the same seed produces the same session', () {
      final a = LessonVariantGenerator.buildSession(
        lesson: _lesson,
        words: _words,
        languageId: 'es',
        random: Random(42),
      );
      final b = LessonVariantGenerator.buildSession(
        lesson: _lesson,
        words: _words,
        languageId: 'es',
        random: Random(42),
      );
      expect(
        a.exercises.map((e) => '${e.id}:${e.type.name}').toList(),
        b.exercises.map((e) => '${e.id}:${e.type.name}').toList(),
      );
    });
  });

  group('generated content is valid and answerable', () {
    test('every generated question names the language it wants back', () {
      for (var seed = 0; seed < 30; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: _lesson.exercises,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        for (final e in varied) {
          final payload = e.payload;
          if (payload is TranslationPayload) {
            expect(payload.prompt, contains('English'));
            expect(payload.answerLanguage, 'English');
          }
          if (payload is ImageRecognitionPayload) {
            // Never an emoji on its own: the word rides along with it.
            expect(payload.hasMeaning, isTrue);
            expect(payload.targetWord, isNotEmpty);
          }
        }
      }
    });

    test('generated options are distinct and contain the answer exactly once', () {
      for (var seed = 0; seed < 30; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: _lesson.exercises,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        for (final e in varied) {
          final payload = e.payload;
          if (payload is MultipleChoicePayload) {
            expect(payload.options.toSet().length, payload.options.length);
            expect(payload.correctIndex, inInclusiveRange(0, payload.options.length - 1));
          }
          if (payload is ListeningPayload) {
            expect(payload.options.toSet().length, payload.options.length);
            expect(payload.options[payload.correctIndex], payload.audioText);
          }
        }
      }
    });

    test('at most one generated speaking exercise per session', () {
      for (var seed = 0; seed < 30; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: _lesson.exercises,
          words: _words,
          languageId: 'es',
          random: Random(seed),
        );
        final speaking = varied.where((e) => e.type == ExerciseType.speaking).length;
        expect(speaking, lessThanOrEqualTo(1));
      }
    });

    test('the course language drives the TTS locale, not a hardcoded default', () {
      for (var seed = 0; seed < 30; seed++) {
        final varied = LessonVariantGenerator.varyTypes(
          exercises: _lesson.exercises,
          words: _words,
          languageId: 'fr',
          random: Random(seed),
        );
        for (final e in varied) {
          final payload = e.payload;
          if (payload is ListeningPayload) expect(payload.ttsLocale, 'fr-FR');
          if (payload is SpeakingPayload) expect(payload.ttsLocale, 'fr-FR');
        }
      }
    });
  });
}

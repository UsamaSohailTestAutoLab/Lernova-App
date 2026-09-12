import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/features/exercises/application/exercise_validator.dart';

void main() {
  group('ExerciseValidator - multipleChoice / listening', () {
    final exercise = Exercise(
      id: 'e1',
      type: ExerciseType.multipleChoice,
      vocabId: 'v1',
      payload: const MultipleChoicePayload(
        prompt: 'p',
        options: ['a', 'b', 'c'],
        correctIndex: 1,
      ),
    );

    test('correct index passes', () {
      expect(ExerciseValidator.isCorrect(exercise, 1), isTrue);
    });

    test('wrong index fails', () {
      expect(ExerciseValidator.isCorrect(exercise, 0), isFalse);
    });

    test('wrong answer type fails', () {
      expect(ExerciseValidator.isCorrect(exercise, 'b'), isFalse);
    });
  });

  group('ExerciseValidator - translation', () {
    final exercise = Exercise(
      id: 'e2',
      type: ExerciseType.translation,
      vocabId: 'v2',
      payload: const TranslationPayload(
        prompt: 'p',
        sourceText: 'Hola',
        acceptableAnswers: ['hello'],
      ),
    );

    test('exact match passes', () {
      expect(ExerciseValidator.isCorrect(exercise, 'hello'), isTrue);
    });

    test('case-insensitive and punctuation-insensitive match passes', () {
      expect(ExerciseValidator.isCorrect(exercise, '  HELLO! '), isTrue);
    });

    test('unrelated answer fails', () {
      expect(ExerciseValidator.isCorrect(exercise, 'goodbye'), isFalse);
    });
  });

  group('ExerciseValidator - speaking (recognized speech, fuzzy match)', () {
    final exercise = Exercise(
      id: 'e3',
      type: ExerciseType.speaking,
      vocabId: 'v3',
      payload: const SpeakingPayload(
        prompt: 'p',
        targetPhrase: 'Hola, ¿cómo estás?',
        translation: 'Hello, how are you?',
      ),
    );

    test('an exact match passes', () {
      expect(ExerciseValidator.isCorrect(exercise, 'Hola, ¿cómo estás?'), isTrue);
    });

    test('a close recognized transcript (minor recognizer noise) passes', () {
      expect(ExerciseValidator.isCorrect(exercise, 'hola como estas'), isTrue);
    });

    test('a completely unrelated transcript fails', () {
      expect(ExerciseValidator.isCorrect(exercise, 'buenas noches amigo'), isFalse);
    });

    test('empty recognized text fails', () {
      expect(ExerciseValidator.isCorrect(exercise, ''), isFalse);
    });

    test('a non-string answer fails', () {
      expect(ExerciseValidator.isCorrect(exercise, true), isFalse);
    });
  });

  group('ExerciseValidator - wordMatching', () {
    final exercise = Exercise(
      id: 'e4',
      type: ExerciseType.wordMatching,
      vocabId: 'v4',
      payload: const WordMatchingPayload(
        prompt: 'p',
        pairs: [
          WordPair(left: 'Hola', right: 'Hello'),
          WordPair(left: 'Adiós', right: 'Goodbye'),
        ],
      ),
    );

    test('all pairs matched to their own index passes', () {
      expect(ExerciseValidator.isCorrect(exercise, {0: 0, 1: 1}), isTrue);
    });

    test('a swapped pair fails', () {
      expect(ExerciseValidator.isCorrect(exercise, {0: 1, 1: 0}), isFalse);
    });

    test('incomplete pairing fails', () {
      expect(ExerciseValidator.isCorrect(exercise, {0: 0}), isFalse);
    });
  });

  group('ExerciseValidator - sentenceArrangement', () {
    final exercise = Exercise(
      id: 'e5',
      type: ExerciseType.sentenceArrangement,
      vocabId: 'v5',
      payload: const SentenceArrangementPayload(
        prompt: 'p',
        shuffledChips: ['gracias', 'Muchas'],
        correctSentence: ['Muchas', 'gracias'],
      ),
    );

    test('correct order passes', () {
      expect(ExerciseValidator.isCorrect(exercise, ['Muchas', 'gracias']), isTrue);
    });

    test('wrong order fails', () {
      expect(ExerciseValidator.isCorrect(exercise, ['gracias', 'Muchas']), isFalse);
    });
  });

  group('ExerciseValidator - imageRecognition', () {
    final exercise = Exercise(
      id: 'e7',
      type: ExerciseType.imageRecognition,
      vocabId: 'v7',
      payload: const ImageRecognitionPayload(
        prompt: 'What is this?',
        emoji: '🍎',
        targetWord: 'Manzana',
        distractorWords: ['Casa', 'Agua', 'Libro'],
      ),
    );

    test('the exact target word passes', () {
      expect(ExerciseValidator.isCorrect(exercise, 'Manzana'), isTrue);
    });

    test('case/punctuation-insensitive match passes', () {
      expect(ExerciseValidator.isCorrect(exercise, '  manzana! '), isTrue);
    });

    test('a distractor fails', () {
      expect(ExerciseValidator.isCorrect(exercise, 'Casa'), isFalse);
    });

    test('a non-string answer fails', () {
      expect(ExerciseValidator.isCorrect(exercise, 3), isFalse);
    });

    // Regression: with meaning-first content the target word is on
    // screen throughout, so typing it back was copying — and the app
    // then announced that the right answer was the word it had been
    // displaying. The recall step asks for the meaning and grades that.
    group('meaning-first content grades the meaning', () {
      final meaningFirst = Exercise(
        id: 'e7m',
        type: ExerciseType.imageRecognition,
        vocabId: 'v7',
        payload: const ImageRecognitionPayload(
          prompt: 'What does this word mean?',
          emoji: '✅',
          targetWord: 'Sí',
          meaning: 'Yes',
          distractorMeanings: ['No', 'Sorry'],
          distractorWords: ['No', 'Lo siento'],
        ),
      );

      test('the English meaning is accepted', () {
        expect(ExerciseValidator.isCorrect(meaningFirst, 'Yes'), isTrue);
        expect(ExerciseValidator.isCorrect(meaningFirst, ' yes '), isTrue);
      });

      test('typing the word shown on screen is not the answer', () {
        expect(ExerciseValidator.isCorrect(meaningFirst, 'Sí'), isFalse);
      });
    });
  });

  group('ExerciseValidator - fillInTheBlank', () {
    final exercise = Exercise(
      id: 'e6',
      type: ExerciseType.fillInTheBlank,
      vocabId: 'v6',
      payload: const FillInTheBlankPayload(
        sentenceTemplate: '___, ¿cómo estás?',
        options: ['Hola', 'Adiós'],
        correctAnswer: 'Hola',
      ),
    );

    test('correct option passes', () {
      expect(ExerciseValidator.isCorrect(exercise, 'Hola'), isTrue);
    });

    test('wrong option fails', () {
      expect(ExerciseValidator.isCorrect(exercise, 'Adiós'), isFalse);
    });
  });
}

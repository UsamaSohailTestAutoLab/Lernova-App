import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/features/exercises/application/exercise_labels.dart';

Exercise _ex(ExerciseType type, ExercisePayload payload) =>
    Exercise(id: 'e1', type: type, vocabId: 'v1', payload: payload);

const _mc = MultipleChoicePayload(
  prompt: "Which word means 'Hello'?",
  options: ['Hola', 'Gracias', 'Adiós'],
  correctIndex: 0,
);

const _listening = ListeningPayload(
  prompt: 'Listen and select what you hear',
  audioText: 'Por favor',
  ttsLocale: 'es-ES',
  options: ['Hola', 'Por favor'],
  correctIndex: 1,
);

const _translation = TranslationPayload(
  prompt: 'Type the English meaning',
  sourceText: 'De nada',
  acceptableAnswers: ["You're welcome"],
);

const _speaking = SpeakingPayload(
  prompt: 'Say this phrase out loud',
  targetPhrase: 'Buenos días',
  translation: 'Good morning',
);

const _matching = WordMatchingPayload(
  prompt: 'Match each word to its meaning',
  pairs: [WordPair(left: 'Hola', right: 'Hello'), WordPair(left: 'Sí', right: 'Yes')],
);

const _arrangement = SentenceArrangementPayload(
  prompt: 'Put the words in the right order',
  shuffledChips: ['gracias', 'Muchas'],
  correctSentence: ['Muchas', 'gracias'],
);

const _blank = FillInTheBlankPayload(
  sentenceTemplate: 'Mi ___ se llama Rosa.',
  options: ['abuela', 'padre'],
  correctAnswer: 'abuela',
);

const _imageLegacy = ImageRecognitionPayload(
  prompt: 'What does this mean?',
  emoji: '👋',
  targetWord: 'Hola',
  distractorWords: ['Gracias'],
);

const _imageMeaning = ImageRecognitionPayload(
  prompt: 'What does this word mean?',
  emoji: '👋',
  targetWord: 'Hola',
  meaning: 'Hello',
  distractorMeanings: ['Goodbye'],
  distractorWords: ['Gracias'],
);

void main() {
  group('userAnswerLabel', () {
    test('an option index renders as the option text', () {
      expect(userAnswerLabel(_ex(ExerciseType.multipleChoice, _mc), 1), 'Gracias');
      expect(userAnswerLabel(_ex(ExerciseType.listening, _listening), 0), 'Hola');
    });

    test('typed answers are trimmed', () {
      expect(
        userAnswerLabel(_ex(ExerciseType.translation, _translation), '  thanks  '),
        'thanks',
      );
      expect(userAnswerLabel(_ex(ExerciseType.fillInTheBlank, _blank), 'padre'), 'padre');
      expect(userAnswerLabel(_ex(ExerciseType.imageRecognition, _imageMeaning), 'Hi'), 'Hi');
    });

    test('speech is quoted, and silence says so', () {
      expect(
        userAnswerLabel(_ex(ExerciseType.speaking, _speaking), 'buenas noches'),
        '“buenas noches”',
      );
      expect(
        userAnswerLabel(_ex(ExerciseType.speaking, _speaking), ''),
        'No speech detected',
      );
    });

    test('a pairing renders as the pairs the learner actually made', () {
      expect(
        userAnswerLabel(_ex(ExerciseType.wordMatching, _matching), {0: 1, 1: 0}),
        'Hola = Yes · Sí = Hello',
      );
    });

    test('a chip order renders as the sentence built', () {
      expect(
        userAnswerLabel(_ex(ExerciseType.sentenceArrangement, _arrangement), ['gracias', 'Muchas']),
        'gracias Muchas',
      );
    });

    // A review screen must never be the thing that crashes: it runs after
    // the session, over whatever was recorded, including a question that
    // was skipped or answered with a type nobody expected.
    group('never throws on unexpected input', () {
      final cases = <String, Exercise>{
        'multipleChoice': _ex(ExerciseType.multipleChoice, _mc),
        'listening': _ex(ExerciseType.listening, _listening),
        'translation': _ex(ExerciseType.translation, _translation),
        'speaking': _ex(ExerciseType.speaking, _speaking),
        'wordMatching': _ex(ExerciseType.wordMatching, _matching),
        'sentenceArrangement': _ex(ExerciseType.sentenceArrangement, _arrangement),
        'fillInTheBlank': _ex(ExerciseType.fillInTheBlank, _blank),
        'imageRecognition': _ex(ExerciseType.imageRecognition, _imageMeaning),
      };

      for (final entry in cases.entries) {
        test(entry.key, () {
          for (final answer in <dynamic>[null, 99, -1, '', <String>[], <int, int>{}, 3.5]) {
            expect(() => userAnswerLabel(entry.value, answer), returnsNormally);
            expect(userAnswerLabel(entry.value, answer), isNotEmpty);
          }
        });
      }
    });
  });

  group('correctAnswerLabel', () {
    test('a matching set names the real pairs, not a placeholder', () {
      expect(
        correctAnswerLabel(_ex(ExerciseType.wordMatching, _matching)),
        'Hola = Hello · Sí = Yes',
      );
    });

    // Regression: the learner typed "Sí" and was told the correct answer
    // was "Sí". Meaning-first content shows the word the whole time, so
    // the recall step asks for — and grades — the meaning.
    test('meaning-first image content names the meaning', () {
      expect(correctAnswerLabel(_ex(ExerciseType.imageRecognition, _imageMeaning)), 'Hello');
    });

    test('legacy image content still names the word', () {
      expect(correctAnswerLabel(_ex(ExerciseType.imageRecognition, _imageLegacy)), 'Hola');
    });
  });

  group('promptLabel and spokenText', () {
    test('a prompt carries the word it was about', () {
      expect(
        promptLabel(_ex(ExerciseType.translation, _translation)),
        'Type the English meaning: “De nada”',
      );
      expect(promptLabel(_ex(ExerciseType.imageRecognition, _imageMeaning)), '👋 Hola');
    });

    test('the learning-language text is what a review row speaks', () {
      expect(spokenTextFor(_ex(ExerciseType.speaking, _speaking)), 'Buenos días');
      expect(spokenTextFor(_ex(ExerciseType.listening, _listening)), 'Por favor');
      expect(spokenTextFor(_ex(ExerciseType.imageRecognition, _imageMeaning)), 'Hola');
      // A multiple-choice prompt is English; there is nothing to speak.
      expect(spokenTextFor(_ex(ExerciseType.multipleChoice, _mc)), isNull);
    });

    test('a fill-in-the-blank speaks the completed sentence', () {
      expect(
        spokenTextFor(_ex(ExerciseType.fillInTheBlank, _blank)),
        'Mi abuela se llama Rosa.',
      );
    });
  });
}

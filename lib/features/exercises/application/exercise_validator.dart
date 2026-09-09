import '../../../core/utils/similarity.dart';
import '../../../core/utils/string_normalize.dart';
import '../../../data/models/exercise.dart';

/// Recognized speech only has to be this close to the target phrase
/// (after normalizing both) to count as correct — spoken output is
/// noisier than typed text (recognizer quirks, dropped words, missed
/// accents), so exact equality is too strict.
const speakingSimilarityThreshold = 0.75;

/// Pure per-type answer validation. Kept free of any widget/controller
/// dependency so it's directly unit-testable and each exercise widget
/// stays a thin input surface.
class ExerciseValidator {
  ExerciseValidator._();

  static bool isCorrect(Exercise exercise, dynamic answer) {
    final payload = exercise.payload;
    switch (payload) {
      case MultipleChoicePayload p:
        return answer is int && answer == p.correctIndex;

      case ListeningPayload p:
        return answer is int && answer == p.correctIndex;

      case TranslationPayload p:
        if (answer is! String) return false;
        return p.acceptableAnswers.any((a) => matchesTypedAnswer(answer, a));

      case SpeakingPayload p:
        // The widget hands back the recognized speech text (from real
        // on-device speech recognition, not a self-report) — graded by
        // fuzzy similarity rather than exact match.
        if (answer is! String || answer.trim().isEmpty) return false;
        final similarity = levenshteinSimilarity(
          normalizeForMatch(answer),
          normalizeForMatch(p.targetPhrase),
        );
        return similarity >= speakingSimilarityThreshold;

      case WordMatchingPayload p:
        if (answer is! Map<int, int>) return false;
        if (answer.length != p.pairs.length) return false;
        return answer.entries.every((e) => e.key == e.value);

      case SentenceArrangementPayload p:
        if (answer is! List<String>) return false;
        if (answer.length != p.correctSentence.length) return false;
        for (var i = 0; i < answer.length; i++) {
          if (answer[i] != p.correctSentence[i]) return false;
        }
        return true;

      case FillInTheBlankPayload p:
        return answer is String && answer == p.correctAnswer;

      case ImageRecognitionPayload p:
        // The Recognize sub-step is resolved locally inside the widget;
        // only the Recall sub-step's typed answer reaches here.
        //
        // Meaning-first content shows the target word on screen the
        // whole time, so asking the learner to type it back would be
        // copying, not recall — the recall step asks for the English
        // meaning instead, and that is what's graded.
        if (answer is! String) return false;
        final expected = p.hasMeaning ? p.meaning! : p.targetWord;
        return matchesTypedAnswer(answer, expected);
    }
  }
}

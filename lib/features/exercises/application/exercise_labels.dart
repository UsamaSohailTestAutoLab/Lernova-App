import '../../../data/models/exercise.dart';

/// Human-readable "correct answer" string shown in the feedback bar
/// when the user gets an exercise wrong.
String correctAnswerLabel(Exercise exercise) {
  final payload = exercise.payload;
  return switch (payload) {
    MultipleChoicePayload p => p.options[p.correctIndex],
    ListeningPayload p => p.options[p.correctIndex],
    TranslationPayload p => p.acceptableAnswers.first,
    SpeakingPayload p => p.targetPhrase,
    WordMatchingPayload p =>
      p.pairs.map((pair) => '${pair.left} = ${pair.right}').join(' · '),
    SentenceArrangementPayload p => p.correctSentence.join(' '),
    FillInTheBlankPayload p => p.correctAnswer,
    // Mirrors what the recall step actually asks for (see
    // [ExerciseValidator]): the English meaning for meaning-first
    // content, the target word for legacy content.
    ImageRecognitionPayload p => p.hasMeaning ? p.meaning! : p.targetWord,
  };
}

/// An English gloss shown beneath a correct answer, with the wording
/// that actually fits it.
class AnswerMeaning {
  /// 'Means' where the gloss translates the answer itself; 'Full
  /// sentence' where the answer is one word of a longer sentence and the
  /// gloss covers the whole thing.
  final String label;
  final String text;

  const AnswerMeaning({required this.label, required this.text});
}

/// The English meaning of [correctAnswerLabel], when the correct answer
/// is in the learning language and nothing else on screen says what it
/// means — null when a gloss would just repeat what the learner can
/// already read.
///
/// Getting a question wrong is the moment the meaning matters most:
/// "Correct answer: El aeropuerto está cerca" teaches word order and
/// nothing else if you don't already know the sentence. The types that
/// return null do so for a reason:
///
///  * multiple choice asks "Which word means 'X'?" — the English is the
///    question,
///  * translation and meaning-first image recall are *answered* in
///    English,
///  * a matching set already shows both sides of every pair.
AnswerMeaning? correctAnswerMeaning(Exercise exercise) {
  final payload = exercise.payload;
  // Fill-in-the-blank is the one type whose answer is a *fragment* — the
  // gloss translates the sentence it slots into, so "Means: …" under the
  // single word "abuela" would be claiming that word means the whole
  // sentence.
  final label =
      payload is FillInTheBlankPayload ? 'Full sentence' : 'Means';
  final meaning = switch (payload) {
    MultipleChoicePayload _ => null,
    TranslationPayload _ => null,
    WordMatchingPayload _ => null,
    ImageRecognitionPayload p => p.hasMeaning ? null : p.meaning,
    SpeakingPayload p => p.translation,
    ListeningPayload p => p.translation,
    SentenceArrangementPayload p => p.translation,
    FillInTheBlankPayload p => p.translation,
  };
  final trimmed = meaning?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return AnswerMeaning(label: label, text: trimmed);
}

/// What the learner was asked, in one line — the question as it appeared,
/// paired with the word it was about so a review row reads on its own.
String promptLabel(Exercise exercise) {
  final payload = exercise.payload;
  return switch (payload) {
    MultipleChoicePayload p => p.prompt,
    ListeningPayload p => '${p.prompt}: “${p.audioText}”',
    TranslationPayload p => '${p.prompt}: “${p.sourceText}”',
    SpeakingPayload p => '${p.prompt}: “${p.targetPhrase}”',
    WordMatchingPayload p => p.prompt,
    SentenceArrangementPayload p => p.prompt,
    FillInTheBlankPayload p => p.sentenceTemplate,
    ImageRecognitionPayload p => '${p.emoji} ${p.targetWord}',
  };
}

/// The learning-language text this exercise is about, or null when there
/// isn't a single one (a matching set covers four pairs at once). Drives
/// the Listen button on review rows.
String? spokenTextFor(Exercise exercise) {
  final payload = exercise.payload;
  return switch (payload) {
    MultipleChoicePayload _ => null,
    ListeningPayload p => p.audioText,
    TranslationPayload p => p.sourceText,
    SpeakingPayload p => p.targetPhrase,
    WordMatchingPayload _ => null,
    SentenceArrangementPayload p => p.correctSentence.join(' '),
    FillInTheBlankPayload p => p.sentenceTemplate.replaceAll('___', p.correctAnswer),
    ImageRecognitionPayload p => p.targetWord,
  };
}

/// The TTS locale authored alongside this exercise, where it has one.
String? ttsLocaleFor(Exercise exercise) {
  final payload = exercise.payload;
  return switch (payload) {
    ListeningPayload p => p.ttsLocale,
    SpeakingPayload p => p.ttsLocale,
    _ => null,
  };
}

/// What the learner actually answered, rendered the same way the correct
/// answer is, so a review row can put the two side by side.
///
/// [answer] is whatever the exercise widget handed to the session — an
/// option index, a typed string, a pairing map, a chip order. Anything
/// unexpected (or a question left unanswered) renders as a dash rather
/// than throwing on a review screen.
String userAnswerLabel(Exercise exercise, dynamic answer) {
  const noAnswer = '—';
  final payload = exercise.payload;

  String option(List<String> options, dynamic value) {
    if (value is! int || value < 0 || value >= options.length) return noAnswer;
    return options[value];
  }

  return switch (payload) {
    MultipleChoicePayload p => option(p.options, answer),
    ListeningPayload p => option(p.options, answer),
    TranslationPayload _ => _typed(answer, noAnswer),
    SpeakingPayload _ =>
      answer is String && answer.trim().isNotEmpty
          ? '“${answer.trim()}”'
          : 'No speech detected',
    WordMatchingPayload p => answer is Map<int, int>
        ? _orDash(
            [
              for (final entry in answer.entries)
                if (entry.key >= 0 &&
                    entry.key < p.pairs.length &&
                    entry.value >= 0 &&
                    entry.value < p.pairs.length)
                  '${p.pairs[entry.key].left} = ${p.pairs[entry.value].right}',
            ].join(' · '),
            noAnswer,
          )
        : noAnswer,
    SentenceArrangementPayload _ =>
      answer is List<String> && answer.isNotEmpty ? answer.join(' ') : noAnswer,
    FillInTheBlankPayload _ => _typed(answer, noAnswer),
    ImageRecognitionPayload _ => _typed(answer, noAnswer),
  };
}

String _orDash(String value, String fallback) => value.isEmpty ? fallback : value;

String _typed(dynamic answer, String fallback) {
  if (answer is! String) return fallback;
  final trimmed = answer.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

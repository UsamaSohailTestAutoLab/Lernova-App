import '../../core/constants/app_enums.dart';

/// Type-safe per-exercise-type payloads. Using a sealed hierarchy (rather
/// than one class with a bag of nullable fields) means each exercise
/// widget can pattern-match exhaustively and the compiler enforces that
/// every type is handled.
sealed class ExercisePayload {
  const ExercisePayload();

  factory ExercisePayload.fromJson(ExerciseType type, Map<String, dynamic> json) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return MultipleChoicePayload.fromJson(json);
      case ExerciseType.translation:
        return TranslationPayload.fromJson(json);
      case ExerciseType.listening:
        return ListeningPayload.fromJson(json);
      case ExerciseType.speaking:
        return SpeakingPayload.fromJson(json);
      case ExerciseType.wordMatching:
        return WordMatchingPayload.fromJson(json);
      case ExerciseType.sentenceArrangement:
        return SentenceArrangementPayload.fromJson(json);
      case ExerciseType.fillInTheBlank:
        return FillInTheBlankPayload.fromJson(json);
      case ExerciseType.imageRecognition:
        return ImageRecognitionPayload.fromJson(json);
    }
  }
}

class MultipleChoicePayload extends ExercisePayload {
  final String prompt;
  final List<String> options;
  final int correctIndex;

  const MultipleChoicePayload({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  factory MultipleChoicePayload.fromJson(Map<String, dynamic> json) {
    return MultipleChoicePayload(
      prompt: json['prompt'] as String,
      options: (json['options'] as List).cast<String>(),
      correctIndex: json['correctIndex'] as int,
    );
  }
}

class TranslationPayload extends ExercisePayload {
  final String prompt;
  final String sourceText;
  final List<String> acceptableAnswers;

  /// The language the learner is expected to answer *in*, named in the
  /// input hint so a beginner is never guessing which side of the pair
  /// to type. Defaults to English, which is what all authored
  /// translation exercises ask for.
  final String answerLanguage;

  const TranslationPayload({
    required this.prompt,
    required this.sourceText,
    required this.acceptableAnswers,
    this.answerLanguage = 'English',
  });

  factory TranslationPayload.fromJson(Map<String, dynamic> json) {
    return TranslationPayload(
      prompt: json['prompt'] as String,
      sourceText: json['sourceText'] as String,
      acceptableAnswers: (json['acceptableAnswers'] as List).cast<String>(),
      answerLanguage: json['answerLanguage'] as String? ?? 'English',
    );
  }
}

class ListeningPayload extends ExercisePayload {
  final String prompt;
  final String audioText;
  final String ttsLocale;
  final List<String> options;
  final int correctIndex;

  const ListeningPayload({
    required this.prompt,
    required this.audioText,
    required this.ttsLocale,
    required this.options,
    required this.correctIndex,
  });

  factory ListeningPayload.fromJson(Map<String, dynamic> json) {
    return ListeningPayload(
      prompt: json['prompt'] as String,
      audioText: json['audioText'] as String,
      ttsLocale: json['ttsLocale'] as String? ?? 'es-ES',
      options: (json['options'] as List).cast<String>(),
      correctIndex: json['correctIndex'] as int,
    );
  }
}

class SpeakingPayload extends ExercisePayload {
  final String prompt;
  final String targetPhrase;
  final String translation;
  final String ttsLocale;

  const SpeakingPayload({
    required this.prompt,
    required this.targetPhrase,
    required this.translation,
    this.ttsLocale = 'es-ES',
  });

  factory SpeakingPayload.fromJson(Map<String, dynamic> json) {
    return SpeakingPayload(
      prompt: json['prompt'] as String,
      targetPhrase: json['targetPhrase'] as String,
      translation: json['translation'] as String,
      ttsLocale: json['ttsLocale'] as String? ?? 'es-ES',
    );
  }
}

class WordPair {
  final String left;
  final String right;
  const WordPair({required this.left, required this.right});

  factory WordPair.fromJson(Map<String, dynamic> json) {
    return WordPair(left: json['left'] as String, right: json['right'] as String);
  }
}

class WordMatchingPayload extends ExercisePayload {
  final String prompt;
  final List<WordPair> pairs;

  const WordMatchingPayload({required this.prompt, required this.pairs});

  factory WordMatchingPayload.fromJson(Map<String, dynamic> json) {
    return WordMatchingPayload(
      prompt: json['prompt'] as String,
      pairs: (json['pairs'] as List)
          .map((e) => WordPair.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SentenceArrangementPayload extends ExercisePayload {
  final String prompt;
  final List<String> shuffledChips;
  final List<String> correctSentence;

  const SentenceArrangementPayload({
    required this.prompt,
    required this.shuffledChips,
    required this.correctSentence,
  });

  factory SentenceArrangementPayload.fromJson(Map<String, dynamic> json) {
    return SentenceArrangementPayload(
      prompt: json['prompt'] as String,
      shuffledChips: (json['shuffledChips'] as List).cast<String>(),
      correctSentence: (json['correctSentence'] as List).cast<String>(),
    );
  }
}

class FillInTheBlankPayload extends ExercisePayload {
  final String sentenceTemplate;
  final List<String> options;
  final String correctAnswer;

  const FillInTheBlankPayload({
    required this.sentenceTemplate,
    required this.options,
    required this.correctAnswer,
  });

  factory FillInTheBlankPayload.fromJson(Map<String, dynamic> json) {
    return FillInTheBlankPayload(
      sentenceTemplate: json['sentenceTemplate'] as String,
      options: (json['options'] as List).cast<String>(),
      correctAnswer: json['correctAnswer'] as String,
    );
  }
}

/// Teaches a word visually (the app has no photo assets by design —
/// everything is original or emoji-based — so [emoji] stands in as "the
/// image"). [targetWord] is authored directly here (mirroring
/// [SpeakingPayload.targetPhrase]) rather than resolved via [vocabId] at
/// validation time, since [ExerciseValidator] has no vocab-pool
/// dependency and shouldn't gain one just for this type.
class ImageRecognitionPayload extends ExercisePayload {
  final String prompt;
  final String emoji;
  final String targetWord;
  final List<String> distractorWords;

  /// The English meaning of [targetWord], and the English meanings used
  /// as wrong choices. The exercise shows the word *with* its image and
  /// asks what it means, so a learner is never asked to decode a bare
  /// picture — the icon supports the word rather than replacing it.
  ///
  /// Nullable so older content still parses; when absent the exercise
  /// falls back to picking the target word from [distractorWords].
  final String? meaning;
  final List<String> distractorMeanings;

  const ImageRecognitionPayload({
    required this.prompt,
    required this.emoji,
    required this.targetWord,
    required this.distractorWords,
    this.meaning,
    this.distractorMeanings = const [],
  });

  /// True when this payload carries enough English content to run the
  /// meaning-first flow.
  bool get hasMeaning => meaning != null && distractorMeanings.isNotEmpty;

  factory ImageRecognitionPayload.fromJson(Map<String, dynamic> json) {
    return ImageRecognitionPayload(
      prompt: json['prompt'] as String,
      emoji: json['emoji'] as String,
      targetWord: json['targetWord'] as String,
      distractorWords: (json['distractorWords'] as List).cast<String>(),
      meaning: json['meaning'] as String?,
      distractorMeanings:
          (json['distractorMeanings'] as List?)?.cast<String>() ?? const [],
    );
  }
}

class Exercise {
  final String id;
  final ExerciseType type;
  final String vocabId;
  final ExercisePayload payload;

  const Exercise({
    required this.id,
    required this.type,
    required this.vocabId,
    required this.payload,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final type = ExerciseType.values.byName(json['type'] as String);
    return Exercise(
      id: json['id'] as String,
      type: type,
      vocabId: json['vocabId'] as String,
      payload: ExercisePayload.fromJson(type, json['payload'] as Map<String, dynamic>),
    );
  }
}

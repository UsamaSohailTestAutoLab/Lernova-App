import '../../../core/constants/app_enums.dart';

/// A single generated Fun-game question — the shared currency every
/// game mode's UI renders, regardless of which of the 9 [FunQuestionType]
/// shapes it is.
class FunQuestion {
  final String id;
  final FunQuestionType type;
  final String promptText;
  final String? promptEmoji;
  final bool promptIsAudio;
  final String ttsLocale;
  final List<String> options;

  /// An illustrative emoji per option, aligned index-for-index with
  /// [options]. Entries are null where the vocabulary has no emoji, and
  /// the whole list is empty for content that carries none — an answer
  /// bubble renders its word either way, so this only ever adds support,
  /// never replaces the label.
  final List<String?> optionEmojis;

  final int correctIndex;
  final String vocabId;

  const FunQuestion({
    required this.id,
    required this.type,
    required this.promptText,
    this.promptEmoji,
    this.promptIsAudio = false,
    this.ttsLocale = 'es-ES',
    required this.options,
    this.optionEmojis = const [],
    required this.correctIndex,
    required this.vocabId,
  });

  String get correctAnswer => options[correctIndex];

  String? emojiFor(int optionIndex) {
    if (optionIndex < 0 || optionIndex >= optionEmojis.length) return null;
    return optionEmojis[optionIndex];
  }

  /// Which side of this question is written in the language being
  /// learned. Question types flip direction (word→meaning vs
  /// meaning→word), so anything that needs to *speak* the word — a
  /// Listen button on a feedback card, a review row — has to ask rather
  /// than assume the prompt is the foreign side.
  String get learningLanguageText => switch (type) {
        FunQuestionType.meaningToWord ||
        FunQuestionType.wordToImage ||
        FunQuestionType.meaningToPhrase =>
          correctAnswer,
        _ => promptText,
      };
}

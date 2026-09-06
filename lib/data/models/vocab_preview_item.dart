/// One card in the shared vocabulary-preview step shown before any Path
/// lesson or Fun game starts — deliberately independent of [VocabWord]/
/// [Phrase]/[FunQuestion]/etc. so the preview screen itself never needs
/// to know which content type produced it.
class VocabPreviewItem {
  final String id;
  final String word;
  final String meaning;
  final String? emoji;
  final bool isAudioPrompt;
  final String ttsLocale;

  /// Whether [word] is real learning-language text that can be spoken
  /// aloud. False only for the handful of cards that stand in for
  /// something non-vocabulary (a conversation's English title/blurb),
  /// where a Listen button would read English aloud in a Spanish voice.
  final bool canSpeak;

  const VocabPreviewItem({
    required this.id,
    required this.word,
    required this.meaning,
    this.emoji,
    this.isAudioPrompt = false,
    this.ttsLocale = 'es-ES',
    this.canSpeak = true,
  });
}

/// A pending "you got this wrong — now prove you know it" step, shared
/// by every Fun session controller. Deliberately mode-agnostic: each
/// controller builds one from whatever it already has on a wrong answer
/// (a `FunQuestion`, a `VocabWord`, a `Phrase`, a `MemoryCard` pair) —
/// no controller needs to know how the others represent their content.
class RecallChallenge {
  final String promptWord;
  final String correctMeaning;
  final String? emoji;

  /// What the player actually picked/typed, so the feedback card can put
  /// their answer next to the right one instead of only naming the right
  /// one. Null when there is nothing to show (a timeout, a pairing that
  /// has no single "answer").
  final String? userAnswer;

  /// The learning-language text this challenge is about, spoken by the
  /// card's Listen button. Null when the challenge has no single foreign
  /// word behind it.
  final String? listenText;
  final String ttsLocale;

  const RecallChallenge({
    required this.promptWord,
    required this.correctMeaning,
    this.emoji,
    this.userAnswer,
    this.listenText,
    this.ttsLocale = 'es-ES',
  });
}

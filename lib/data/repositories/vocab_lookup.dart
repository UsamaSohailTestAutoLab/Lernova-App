import '../models/fun/vocab_word.dart';

/// Shared `vocabId -> VocabWord` lookup, used by [FunQuestionGenerator]
/// (synonym/antonym resolution) and by the vocabulary-preview builder —
/// a single implementation instead of each call site re-scanning the
/// pool itself.
class VocabLookup {
  VocabLookup._();

  static VocabWord? findWordById(List<VocabWord> words, String id) {
    for (final w in words) {
      if (w.id == id) return w;
    }
    return null;
  }
}

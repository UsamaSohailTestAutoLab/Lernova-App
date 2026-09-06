import '../../../core/utils/string_normalize.dart';
import '../../../core/utils/tts_locales.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/fun/conversation.dart';
import '../../../data/models/fun/fun_question.dart';
import '../../../data/models/fun/phrase.dart';
import '../../../data/models/fun/vocab_word.dart';
import '../../../data/models/vocab_preview_item.dart';
import '../../../data/repositories/vocab_lookup.dart';

/// Pure builder functions turning each content type's own shape into the
/// shared [VocabPreviewItem] currency the preview screen renders — the
/// only place any of these domain models need to know the preview step
/// exists at all.
class VocabPreviewBuilder {
  VocabPreviewBuilder._();

  /// The one de-duplication rule for Review Words, everywhere.
  ///
  /// Keys on the *normalized learning-language word*, never on the item
  /// id: a lesson reaches the same word through several exercises (an
  /// MCQ keyed `es_hola`, a word-matching set keyed `pair_0_Hola`), and
  /// id-keyed de-duplication let every one of those through as its own
  /// card. One unique word = one review card, no matter how many
  /// questions it appeared in.
  static List<VocabPreviewItem> dedupe(Iterable<VocabPreviewItem> items) {
    final seen = <String>{};
    final result = <VocabPreviewItem>[];
    for (final item in items) {
      final key = normalizeForMatch(item.word);
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(item);
    }
    return result;
  }

  /// Resolves each id via [wordPool] first, [phrasePool] second, and
  /// silently drops any id that resolves in neither (e.g. a synthetic
  /// per-exercise id like a word-matching set's own id, which callers
  /// should build separately via [fromWordMatchingPairs] instead).
  /// De-duplicates by word, preserving first-seen order.
  static List<VocabPreviewItem> fromVocabIds({
    required List<String> vocabIds,
    required List<VocabWord> wordPool,
    List<Phrase> phrasePool = const [],
    String? languageId,
  }) {
    final ttsLocale = TtsLocales.forLanguageId(languageId);
    final items = <VocabPreviewItem>[];
    for (final id in vocabIds) {
      final word = VocabLookup.findWordById(wordPool, id);
      if (word != null) {
        items.add(VocabPreviewItem(
          id: word.id,
          word: word.word,
          meaning: word.translation,
          emoji: word.emoji,
          ttsLocale: ttsLocale,
        ));
        continue;
      }
      final phrase = _findPhrase(phrasePool, id);
      if (phrase != null) {
        items.add(VocabPreviewItem(
          id: phrase.id,
          word: phrase.phrase,
          meaning: phrase.meaning,
          ttsLocale: ttsLocale,
        ));
      }
    }
    return dedupe(items);
  }

  static Phrase? _findPhrase(List<Phrase> phrases, String id) {
    for (final p in phrases) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Convenience wrapper for the falling-word family: derives ids from
  /// already-generated questions, then resolves via the real word/phrase
  /// records — never from `FunQuestion.promptText`/options, since those
  /// flip direction per question type (meaning->word, audio, synonym,
  /// image) and would produce inconsistent preview cards.
  static List<VocabPreviewItem> fromFunQuestions(
    List<FunQuestion> questions, {
    required List<VocabWord> wordPool,
    List<Phrase> phrasePool = const [],
    String? languageId,
  }) {
    final ids = questions.map((q) => q.vocabId).toList();
    return fromVocabIds(
      vocabIds: ids,
      wordPool: wordPool,
      phrasePool: phrasePool,
      languageId: languageId,
    );
  }

  static List<VocabPreviewItem> fromWordMatchingPairs(
    List<WordPair> pairs, {
    String? languageId,
  }) {
    final ttsLocale = TtsLocales.forLanguageId(languageId);
    return dedupe([
      for (var i = 0; i < pairs.length; i++)
        VocabPreviewItem(
          id: 'pair_${i}_${pairs[i].left}',
          word: pairs[i].left,
          meaning: pairs[i].right,
          ttsLocale: ttsLocale,
        ),
    ]);
  }

  static List<VocabPreviewItem> fromVocabWords(
    List<VocabWord> words, {
    String? languageId,
  }) {
    final ttsLocale = TtsLocales.forLanguageId(languageId);
    return dedupe([
      for (final w in words)
        VocabPreviewItem(
          id: w.id,
          word: w.word,
          meaning: w.translation,
          emoji: w.emoji,
          ttsLocale: ttsLocale,
        ),
    ]);
  }

  static VocabPreviewItem fromPhrase(Phrase phrase, {String? languageId}) {
    return VocabPreviewItem(
      id: phrase.id,
      word: phrase.phrase,
      meaning: phrase.meaning,
      ttsLocale: TtsLocales.forLanguageId(languageId),
    );
  }

  /// Conversation Challenge isn't vocabulary-shaped — a single "what to
  /// expect" card stands in for the usual word/meaning pairs. It carries
  /// no learning-language text of its own, so it is marked unspeakable
  /// rather than mispronouncing an English scenario blurb.
  static VocabPreviewItem fromConversation(Conversation conversation) {
    return VocabPreviewItem(
      id: conversation.id,
      word: conversation.title,
      meaning: conversation.scenario,
      canSpeak: false,
    );
  }
}

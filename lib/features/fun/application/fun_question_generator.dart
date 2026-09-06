import 'dart:math';

import '../../../core/constants/app_enums.dart';
import '../../../data/models/fun/fun_level_config.dart';
import '../../../data/models/fun/fun_question.dart';
import '../../../data/models/fun/phrase.dart';
import '../../../data/models/fun/vocab_word.dart';
import '../../../data/repositories/vocab_lookup.dart';

/// Turns a word/phrase pool plus a difficulty config into a round of
/// [FunQuestion]s, covering every combination in the Fun spec (word<->
/// meaning, image, audio, synonym/antonym, phrase<->meaning). Word
/// selection is weighted by [vocabStrength] — the *same* mastery map the
/// core lesson engine writes to — so words the player is shaky on come
/// up more often, without a second spaced-repetition tracker.
class FunQuestionGenerator {
  FunQuestionGenerator._();

  static const _wordTypes = [
    FunQuestionType.wordToMeaning,
    FunQuestionType.meaningToWord,
    FunQuestionType.imageToWord,
    FunQuestionType.wordToImage,
    FunQuestionType.audioToMeaning,
    FunQuestionType.wordToSynonym,
    FunQuestionType.wordToOpposite,
  ];

  static const _phraseTypes = [
    FunQuestionType.phraseToMeaning,
    FunQuestionType.meaningToPhrase,
  ];

  static List<FunQuestion> generateRound({
    required List<VocabWord> words,
    required List<Phrase> phrases,
    required FunLevelConfig level,
    required Map<String, int> vocabStrength,
    required Random random,
  }) {
    if (words.isEmpty) return const [];

    final allowedWordTypes = level.allowedTypes.where(_wordTypes.contains).toList();
    final allowedPhraseTypes = level.allowedTypes.where(_phraseTypes.contains).toList();
    final usePhrases = allowedPhraseTypes.isNotEmpty && phrases.isNotEmpty;

    final pickedWords = weightedWordSample(words, vocabStrength, level.wordCount, random);
    var phraseSlotBudget = usePhrases ? (level.wordCount * 0.3).round() : 0;
    final emojiByLabel = emojiLookup(words);

    final questions = <FunQuestion>[];
    for (final word in pickedWords) {
      final drawPhrase = phraseSlotBudget > 0 && random.nextBool();
      if (drawPhrase) {
        phraseSlotBudget--;
        final phrase = phrases[random.nextInt(phrases.length)];
        final type = allowedPhraseTypes[random.nextInt(allowedPhraseTypes.length)];
        questions.add(_buildPhraseQuestion(
          id: 'fq_${questions.length}_${phrase.id}',
          type: type,
          phrase: phrase,
          phrases: phrases,
          choiceCount: level.bubbleOptionCount,
          random: random,
        ));
        continue;
      }

      final eligible = allowedWordTypes.where((t) => _isEligible(t, word)).toList();
      if (eligible.isEmpty) continue;
      final type = eligible[random.nextInt(eligible.length)];
      final question = _buildWordQuestion(
        id: 'fq_${questions.length}_${word.id}',
        type: type,
        word: word,
        words: words,
        choiceCount: level.bubbleOptionCount,
        random: random,
        emojiByLabel: emojiByLabel,
      );
      if (question != null) questions.add(question);
    }

    return questions;
  }

  /// A focused practice round built from exactly the given word ids
  /// (e.g. the ones just missed) — always the simplest question shape
  /// (word -> meaning) so "practice your mistakes" stays low-friction.
  static List<FunQuestion> generatePracticeRound({
    required List<VocabWord> words,
    required List<String> vocabIds,
    required int choiceCount,
    required Random random,
  }) {
    final targets = vocabIds
        .map((id) => VocabLookup.findWordById(words, id))
        .whereType<VocabWord>()
        .toList()
      ..shuffle(random);

    return [
      for (var i = 0; i < targets.length; i++)
        _mcQuestion(
          id: 'practice_${i}_${targets[i].id}',
          type: FunQuestionType.wordToMeaning,
          prompt: targets[i].word,
          correct: targets[i].translation,
          pool: words.map((w) => w.translation).toList(),
          vocabId: targets[i].id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiLookup(words),
        ),
    ];
  }

  static bool _isEligible(FunQuestionType type, VocabWord word) {
    switch (type) {
      case FunQuestionType.imageToWord:
      case FunQuestionType.wordToImage:
        return word.emoji != null;
      case FunQuestionType.wordToSynonym:
        return word.synonyms.isNotEmpty;
      case FunQuestionType.wordToOpposite:
        return word.antonyms.isNotEmpty;
      default:
        return true;
    }
  }

  /// Picks up to [count] distinct words, weighted toward low/negative
  /// [vocabStrength] entries, so words the learner is shaky on come up
  /// more often. Returns fewer than [count] when the pool is smaller —
  /// a round is capped by the vocabulary that actually exists rather
  /// than padded by asking the same word repeatedly. Public so other
  /// Fun modes with their own session shape (Word Match, Memory Match)
  /// and Learner Mate all get the same adaptive selection.
  static List<VocabWord> weightedWordSample(
    List<VocabWord> words,
    Map<String, int> vocabStrength,
    int count,
    Random random,
  ) {
    final weighted = <VocabWord>[];
    for (final w in words) {
      final strength = (vocabStrength[w.id] ?? 0).clamp(-2, 5);
      // Weaker/newer words (low strength) get picked more often.
      final weight = (6 - strength).clamp(1, 8);
      for (var i = 0; i < weight; i++) {
        weighted.add(w);
      }
    }
    weighted.shuffle(random);

    final result = <VocabWord>[];
    final used = <String>{};
    for (final w in weighted) {
      if (result.length >= count) break;
      if (!used.add(w.id)) continue;
      result.add(w);
    }
    return result;
  }

  static FunQuestion? _buildWordQuestion({
    required String id,
    required FunQuestionType type,
    required VocabWord word,
    required List<VocabWord> words,
    required int choiceCount,
    required Random random,
    Map<String, String?> emojiByLabel = const {},
  }) {
    switch (type) {
      case FunQuestionType.wordToMeaning:
        return _mcQuestion(
          id: id,
          type: type,
          prompt: word.word,
          correct: word.translation,
          pool: words.map((w) => w.translation).toList(),
          vocabId: word.id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiByLabel,
        );
      case FunQuestionType.meaningToWord:
        return _mcQuestion(
          id: id,
          type: type,
          prompt: word.translation,
          correct: word.word,
          pool: words.map((w) => w.word).toList(),
          vocabId: word.id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiByLabel,
        );
      // Both image types show the word ALONGSIDE its picture and ask
      // about meaning, rather than making the picture itself the puzzle.
      // Emoji-only prompts and emoji-only answer bubbles left a learner
      // guessing what a symbol was supposed to represent.
      case FunQuestionType.wordToImage:
        return _mcQuestion(
          id: id,
          type: type,
          prompt: word.translation,
          promptEmoji: word.emoji,
          correct: word.word,
          pool: words.map((w) => w.word).toList(),
          vocabId: word.id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiByLabel,
        );
      case FunQuestionType.imageToWord:
        return _mcQuestion(
          id: id,
          type: type,
          prompt: word.word,
          promptEmoji: word.emoji,
          correct: word.translation,
          pool: words.map((w) => w.translation).toList(),
          vocabId: word.id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiByLabel,
        );
      case FunQuestionType.audioToMeaning:
        return _mcQuestion(
          id: id,
          type: type,
          prompt: word.word,
          promptIsAudio: true,
          correct: word.translation,
          pool: words.map((w) => w.translation).toList(),
          vocabId: word.id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiByLabel,
        );
      case FunQuestionType.wordToSynonym:
        final synonym = VocabLookup.findWordById(words, word.synonyms.first);
        if (synonym == null) return null;
        return _mcQuestion(
          id: id,
          type: type,
          prompt: word.word,
          correct: synonym.word,
          pool: words.map((w) => w.word).toList(),
          vocabId: word.id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiByLabel,
        );
      case FunQuestionType.wordToOpposite:
        final opposite = VocabLookup.findWordById(words, word.antonyms.first);
        if (opposite == null) return null;
        return _mcQuestion(
          id: id,
          type: type,
          prompt: word.word,
          correct: opposite.word,
          pool: words.map((w) => w.word).toList(),
          vocabId: word.id,
          choiceCount: choiceCount,
          random: random,
          emojiByLabel: emojiByLabel,
        );
      case FunQuestionType.phraseToMeaning:
      case FunQuestionType.meaningToPhrase:
        return null; // built via _buildPhraseQuestion instead
    }
  }

  static FunQuestion _buildPhraseQuestion({
    required String id,
    required FunQuestionType type,
    required Phrase phrase,
    required List<Phrase> phrases,
    required int choiceCount,
    required Random random,
  }) {
    if (type == FunQuestionType.meaningToPhrase) {
      return _mcQuestion(
        id: id,
        type: type,
        prompt: phrase.meaning,
        correct: phrase.phrase,
        pool: phrases.map((p) => p.phrase).toList(),
        vocabId: phrase.id,
        choiceCount: choiceCount,
        random: random,
      );
    }
    return _mcQuestion(
      id: id,
      type: type,
      prompt: phrase.phrase,
      correct: phrase.meaning,
      pool: phrases.map((p) => p.meaning).toList(),
      vocabId: phrase.id,
      choiceCount: choiceCount,
      random: random,
    );
  }

  static FunQuestion _mcQuestion({
    required String id,
    required FunQuestionType type,
    required String prompt,
    required String correct,
    required List<String> pool,
    required String vocabId,
    required int choiceCount,
    required Random random,
    String? promptEmoji,
    bool promptIsAudio = false,
    String ttsLocale = 'es-ES',
    Map<String, String?> emojiByLabel = const {},
  }) {
    final distractors = pool.toSet()
      ..remove(correct);
    final distractorList = distractors.toList()..shuffle(random);
    final options = [correct, ...distractorList.take(choiceCount - 1)]..shuffle(random);

    return FunQuestion(
      id: id,
      type: type,
      promptText: prompt,
      promptEmoji: promptEmoji,
      promptIsAudio: promptIsAudio,
      ttsLocale: ttsLocale,
      options: options,
      optionEmojis: [for (final o in options) emojiByLabel[o]],
      correctIndex: options.indexOf(correct),
      vocabId: vocabId,
    );
  }

  /// Label -> emoji for every rendered form of a word, so an answer
  /// bubble can illustrate its option whichever direction the question
  /// runs (the Spanish word, or its English meaning).
  static Map<String, String?> emojiLookup(List<VocabWord> words) {
    final map = <String, String?>{};
    for (final w in words) {
      if (w.emoji == null) continue;
      map[w.word] = w.emoji;
      map[w.translation] = w.emoji;
    }
    return map;
  }
}

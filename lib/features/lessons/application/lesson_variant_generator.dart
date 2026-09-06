import 'dart:math';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/tts_locales.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/fun/vocab_word.dart';
import '../../../data/models/lesson.dart';

/// Rebuilds a lesson into a fresh arrangement for one playthrough:
/// the exercise order is reshuffled, and some exercises are re-asked
/// through a *different* exercise type than the one they were authored
/// as. Replaying a level should be a new experience, not the same
/// questions in the same order.
///
/// Two invariants make this safe to run on every attempt:
///
///  * **Authored ids survive.** `mistakeBank`, `perfectLessonIds`,
///    `completedUniqueIds`, the in-session retry re-queue and the review
///    lesson all key off `Exercise.id`, so a variant keeps the id (and
///    `vocabId`) of the exercise it replaces — only `type`/`payload`
///    change.
///  * **Nothing is invented.** A variant is only produced when the
///    exercise's `vocabId` resolves to a real [VocabWord], so every
///    generated prompt, option and answer is authored content that just
///    happens to be recombined. Anything unresolvable keeps its original
///    form forever.
class LessonVariantGenerator {
  LessonVariantGenerator._();

  /// Exercise types that are never *generated*. Their authored content
  /// is hand-tuned in ways a recombination can't reproduce — matched
  /// pair sets, word-order chips, and blanked sentence templates all
  /// depend on a specific sentence existing — so exercises of these
  /// types are always played exactly as written.
  static const _neverGenerated = {
    ExerciseType.wordMatching,
    ExerciseType.sentenceArrangement,
    ExerciseType.fillInTheBlank,
  };

  /// Ceiling on how much of one session gets re-asked in a new form.
  /// Some familiarity between attempts is the point — a lesson that is
  /// entirely different every time never lets a word settle.
  static const double _maxSwapFraction = 0.5;

  /// At most one generated speaking exercise per session. Speaking is
  /// the slowest and most failure-prone type; a round that turned into
  /// four mic prompts would be a worse experience, not a more varied one.
  static const int _maxGeneratedSpeaking = 1;

  /// The whole per-attempt transformation: reorder, then re-form.
  ///
  /// [prioritizeIds] are exercises the learner has previously got wrong
  /// (the mistake bank). They lead the round, so a retry — after running
  /// out of hearts, or just replaying — starts with what actually needs
  /// the practice rather than with what's already mastered.
  static Lesson buildSession({
    required Lesson lesson,
    required List<VocabWord> words,
    required String? languageId,
    required Random random,
    Set<String> prioritizeIds = const {},
  }) {
    final varied = varyTypes(
      exercises: lesson.exercises,
      words: words,
      languageId: languageId,
      random: random,
    );
    return Lesson(
      id: lesson.id,
      title: lesson.title,
      subtitle: lesson.subtitle,
      icon: lesson.icon,
      exercises: shuffleOrder(varied, random, prioritizeIds: prioritizeIds),
    );
  }

  /// An *anchored* shuffle: word-matching sets are the summary round-up
  /// of everything a lesson taught (they are authored last for that
  /// reason), so they stay at the end while everything before them is
  /// reordered freely. A flat shuffle that opened with the four-pair
  /// summary would be worse than no shuffle at all.
  ///
  /// Within the teaching block, previously-missed exercises come first —
  /// shuffled among themselves, so "the hard ones first" doesn't become
  /// its own fixed order.
  static List<Exercise> shuffleOrder(
    List<Exercise> exercises,
    Random random, {
    Set<String> prioritizeIds = const {},
  }) {
    final missed = <Exercise>[];
    final teaching = <Exercise>[];
    final summary = <Exercise>[];
    for (final e in exercises) {
      if (e.type == ExerciseType.wordMatching) {
        summary.add(e);
      } else if (prioritizeIds.contains(e.id)) {
        missed.add(e);
      } else {
        teaching.add(e);
      }
    }
    missed.shuffle(random);
    teaching.shuffle(random);
    summary.shuffle(random);
    return [...missed, ...teaching, ...summary];
  }

  /// Re-asks a bounded random subset of [exercises] through a different
  /// exercise type. Order is preserved here; [shuffleOrder] handles that.
  static List<Exercise> varyTypes({
    required List<Exercise> exercises,
    required List<VocabWord> words,
    required String? languageId,
    required Random random,
  }) {
    if (words.isEmpty) return List<Exercise>.from(exercises);

    final byId = {for (final w in words) w.id: w};
    final ttsLocale = TtsLocales.forLanguageId(languageId);

    // Which slots could be re-formed at all.
    final eligible = <int>[];
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      if (_neverGenerated.contains(e.type)) continue;
      if (!byId.containsKey(e.vocabId)) continue;
      eligible.add(i);
    }
    if (eligible.isEmpty) return List<Exercise>.from(exercises);

    eligible.shuffle(random);
    final budget = max(1, (eligible.length * _maxSwapFraction).round());

    final result = List<Exercise>.from(exercises);
    var swapped = 0;
    var speakingGenerated = 0;

    for (final index in eligible) {
      if (swapped >= budget) break;
      final original = exercises[index];
      final word = byId[original.vocabId]!;

      final candidates = _candidateTypesFor(word)
          .where((t) => t != original.type)
          .where((t) => t != ExerciseType.speaking ||
              speakingGenerated < _maxGeneratedSpeaking)
          .toList();
      if (candidates.isEmpty) continue;

      final type = candidates[random.nextInt(candidates.length)];
      final variant = _build(
        id: original.id,
        vocabId: original.vocabId,
        type: type,
        word: word,
        pool: words,
        ttsLocale: ttsLocale,
        random: random,
      );
      if (variant == null) continue;

      result[index] = variant;
      swapped++;
      if (type == ExerciseType.speaking) speakingGenerated++;
    }

    return result;
  }

  /// Every form a single word can honestly be asked in. Image
  /// recognition needs an emoji to stand in as "the image"; everything
  /// else only needs the word and its translation.
  static List<ExerciseType> _candidateTypesFor(VocabWord word) {
    return [
      ExerciseType.multipleChoice,
      ExerciseType.translation,
      ExerciseType.listening,
      ExerciseType.speaking,
      if (word.emoji != null) ExerciseType.imageRecognition,
    ];
  }

  static Exercise? _build({
    required String id,
    required String vocabId,
    required ExerciseType type,
    required VocabWord word,
    required List<VocabWord> pool,
    required String ttsLocale,
    required Random random,
  }) {
    switch (type) {
      // Half the time "which word means X" (recognise the target
      // language), half "what does X mean" (produce the English) — the
      // same word asked from both directions across attempts.
      case ExerciseType.multipleChoice:
        final askMeaning = random.nextBool();
        final distractors = _distractors(word, pool, random, 3);
        if (distractors.length < 2) return null;
        if (askMeaning) {
          final options = [word.translation, ...distractors.map((w) => w.translation)]
            ..shuffle(random);
          return Exercise(
            id: id,
            type: ExerciseType.multipleChoice,
            vocabId: vocabId,
            payload: MultipleChoicePayload(
              prompt: 'What does “${word.word}” mean?',
              options: options,
              correctIndex: options.indexOf(word.translation),
            ),
          );
        }
        final options = [word.word, ...distractors.map((w) => w.word)]..shuffle(random);
        return Exercise(
          id: id,
          type: ExerciseType.multipleChoice,
          vocabId: vocabId,
          payload: MultipleChoicePayload(
            prompt: "Which word means '${word.translation}'?",
            options: options,
            correctIndex: options.indexOf(word.word),
          ),
        );

      // The instruction names the language being asked for, so a learner
      // is never left guessing which side of the pair to type.
      case ExerciseType.translation:
        return Exercise(
          id: id,
          type: ExerciseType.translation,
          vocabId: vocabId,
          payload: TranslationPayload(
            prompt: 'Type the English meaning of this word',
            sourceText: word.word,
            acceptableAnswers: [word.translation],
          ),
        );

      case ExerciseType.listening:
        final distractors = _distractors(word, pool, random, 3);
        if (distractors.length < 2) return null;
        final options = [word.word, ...distractors.map((w) => w.word)]..shuffle(random);
        return Exercise(
          id: id,
          type: ExerciseType.listening,
          vocabId: vocabId,
          payload: ListeningPayload(
            prompt: 'Listen and select what you hear',
            audioText: word.word,
            ttsLocale: ttsLocale,
            options: options,
            correctIndex: options.indexOf(word.word),
          ),
        );

      case ExerciseType.speaking:
        return Exercise(
          id: id,
          type: ExerciseType.speaking,
          vocabId: vocabId,
          payload: SpeakingPayload(
            prompt: 'Say this word out loud',
            targetPhrase: word.word,
            translation: word.translation,
            ttsLocale: ttsLocale,
          ),
        );

      case ExerciseType.imageRecognition:
        final emoji = word.emoji;
        if (emoji == null) return null;
        final distractors = _distractors(word, pool, random, 3);
        if (distractors.length < 2) return null;
        return Exercise(
          id: id,
          type: ExerciseType.imageRecognition,
          vocabId: vocabId,
          payload: ImageRecognitionPayload(
            prompt: 'What does this word mean?',
            emoji: emoji,
            targetWord: word.word,
            meaning: word.translation,
            distractorMeanings: distractors.map((w) => w.translation).toList(),
            distractorWords: distractors.map((w) => w.word).toList(),
          ),
        );

      case ExerciseType.wordMatching:
      case ExerciseType.sentenceArrangement:
      case ExerciseType.fillInTheBlank:
        return null;
    }
  }

  /// Up to [count] wrong choices, drawn from the target's own category
  /// when that category is deep enough to supply them (mixing "Mother"
  /// with "Left" makes a question answerable without knowing the word),
  /// and from the whole pool otherwise. De-duplicated on the rendered
  /// strings so an option list can never show the same text twice.
  static List<VocabWord> _distractors(
    VocabWord target,
    List<VocabWord> pool,
    Random random,
    int count,
  ) {
    List<VocabWord> candidates = pool
        .where((w) =>
            w.id != target.id &&
            w.word != target.word &&
            w.translation != target.translation)
        .toList();

    final sameCategory =
        candidates.where((w) => w.category == target.category).toList();
    if (sameCategory.length >= count) candidates = sameCategory;

    candidates.shuffle(random);

    final picked = <VocabWord>[];
    final usedWords = <String>{target.word};
    final usedMeanings = <String>{target.translation};
    for (final w in candidates) {
      if (picked.length >= count) break;
      if (!usedWords.add(w.word)) continue;
      if (!usedMeanings.add(w.translation)) continue;
      picked.add(w);
    }
    return picked;
  }
}

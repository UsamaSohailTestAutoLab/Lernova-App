import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/string_normalize.dart';
import '../../../data/models/fun/phrase.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import '../domain/recall_challenge.dart';
import 'falling_word_session_controller.dart';
import 'fun_progress_controller.dart';

class FunSentenceBuilderState {
  final List<Phrase> pool;
  final int totalRounds;
  final int currentRoundIndex;
  final Phrase currentPhrase;
  final List<String> shuffledTokens;
  final List<int> chosenIndices;
  final int lives;
  final int combo;
  final int bestCombo;
  final int xpEarned;
  final int coinsEarned;
  final int correctCount;
  final int wrongCount;
  final Map<String, int> vocabDeltas;
  final bool isComplete;
  final bool failed;
  final LessonCompletionResult? result;
  final bool funLeveledUp;
  final bool dailyChallengeJustCompleted;
  final RecallChallenge? pendingRecall;
  final int recallAttempts;

  const FunSentenceBuilderState({
    required this.pool,
    required this.totalRounds,
    required this.currentRoundIndex,
    required this.currentPhrase,
    required this.shuffledTokens,
    required this.chosenIndices,
    required this.lives,
    required this.combo,
    required this.bestCombo,
    required this.xpEarned,
    required this.coinsEarned,
    required this.correctCount,
    required this.wrongCount,
    required this.vocabDeltas,
    required this.isComplete,
    required this.failed,
    this.result,
    this.funLeveledUp = false,
    this.dailyChallengeJustCompleted = false,
    this.pendingRecall,
    this.recallAttempts = 0,
  });

  List<int> get availableIndices => List.generate(shuffledTokens.length, (i) => i)
      .where((i) => !chosenIndices.contains(i))
      .toList();
  bool get sentenceReady => chosenIndices.length == shuffledTokens.length;
  int get answeredCount => correctCount + wrongCount;
  double get accuracy => answeredCount == 0 ? 1 : correctCount / answeredCount;
  bool get isPerfectRound => wrongCount == 0 && answeredCount > 0;

  FunSentenceBuilderState copyWith({
    int? currentRoundIndex,
    Phrase? currentPhrase,
    List<String>? shuffledTokens,
    List<int>? chosenIndices,
    int? lives,
    int? combo,
    int? bestCombo,
    int? xpEarned,
    int? coinsEarned,
    int? correctCount,
    int? wrongCount,
    Map<String, int>? vocabDeltas,
    bool? isComplete,
    bool? failed,
    LessonCompletionResult? result,
    bool? funLeveledUp,
    bool? dailyChallengeJustCompleted,
    RecallChallenge? pendingRecall,
    bool clearPendingRecall = false,
    int? recallAttempts,
  }) {
    return FunSentenceBuilderState(
      pool: pool,
      totalRounds: totalRounds,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      currentPhrase: currentPhrase ?? this.currentPhrase,
      shuffledTokens: shuffledTokens ?? this.shuffledTokens,
      chosenIndices: chosenIndices ?? this.chosenIndices,
      lives: lives ?? this.lives,
      combo: combo ?? this.combo,
      bestCombo: bestCombo ?? this.bestCombo,
      xpEarned: xpEarned ?? this.xpEarned,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      vocabDeltas: vocabDeltas ?? this.vocabDeltas,
      isComplete: isComplete ?? this.isComplete,
      failed: failed ?? this.failed,
      result: result ?? this.result,
      funLeveledUp: funLeveledUp ?? this.funLeveledUp,
      dailyChallengeJustCompleted:
          dailyChallengeJustCompleted ?? this.dailyChallengeJustCompleted,
      pendingRecall: clearPendingRecall ? null : (pendingRecall ?? this.pendingRecall),
      recallAttempts: recallAttempts ?? this.recallAttempts,
    );
  }
}

const _sentenceBuilderLives = 3;

/// Drives Sentence Builder: tap shuffled word chips into order to
/// rebuild a phrase. A correct sentence resolves immediately and moves
/// on; a wrong one blocks behind [pendingRecall] until the player
/// actively recalls the phrase's meaning.
class FunSentenceBuilderSessionController extends Notifier<FunSentenceBuilderState?> {
  @override
  FunSentenceBuilderState? build() => null;

  Phrase _pickPhrase(List<Phrase> pool, Random random) => pool[random.nextInt(pool.length)];

  List<String> _tokensFor(Phrase phrase, Random random) {
    final tokens = phrase.phrase.split(' ');
    final shuffled = List<String>.from(tokens);
    // Re-shuffle if it happens to land in the already-correct order for
    // anything with 3+ tokens (2-token phrases have only one wrong order).
    do {
      shuffled.shuffle(random);
    } while (tokens.length >= 3 && shuffled.join(' ') == phrase.phrase);
    return shuffled;
  }

  void start({required List<Phrase> pool, required int totalRounds, required Random random}) {
    if (pool.isEmpty) return;
    final phrase = _pickPhrase(pool, random);
    state = FunSentenceBuilderState(
      pool: pool,
      totalRounds: totalRounds,
      currentRoundIndex: 0,
      currentPhrase: phrase,
      shuffledTokens: _tokensFor(phrase, random),
      chosenIndices: const [],
      lives: _sentenceBuilderLives,
      combo: 0,
      bestCombo: 0,
      xpEarned: 0,
      coinsEarned: 0,
      correctCount: 0,
      wrongCount: 0,
      vocabDeltas: const {},
      isComplete: false,
      failed: false,
    );
  }

  void chooseToken(int index) {
    final s = state;
    if (s == null || s.isComplete || s.chosenIndices.contains(index)) return;
    state = s.copyWith(chosenIndices: [...s.chosenIndices, index]);
  }

  void removeToken(int position) {
    final s = state;
    if (s == null || s.isComplete) return;
    final chosen = List<int>.from(s.chosenIndices)..removeAt(position);
    state = s.copyWith(chosenIndices: chosen);
  }

  void submitSentence(Random random) {
    final s = state;
    if (s == null || s.isComplete || s.pendingRecall != null || !s.sentenceReady) return;

    final built = s.chosenIndices.map((i) => s.shuffledTokens[i]).join(' ');
    final correct = built == s.currentPhrase.phrase;

    final vocabDeltas = Map<String, int>.from(s.vocabDeltas);
    vocabDeltas[s.currentPhrase.id] =
        (vocabDeltas[s.currentPhrase.id] ?? 0) + (correct ? 1 : -1);

    if (correct) {
      final combo = s.combo + 1;
      final bestCombo = combo > s.bestCombo ? combo : s.bestCombo;
      final xp = s.xpEarned + 5 * FallingWordSessionController.comboMultiplier(combo);
      final coins = s.coinsEarned + 2;
      final nextRoundIndex = s.currentRoundIndex + 1;
      final isComplete = nextRoundIndex >= s.totalRounds;

      if (isComplete) {
        state = s.copyWith(
          combo: combo,
          bestCombo: bestCombo,
          xpEarned: xp,
          coinsEarned: coins,
          correctCount: s.correctCount + 1,
          vocabDeltas: vocabDeltas,
          isComplete: true,
          failed: false,
        );
        return;
      }

      final nextPhrase = _pickPhrase(s.pool, random);
      state = s.copyWith(
        currentRoundIndex: nextRoundIndex,
        currentPhrase: nextPhrase,
        shuffledTokens: _tokensFor(nextPhrase, random),
        chosenIndices: const [],
        combo: combo,
        bestCombo: bestCombo,
        xpEarned: xp,
        coinsEarned: coins,
        correctCount: s.correctCount + 1,
        vocabDeltas: vocabDeltas,
      );
      return;
    }

    // Wrong: lives/combo bookkeeping now, hold the round-advance behind
    // the recall challenge.
    state = s.copyWith(
      combo: 0,
      lives: (s.lives - 1).clamp(0, _sentenceBuilderLives),
      wrongCount: s.wrongCount + 1,
      vocabDeltas: vocabDeltas,
      pendingRecall: RecallChallenge(
        promptWord: s.currentPhrase.phrase,
        correctMeaning: s.currentPhrase.meaning,
        listenText: s.currentPhrase.phrase,
      ),
      recallAttempts: 0,
    );
  }

  /// The player typed a guess at the missed phrase's meaning.
  void submitRecallAnswer(String typed, Random random) {
    final s = state;
    if (s == null || s.pendingRecall == null) return;
    final correct =
        normalizeForMatch(typed) == normalizeForMatch(s.pendingRecall!.correctMeaning);
    if (correct) {
      _clearRecallAndAdvance(random);
    } else {
      state = s.copyWith(recallAttempts: s.recallAttempts + 1);
    }
  }

  /// The player acknowledged the revealed answer after exhausting their
  /// recall attempts.
  void acknowledgeRecall(Random random) {
    if (state?.pendingRecall == null) return;
    _clearRecallAndAdvance(random);
  }

  void _clearRecallAndAdvance(Random random) {
    final s = state!;
    final failed = s.lives <= 0;
    final nextRoundIndex = s.currentRoundIndex + 1;
    final isComplete = failed || nextRoundIndex >= s.totalRounds;

    if (isComplete) {
      state = s.copyWith(
        clearPendingRecall: true,
        recallAttempts: 0,
        isComplete: true,
        failed: failed,
      );
      return;
    }

    final nextPhrase = _pickPhrase(s.pool, random);
    state = s.copyWith(
      currentRoundIndex: nextRoundIndex,
      currentPhrase: nextPhrase,
      shuffledTokens: _tokensFor(nextPhrase, random),
      chosenIndices: const [],
      clearPendingRecall: true,
      recallAttempts: 0,
    );
  }

  LessonCompletionResult finishAndApply() {
    final s = state!;
    if (s.result != null) return s.result!;

    final result = ref.read(progressProvider.notifier).awardFunSession(
          xpEarned: s.xpEarned,
          coinsEarned: s.coinsEarned,
          vocabDeltas: s.vocabDeltas,
          isPerfectRound: s.isPerfectRound,
          isSpeedRound: false,
        );

    final leveledUp = ref.read(funProgressProvider.notifier).recordRoundResult(
          mode: FunGameMode.sentenceBuilder,
          accuracy: s.accuracy,
          comboAchieved: s.bestCombo,
          starsEarned: FallingWordSessionController.starsForAccuracy(s.accuracy),
        );

    final learnedToday =
        s.vocabDeltas.entries.where((e) => e.value > 0).map((e) => e.key).toSet();
    final challengeJustCompleted = ref
        .read(funProgressProvider.notifier)
        .recordWordsLearnedToday(learnedToday);

    state = s.copyWith(
      result: result,
      funLeveledUp: leveledUp,
      dailyChallengeJustCompleted: challengeJustCompleted,
    );
    return result;
  }

  void reset() => state = null;
}

final funSentenceBuilderSessionProvider =
    NotifierProvider<FunSentenceBuilderSessionController, FunSentenceBuilderState?>(
  FunSentenceBuilderSessionController.new,
);

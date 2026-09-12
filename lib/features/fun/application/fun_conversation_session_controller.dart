import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../data/models/fun/conversation.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import 'falling_word_session_controller.dart';
import 'fun_progress_controller.dart';

class FunConversationState {
  final List<Conversation> pool;
  final int totalConversations;
  final int currentConversationIndex;
  final Conversation currentConversation;
  final int currentTurnIndex;
  final List<bool?> turnCorrectness; // per turn in currentConversation, null = not yet answered

  /// Which option the player picked on each turn, so the feedback can
  /// show their reply next to the expected one rather than only naming
  /// the expected one. Null = not yet answered.
  final List<int?> chosenIndices;
  final int combo;
  final int bestCombo;
  final int xpEarned;
  final int correctCount;
  final int wrongCount;
  final Map<String, int> vocabDeltas;
  final bool isComplete;
  final LessonCompletionResult? result;
  final bool funLeveledUp;
  final bool dailyChallengeJustCompleted;

  /// True right after a wrong pick on the current turn — the correct
  /// response is already showing in the reply bubble, but the
  /// conversation won't advance until the player re-taps it themselves.
  final bool awaitingRecallConfirmation;

  const FunConversationState({
    required this.pool,
    required this.totalConversations,
    required this.currentConversationIndex,
    required this.currentConversation,
    required this.currentTurnIndex,
    required this.turnCorrectness,
    this.chosenIndices = const [],
    required this.combo,
    required this.bestCombo,
    required this.xpEarned,
    required this.correctCount,
    required this.wrongCount,
    required this.vocabDeltas,
    required this.isComplete,
    this.result,
    this.funLeveledUp = false,
    this.dailyChallengeJustCompleted = false,
    this.awaitingRecallConfirmation = false,
  });

  ConversationTurn get currentTurn => currentConversation.turns[currentTurnIndex];
  int get answeredCount => correctCount + wrongCount;
  double get accuracy => answeredCount == 0 ? 1 : correctCount / answeredCount;
  bool get isPerfectRound => wrongCount == 0 && answeredCount > 0;

  FunConversationState copyWith({
    int? currentConversationIndex,
    Conversation? currentConversation,
    int? currentTurnIndex,
    List<bool?>? turnCorrectness,
    List<int?>? chosenIndices,
    int? combo,
    int? bestCombo,
    int? xpEarned,
    int? correctCount,
    int? wrongCount,
    Map<String, int>? vocabDeltas,
    bool? isComplete,
    LessonCompletionResult? result,
    bool? funLeveledUp,
    bool? dailyChallengeJustCompleted,
    bool? awaitingRecallConfirmation,
  }) {
    return FunConversationState(
      pool: pool,
      totalConversations: totalConversations,
      currentConversationIndex: currentConversationIndex ?? this.currentConversationIndex,
      currentConversation: currentConversation ?? this.currentConversation,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      turnCorrectness: turnCorrectness ?? this.turnCorrectness,
      chosenIndices: chosenIndices ?? this.chosenIndices,
      combo: combo ?? this.combo,
      bestCombo: bestCombo ?? this.bestCombo,
      xpEarned: xpEarned ?? this.xpEarned,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      vocabDeltas: vocabDeltas ?? this.vocabDeltas,
      isComplete: isComplete ?? this.isComplete,
      result: result ?? this.result,
      funLeveledUp: funLeveledUp ?? this.funLeveledUp,
      dailyChallengeJustCompleted:
          dailyChallengeJustCompleted ?? this.dailyChallengeJustCompleted,
      awaitingRecallConfirmation:
          awaitingRecallConfirmation ?? this.awaitingRecallConfirmation,
    );
  }
}

/// Drives Conversation Challenge: pick the right response at each turn
/// of a short dialogue. Deliberately has no lives/fail state — a wrong
/// pick reveals the correct response, but (unlike before) the
/// conversation now blocks on that turn until the player re-taps the
/// revealed correct option themselves, turning the reveal into an
/// active-recall step instead of a passively-skipped-past one. Multiple
/// conversations can be chained in one session for a fuller round.
class FunConversationSessionController extends Notifier<FunConversationState?> {
  @override
  FunConversationState? build() => null;

  /// A lookup into the round set [start] drew up front, not a fresh
  /// draw — a session can't serve the same conversation twice, and the
  /// preview can name every scenario before play begins.
  Conversation _conversationAt(List<Conversation> pool, int index) =>
      pool[index % pool.length];

  void start({
    required List<Conversation> pool,
    required int totalConversations,
    required Random random,
  }) {
    if (pool.isEmpty) return;
    // Draw the whole session's conversations now, distinct, so a round
    // can't repeat a scenario and the preview can list them all.
    final drawn = List<Conversation>.from(pool)..shuffle(random);
    final count =
        totalConversations < drawn.length ? totalConversations : drawn.length;
    final roundSet = drawn.take(count).toList();
    final conversation = roundSet.first;
    state = FunConversationState(
      pool: roundSet,
      totalConversations: count,
      currentConversationIndex: 0,
      currentConversation: conversation,
      currentTurnIndex: 0,
      turnCorrectness: List<bool?>.filled(conversation.turns.length, null),
      chosenIndices: List<int?>.filled(conversation.turns.length, null),
      combo: 0,
      bestCombo: 0,
      xpEarned: 0,
      correctCount: 0,
      wrongCount: 0,
      vocabDeltas: const {},
      isComplete: false,
    );
  }

  void chooseResponse(int optionIndex, Random random) {
    final s = state;
    if (s == null || s.isComplete) return;
    final turn = s.currentTurn;

    if (s.awaitingRecallConfirmation) {
      // Already got this turn wrong once — the correct response is
      // showing in the bubble; only re-tapping it moves the chat on.
      if (optionIndex != turn.correctIndex) return;
      state = s.copyWith(awaitingRecallConfirmation: false);
      _advanceTurn(random);
      return;
    }

    if (s.turnCorrectness[s.currentTurnIndex] != null) return; // already answered

    final correct = optionIndex == turn.correctIndex;
    final vocabDeltas = Map<String, int>.from(s.vocabDeltas);
    vocabDeltas[turn.id] = (vocabDeltas[turn.id] ?? 0) + (correct ? 1 : -1);

    final turnCorrectness = List<bool?>.from(s.turnCorrectness);
    turnCorrectness[s.currentTurnIndex] = correct;

    final chosenIndices = s.chosenIndices.length == s.turnCorrectness.length
        ? (List<int?>.from(s.chosenIndices)..[s.currentTurnIndex] = optionIndex)
        : s.chosenIndices;

    if (correct) {
      final combo = s.combo + 1;
      final bestCombo = combo > s.bestCombo ? combo : s.bestCombo;
      state = s.copyWith(
        turnCorrectness: turnCorrectness,
        chosenIndices: chosenIndices,
        combo: combo,
        bestCombo: bestCombo,
        xpEarned: s.xpEarned + 5 * FallingWordSessionController.comboMultiplier(combo),
        correctCount: s.correctCount + 1,
        vocabDeltas: vocabDeltas,
      );
      _advanceTurn(random);
      return;
    }

    // Wrong: the reveal bubble now shows the correct response (driven by
    // turnCorrectness being non-null); block the chat until the player
    // re-taps it.
    state = s.copyWith(
      turnCorrectness: turnCorrectness,
      chosenIndices: chosenIndices,
      combo: 0,
      wrongCount: s.wrongCount + 1,
      vocabDeltas: vocabDeltas,
      awaitingRecallConfirmation: true,
    );
  }

  void _advanceTurn(Random random) {
    final s = state!;
    final nextTurnIndex = s.currentTurnIndex + 1;
    final conversationDone = nextTurnIndex >= s.currentConversation.turns.length;

    if (!conversationDone) {
      state = s.copyWith(currentTurnIndex: nextTurnIndex);
      return;
    }

    final nextConversationIndex = s.currentConversationIndex + 1;
    final sessionDone = nextConversationIndex >= s.totalConversations;

    if (sessionDone) {
      state = s.copyWith(isComplete: true);
      return;
    }

    final nextConversation = _conversationAt(s.pool, nextConversationIndex);
    state = s.copyWith(
      currentConversationIndex: nextConversationIndex,
      currentConversation: nextConversation,
      currentTurnIndex: 0,
      turnCorrectness: List<bool?>.filled(nextConversation.turns.length, null),
      chosenIndices: List<int?>.filled(nextConversation.turns.length, null),
    );
  }

  LessonCompletionResult finishAndApply() {
    final s = state!;
    if (s.result != null) return s.result!;

    final result = ref.read(progressProvider.notifier).awardFunSession(
          xpEarned: s.xpEarned,
          vocabDeltas: s.vocabDeltas,
          isPerfectRound: s.isPerfectRound,
          isSpeedRound: false,
        );

    final leveledUp = ref.read(funProgressProvider.notifier).recordRoundResult(
          mode: FunGameMode.conversationChallenge,
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

final funConversationSessionProvider =
    NotifierProvider<FunConversationSessionController, FunConversationState?>(
  FunConversationSessionController.new,
);

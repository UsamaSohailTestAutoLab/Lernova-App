import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../data/models/fun/vocab_word.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import 'falling_word_session_controller.dart';
import 'fun_progress_controller.dart';
import 'fun_question_generator.dart';

class MemoryCard {
  final String label;
  final String pairId;
  const MemoryCard({required this.label, required this.pairId});
}

/// A round opens by showing the whole board.
///
/// Starting face-down made the first few flips pure guesswork — there is
/// nothing to *remember* yet, so the opening moves cost lives for no
/// reason and taught nothing. Showing the arrangement first turns the
/// round into the memory exercise it is named after.
enum MemoryMatchPhase {
  /// Every card face up, taps ignored, a countdown running.
  memorising,

  /// Board face down, normal play.
  playing,
}

class FunMemoryMatchState {
  final MemoryMatchPhase phase;
  final List<MemoryCard> cards;
  final List<VocabWord> sourceWords;
  final Set<int> flippedIndices;
  final Set<int> matchedIndices;
  final int lives;
  final int combo;
  final int bestCombo;
  final int xpEarned;
  final int coinsEarned;
  final int matchesFound;
  final int mismatches;
  final Map<String, int> vocabDeltas;
  final bool isComplete;
  final bool failed;
  final LessonCompletionResult? result;
  final bool funLeveledUp;
  final bool dailyChallengeJustCompleted;

  const FunMemoryMatchState({
    this.phase = MemoryMatchPhase.memorising,
    required this.cards,
    required this.sourceWords,
    required this.flippedIndices,
    required this.matchedIndices,
    required this.lives,
    required this.combo,
    required this.bestCombo,
    required this.xpEarned,
    required this.coinsEarned,
    required this.matchesFound,
    required this.mismatches,
    required this.vocabDeltas,
    required this.isComplete,
    required this.failed,
    this.result,
    this.funLeveledUp = false,
    this.dailyChallengeJustCompleted = false,
  });

  int get pairCount => cards.length ~/ 2;
  int get answeredCount => matchesFound + mismatches;
  double get accuracy => answeredCount == 0 ? 1 : matchesFound / answeredCount;
  bool get isPerfectRound => mismatches == 0 && answeredCount > 0;

  FunMemoryMatchState copyWith({
    MemoryMatchPhase? phase,
    Set<int>? flippedIndices,
    Set<int>? matchedIndices,
    int? lives,
    int? combo,
    int? bestCombo,
    int? xpEarned,
    int? coinsEarned,
    int? matchesFound,
    int? mismatches,
    Map<String, int>? vocabDeltas,
    bool? isComplete,
    bool? failed,
    LessonCompletionResult? result,
    bool? funLeveledUp,
    bool? dailyChallengeJustCompleted,
  }) {
    return FunMemoryMatchState(
      phase: phase ?? this.phase,
      cards: cards,
      sourceWords: sourceWords,
      flippedIndices: flippedIndices ?? this.flippedIndices,
      matchedIndices: matchedIndices ?? this.matchedIndices,
      lives: lives ?? this.lives,
      combo: combo ?? this.combo,
      bestCombo: bestCombo ?? this.bestCombo,
      xpEarned: xpEarned ?? this.xpEarned,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      matchesFound: matchesFound ?? this.matchesFound,
      mismatches: mismatches ?? this.mismatches,
      vocabDeltas: vocabDeltas ?? this.vocabDeltas,
      isComplete: isComplete ?? this.isComplete,
      failed: failed ?? this.failed,
      result: result ?? this.result,
      funLeveledUp: funLeveledUp ?? this.funLeveledUp,
      dailyChallengeJustCompleted:
          dailyChallengeJustCompleted ?? this.dailyChallengeJustCompleted,
    );
  }
}

// More forgiving than the other modes — memory games naturally involve
// a lot of expected wrong guesses while the grid is still unfamiliar.
const _memoryMatchLives = 5;

/// Drives a Memory Match round: flip two cards, a matching word/meaning
/// pair stays face up, a mismatch costs a life and combo before flipping
/// back down. [flipCard] resolves a pair the instant the second card is
/// tapped; the screen is responsible for calling [resolveMismatch] after
/// a short delay so the player actually gets to see what they flipped
/// before it flips back.
class FunMemoryMatchSessionController extends Notifier<FunMemoryMatchState?> {
  @override
  FunMemoryMatchState? build() => null;

  void start({
    required List<VocabWord> words,
    required Map<String, int> vocabStrength,
    required int pairCount,
    required Random random,
  }) {
    final picked = FunQuestionGenerator.weightedWordSample(words, vocabStrength, pairCount, random);
    final cards = <MemoryCard>[
      for (final w in picked) MemoryCard(label: w.word, pairId: w.id),
      for (final w in picked) MemoryCard(label: w.translation, pairId: w.id),
    ]..shuffle(random);

    state = FunMemoryMatchState(
      phase: MemoryMatchPhase.memorising,
      cards: cards,
      sourceWords: picked,
      flippedIndices: const {},
      matchedIndices: const {},
      lives: _memoryMatchLives,
      combo: 0,
      bestCombo: 0,
      xpEarned: 0,
      coinsEarned: 0,
      matchesFound: 0,
      mismatches: 0,
      vocabDeltas: const {},
      isComplete: false,
      failed: false,
    );
  }

  /// How long the board stays face up before play begins.
  ///
  /// Ten seconds is the floor — anything less and a board of six pairs
  /// is gone before you've read it. Bigger boards get longer still,
  /// since every extra pair is two more cards to place.
  static Duration memoriseDuration(int pairCount) =>
      Duration(seconds: (8 + pairCount).clamp(10, 20));

  /// Ends the memorise phase and turns the board face down. Safe to call
  /// more than once — a late timer after the player has already started
  /// playing is a no-op rather than a reset.
  void beginPlay() {
    final s = state;
    if (s == null || s.phase != MemoryMatchPhase.memorising) return;
    state = s.copyWith(phase: MemoryMatchPhase.playing);
  }

  void flipCard(int index) {
    final s = state;
    if (s == null || s.isComplete) return;
    // Taps during the memorise phase would flip cards that are already
    // showing, and burn lives on a board the player is still reading.
    if (s.phase != MemoryMatchPhase.playing) return;
    if (s.matchedIndices.contains(index) || s.flippedIndices.contains(index)) return;
    if (s.flippedIndices.length >= 2) return; // waiting for the mismatch to resolve

    final flipped = {...s.flippedIndices, index};
    if (flipped.length < 2) {
      state = s.copyWith(flippedIndices: flipped);
      return;
    }

    final indices = flipped.toList();
    final cardA = s.cards[indices[0]];
    final cardB = s.cards[indices[1]];
    final vocabDeltas = Map<String, int>.from(s.vocabDeltas);

    if (cardA.pairId == cardB.pairId) {
      final matched = {...s.matchedIndices, ...flipped};
      final combo = s.combo + 1;
      final bestCombo = combo > s.bestCombo ? combo : s.bestCombo;
      vocabDeltas[cardA.pairId] = (vocabDeltas[cardA.pairId] ?? 0) + 1;

      state = s.copyWith(
        matchedIndices: matched,
        flippedIndices: const {},
        combo: combo,
        bestCombo: bestCombo,
        xpEarned: s.xpEarned + 5 * FallingWordSessionController.comboMultiplier(combo),
        coinsEarned: s.coinsEarned + 2,
        matchesFound: s.matchesFound + 1,
        vocabDeltas: vocabDeltas,
        isComplete: matched.length == s.cards.length,
      );
    } else {
      vocabDeltas[cardA.pairId] = (vocabDeltas[cardA.pairId] ?? 0) - 1;
      vocabDeltas[cardB.pairId] = (vocabDeltas[cardB.pairId] ?? 0) - 1;
      final lives = s.lives - 1;

      state = s.copyWith(
        // Left flipped so the screen can show both cards red for a
        // moment; resolveMismatch() turns them back over after a short
        // delay, and that is where isComplete/failed get decided.
        flippedIndices: flipped,
        combo: 0,
        lives: lives,
        mismatches: s.mismatches + 1,
        vocabDeltas: vocabDeltas,
      );
    }
  }

  /// Turns the briefly-shown wrong pair back over.
  ///
  /// No written correction here, unlike the other Fun modes. Memory
  /// Match is a *placement* game — you already know what the words mean
  /// from the memorise phase, and the thing you got wrong was where
  /// they are. Stopping the round to type a meaning interrupted the
  /// board you were holding in your head, so a mismatch is now just the
  /// two cards flashing red and flipping back.
  void resolveMismatch() {
    final s = state;
    if (s == null || s.flippedIndices.length != 2) return;
    if (s.matchedIndices.containsAll(s.flippedIndices)) return;

    final failed = s.lives <= 0;
    state = s.copyWith(flippedIndices: const {}, isComplete: failed, failed: failed);
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
          mode: FunGameMode.memoryMatch,
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

final funMemoryMatchSessionProvider =
    NotifierProvider<FunMemoryMatchSessionController, FunMemoryMatchState?>(
  FunMemoryMatchSessionController.new,
);

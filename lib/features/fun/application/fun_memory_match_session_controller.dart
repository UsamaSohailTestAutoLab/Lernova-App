import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/string_normalize.dart';
import '../../../data/models/fun/vocab_word.dart';
import '../../../data/repositories/vocab_lookup.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import '../domain/recall_challenge.dart';
import 'falling_word_session_controller.dart';
import 'fun_progress_controller.dart';
import 'fun_question_generator.dart';

class MemoryCard {
  final String label;
  final String pairId;
  const MemoryCard({required this.label, required this.pairId});
}

class FunMemoryMatchState {
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
  final RecallChallenge? pendingRecall;
  final int recallAttempts;

  const FunMemoryMatchState({
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
    this.pendingRecall,
    this.recallAttempts = 0,
  });

  int get pairCount => cards.length ~/ 2;
  int get answeredCount => matchesFound + mismatches;
  double get accuracy => answeredCount == 0 ? 1 : matchesFound / answeredCount;
  bool get isPerfectRound => mismatches == 0 && answeredCount > 0;

  FunMemoryMatchState copyWith({
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
    RecallChallenge? pendingRecall,
    bool clearPendingRecall = false,
    int? recallAttempts,
  }) {
    return FunMemoryMatchState(
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
      pendingRecall: clearPendingRecall ? null : (pendingRecall ?? this.pendingRecall),
      recallAttempts: recallAttempts ?? this.recallAttempts,
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

  void flipCard(int index) {
    final s = state;
    if (s == null || s.isComplete || s.pendingRecall != null) return;
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
        // Left flipped so the UI can show the wrong pair briefly; the
        // screen clears it via resolveMismatch() after a short delay,
        // which is also where the recall challenge for the correct
        // pairing gets set — isComplete/failed aren't decided until
        // that recall resolves.
        flippedIndices: flipped,
        combo: 0,
        lives: lives,
        mismatches: s.mismatches + 1,
        vocabDeltas: vocabDeltas,
      );
    }
  }

  /// Clears the briefly-shown wrong pair and, unless something's gone
  /// astray with the content pool, sets a recall challenge for the
  /// correct pairing of the first card the player flipped — showing the
  /// player's own wrong guess isn't the same as showing them the right
  /// answer, so this is what actually closes that gap.
  void resolveMismatch() {
    final s = state;
    if (s == null || s.flippedIndices.length != 2) return;
    if (s.matchedIndices.containsAll(s.flippedIndices)) return;

    final indices = s.flippedIndices.toList();
    final cardA = s.cards[indices[0]];
    final partnerWord = VocabLookup.findWordById(s.sourceWords, cardA.pairId);

    if (partnerWord == null) {
      final failed = s.lives <= 0;
      state = s.copyWith(flippedIndices: const {}, isComplete: failed, failed: failed);
      return;
    }

    state = s.copyWith(
      flippedIndices: const {},
      pendingRecall: RecallChallenge(
        promptWord: partnerWord.word,
        correctMeaning: partnerWord.translation,
        listenText: partnerWord.word,
      ),
      recallAttempts: 0,
    );
  }

  /// The player typed a guess at the correct pairing's meaning.
  void submitRecallAnswer(String typed) {
    final s = state;
    if (s == null || s.pendingRecall == null) return;
    final correct =
        normalizeForMatch(typed) == normalizeForMatch(s.pendingRecall!.correctMeaning);
    if (correct) {
      _finalizeRecall();
    } else {
      state = s.copyWith(recallAttempts: s.recallAttempts + 1);
    }
  }

  /// The player acknowledged the revealed answer after exhausting their
  /// recall attempts.
  void acknowledgeRecall() {
    if (state?.pendingRecall == null) return;
    _finalizeRecall();
  }

  void _finalizeRecall() {
    final s = state!;
    final failed = s.lives <= 0;
    state = s.copyWith(
      clearPendingRecall: true,
      recallAttempts: 0,
      isComplete: failed,
      failed: failed,
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

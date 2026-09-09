import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/string_normalize.dart';
import '../../../data/models/fun/vocab_word.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import '../domain/recall_challenge.dart';
import 'falling_word_session_controller.dart';
import 'fun_progress_controller.dart';
import 'fun_question_generator.dart';

import '../../../core/constants/app_enums.dart';

class FunWordMatchState {
  final int totalRounds;
  final int pairsPerRound;
  final int currentRoundIndex;
  final List<VocabWord> currentRoundWords;
  final List<int> rightOrder; // shuffled original indices for the right column
  final Map<int, int> matched; // leftIndex -> rightOriginalIndex, current round only
  final int lives;
  final int combo;
  final int bestCombo;
  final int xpEarned;
  final int coinsEarned;
  final int correctPairs;
  final int wrongAttempts;
  final Map<String, int> vocabDeltas;
  final bool isComplete;
  final bool failed;
  final LessonCompletionResult? result;
  final bool funLeveledUp;
  final bool dailyChallengeJustCompleted;
  final RecallChallenge? pendingRecall;
  final int recallAttempts;

  const FunWordMatchState({
    required this.totalRounds,
    required this.pairsPerRound,
    required this.currentRoundIndex,
    required this.currentRoundWords,
    required this.rightOrder,
    required this.matched,
    required this.lives,
    required this.combo,
    required this.bestCombo,
    required this.xpEarned,
    required this.coinsEarned,
    required this.correctPairs,
    required this.wrongAttempts,
    required this.vocabDeltas,
    required this.isComplete,
    required this.failed,
    this.result,
    this.funLeveledUp = false,
    this.dailyChallengeJustCompleted = false,
    this.pendingRecall,
    this.recallAttempts = 0,
  });

  int get answeredCount => correctPairs + wrongAttempts;
  double get accuracy => answeredCount == 0 ? 1 : correctPairs / answeredCount;
  bool get isPerfectRound => wrongAttempts == 0 && answeredCount > 0;

  FunWordMatchState copyWith({
    int? currentRoundIndex,
    List<VocabWord>? currentRoundWords,
    List<int>? rightOrder,
    Map<int, int>? matched,
    int? lives,
    int? combo,
    int? bestCombo,
    int? xpEarned,
    int? coinsEarned,
    int? correctPairs,
    int? wrongAttempts,
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
    return FunWordMatchState(
      totalRounds: totalRounds,
      pairsPerRound: pairsPerRound,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      currentRoundWords: currentRoundWords ?? this.currentRoundWords,
      rightOrder: rightOrder ?? this.rightOrder,
      matched: matched ?? this.matched,
      lives: lives ?? this.lives,
      combo: combo ?? this.combo,
      bestCombo: bestCombo ?? this.bestCombo,
      xpEarned: xpEarned ?? this.xpEarned,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      correctPairs: correctPairs ?? this.correctPairs,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
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

const _wordMatchLives = 3;

/// Drives a Word Match round: tap a word on the left, then its meaning
/// on the right. A correct pair locks in green; a wrong pair flashes
/// red, costs a life and resets combo, then blocks the grid behind
/// [pendingRecall] until the player actively recalls the missed word's
/// meaning. Once every pair in a round is matched, the next round's
/// words load; the session ends on finishing every round or on 0 lives,
/// same shape as [FallingWordSessionController].
class FunWordMatchSessionController extends Notifier<FunWordMatchState?> {
  @override
  FunWordMatchState? build() => null;

  void start({
    required List<VocabWord> words,
    required Map<String, int> vocabStrength,
    required int totalRounds,
    required int pairsPerRound,
    required Random random,
  }) {
    final roundWords = _pickRoundWords(words, vocabStrength, pairsPerRound, random);
    state = FunWordMatchState(
      totalRounds: totalRounds,
      pairsPerRound: pairsPerRound,
      currentRoundIndex: 0,
      currentRoundWords: roundWords,
      rightOrder: List.generate(roundWords.length, (i) => i)..shuffle(random),
      matched: const {},
      lives: _wordMatchLives,
      combo: 0,
      bestCombo: 0,
      xpEarned: 0,
      coinsEarned: 0,
      correctPairs: 0,
      wrongAttempts: 0,
      vocabDeltas: const {},
      isComplete: false,
      failed: false,
    );
    _wordsPool = words;
    _vocabStrength = vocabStrength;
  }

  List<VocabWord> _wordsPool = const [];
  Map<String, int> _vocabStrength = const {};

  List<VocabWord> _pickRoundWords(
    List<VocabWord> words,
    Map<String, int> vocabStrength,
    int count,
    Random random,
  ) {
    return FunQuestionGenerator.weightedWordSample(words, vocabStrength, count, random);
  }

  void attemptPair(int leftIndex, int rightOriginalIndex, Random random) {
    final s = state;
    if (s == null || s.isComplete || s.pendingRecall != null) return;
    if (s.matched.containsKey(leftIndex) || s.matched.containsValue(rightOriginalIndex)) return;

    final word = s.currentRoundWords[leftIndex];
    final vocabDeltas = Map<String, int>.from(s.vocabDeltas);

    if (leftIndex == rightOriginalIndex) {
      final matched = {...s.matched, leftIndex: rightOriginalIndex};
      final combo = s.combo + 1;
      final bestCombo = combo > s.bestCombo ? combo : s.bestCombo;
      final multiplier = FallingWordSessionController.comboMultiplier(combo);
      vocabDeltas[word.id] = (vocabDeltas[word.id] ?? 0) + 1;

      final roundComplete = matched.length == s.currentRoundWords.length;
      final isLastRound = s.currentRoundIndex + 1 >= s.totalRounds;

      if (roundComplete && isLastRound) {
        state = s.copyWith(
          matched: matched,
          combo: combo,
          bestCombo: bestCombo,
          xpEarned: s.xpEarned + 5 * multiplier,
          coinsEarned: s.coinsEarned + 2,
          correctPairs: s.correctPairs + 1,
          vocabDeltas: vocabDeltas,
          isComplete: true,
        );
      } else if (roundComplete) {
        final nextRoundWords =
            _pickRoundWords(_wordsPool, _vocabStrength, s.pairsPerRound, random);
        state = s.copyWith(
          currentRoundIndex: s.currentRoundIndex + 1,
          currentRoundWords: nextRoundWords,
          rightOrder: List.generate(nextRoundWords.length, (i) => i)..shuffle(random),
          matched: const {},
          combo: combo,
          bestCombo: bestCombo,
          xpEarned: s.xpEarned + 5 * multiplier,
          coinsEarned: s.coinsEarned + 2,
          correctPairs: s.correctPairs + 1,
          vocabDeltas: vocabDeltas,
        );
      } else {
        state = s.copyWith(
          matched: matched,
          combo: combo,
          bestCombo: bestCombo,
          xpEarned: s.xpEarned + 5 * multiplier,
          coinsEarned: s.coinsEarned + 2,
          correctPairs: s.correctPairs + 1,
          vocabDeltas: vocabDeltas,
        );
      }
    } else {
      vocabDeltas[word.id] = (vocabDeltas[word.id] ?? 0) - 1;
      final lives = s.lives - 1;
      state = s.copyWith(
        combo: 0,
        lives: lives,
        wrongAttempts: s.wrongAttempts + 1,
        vocabDeltas: vocabDeltas,
        pendingRecall: RecallChallenge(
          promptWord: word.word,
          correctMeaning: word.translation,
          listenText: word.word,
        ),
        recallAttempts: 0,
      );
    }
  }

  /// The player typed a guess at the missed word's meaning.
  void submitRecallAnswer(String typed) {
    final s = state;
    if (s == null || s.pendingRecall == null) return;
    final correct =
        matchesTypedAnswer(typed, s.pendingRecall!.correctMeaning);
    if (correct) {
      _clearRecall();
    } else {
      state = s.copyWith(recallAttempts: s.recallAttempts + 1);
    }
  }

  /// The player acknowledged the revealed answer after exhausting their
  /// recall attempts.
  void acknowledgeRecall() {
    if (state?.pendingRecall == null) return;
    _clearRecall();
  }

  void _clearRecall() {
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
          mode: FunGameMode.wordMatch,
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

final funWordMatchSessionProvider =
    NotifierProvider<FunWordMatchSessionController, FunWordMatchState?>(
  FunWordMatchSessionController.new,
);

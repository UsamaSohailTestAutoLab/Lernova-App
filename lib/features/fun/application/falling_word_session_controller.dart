import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/string_normalize.dart';
import '../../../data/models/fun/fun_level_config.dart';
import '../../../data/models/fun/fun_question.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import '../domain/recall_challenge.dart';
import 'fun_progress_controller.dart';

class FallingWordSessionState {
  final FunGameMode mode;
  final FunLevelConfig levelConfig;
  final List<FunQuestion> questions;
  final int currentIndex;
  final int lives;
  final int combo;
  final int bestCombo;
  final int xpEarned;
  final int coinsEarned;
  final int correctCount;
  final int mistakeCount;
  final Map<String, int> vocabDeltas;
  final int consecutiveFastAnswers;
  final bool speedAchieved;
  final bool isComplete;
  final bool failed;
  final DateTime questionStartedAt;
  final DateTime roundStartedAt;
  final LessonCompletionResult? result;
  final bool funLeveledUp;
  final bool dailyChallengeJustCompleted;
  final RecallChallenge? pendingRecall;
  final int recallAttempts;

  const FallingWordSessionState({
    required this.mode,
    required this.levelConfig,
    required this.questions,
    required this.currentIndex,
    required this.lives,
    required this.combo,
    required this.bestCombo,
    required this.xpEarned,
    required this.coinsEarned,
    required this.correctCount,
    required this.mistakeCount,
    required this.vocabDeltas,
    required this.consecutiveFastAnswers,
    required this.speedAchieved,
    required this.isComplete,
    required this.failed,
    required this.questionStartedAt,
    required this.roundStartedAt,
    this.result,
    this.funLeveledUp = false,
    this.dailyChallengeJustCompleted = false,
    this.pendingRecall,
    this.recallAttempts = 0,
  });

  FunQuestion? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  int get answeredCount => correctCount + mistakeCount;
  double get accuracy => answeredCount == 0 ? 1 : correctCount / answeredCount;
  bool get isPerfectRound => mistakeCount == 0 && answeredCount > 0;

  FallingWordSessionState copyWith({
    int? currentIndex,
    int? lives,
    int? combo,
    int? bestCombo,
    int? xpEarned,
    int? coinsEarned,
    int? correctCount,
    int? mistakeCount,
    Map<String, int>? vocabDeltas,
    int? consecutiveFastAnswers,
    bool? speedAchieved,
    bool? isComplete,
    bool? failed,
    DateTime? questionStartedAt,
    LessonCompletionResult? result,
    bool? funLeveledUp,
    bool? dailyChallengeJustCompleted,
    RecallChallenge? pendingRecall,
    bool clearPendingRecall = false,
    int? recallAttempts,
  }) {
    return FallingWordSessionState(
      mode: mode,
      levelConfig: levelConfig,
      questions: questions,
      currentIndex: currentIndex ?? this.currentIndex,
      lives: lives ?? this.lives,
      combo: combo ?? this.combo,
      bestCombo: bestCombo ?? this.bestCombo,
      xpEarned: xpEarned ?? this.xpEarned,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      correctCount: correctCount ?? this.correctCount,
      mistakeCount: mistakeCount ?? this.mistakeCount,
      vocabDeltas: vocabDeltas ?? this.vocabDeltas,
      consecutiveFastAnswers: consecutiveFastAnswers ?? this.consecutiveFastAnswers,
      speedAchieved: speedAchieved ?? this.speedAchieved,
      isComplete: isComplete ?? this.isComplete,
      failed: failed ?? this.failed,
      questionStartedAt: questionStartedAt ?? this.questionStartedAt,
      roundStartedAt: roundStartedAt,
      result: result ?? this.result,
      funLeveledUp: funLeveledUp ?? this.funLeveledUp,
      dailyChallengeJustCompleted:
          dailyChallengeJustCompleted ?? this.dailyChallengeJustCompleted,
      pendingRecall: clearPendingRecall ? null : (pendingRecall ?? this.pendingRecall),
      recallAttempts: recallAttempts ?? this.recallAttempts,
    );
  }
}

/// Drives one round of Falling Words / Word Rush: each bubble tap (or
/// timeout) is resolved immediately for a correct answer. A wrong answer
/// blocks progress behind [pendingRecall] — the player must actively
/// recall the correct meaning (see [RecallInterstitial]) before the
/// round advances, rather than the round just moving on past a mistake.
/// Combo, lives, XP/coins and per-word mastery deltas are tracked here;
/// applying them to the shared [ProgressController]/[FunProgressController]
/// only happens once, in [finishAndApply].
class FallingWordSessionController extends Notifier<FallingWordSessionState?> {
  @override
  FallingWordSessionState? build() => null;

  void start({
    required FunGameMode mode,
    required List<FunQuestion> questions,
    required FunLevelConfig levelConfig,
  }) {
    final now = DateTime.now();
    state = FallingWordSessionState(
      mode: mode,
      levelConfig: levelConfig,
      questions: questions,
      currentIndex: 0,
      lives: levelConfig.maxLives,
      combo: 0,
      bestCombo: 0,
      xpEarned: 0,
      coinsEarned: 0,
      correctCount: 0,
      mistakeCount: 0,
      vocabDeltas: const {},
      consecutiveFastAnswers: 0,
      speedAchieved: false,
      isComplete: false,
      failed: false,
      questionStartedAt: now,
      roundStartedAt: now,
    );
  }

  /// Returns true if [selectedIndex] was the correct option.
  bool submitAnswer(int selectedIndex) {
    final s = state;
    if (s == null || s.isComplete || s.pendingRecall != null || s.currentQuestion == null) {
      return false;
    }
    final question = s.currentQuestion!;
    final correct = selectedIndex == question.correctIndex;
    _resolveAnswer(
      correct,
      userAnswer: selectedIndex >= 0 && selectedIndex < question.options.length
          ? question.options[selectedIndex]
          : null,
    );
    return correct;
  }

  /// The correct bubble reached the bottom of the screen untapped.
  void questionTimedOut() {
    final s = state;
    if (s == null || s.isComplete || s.pendingRecall != null || s.currentQuestion == null) {
      return;
    }
    _resolveAnswer(false, userAnswer: 'Time ran out');
  }

  void _resolveAnswer(bool correct, {String? userAnswer}) {
    final s = state!;
    final question = s.currentQuestion!;
    final responseMs = DateTime.now().difference(s.questionStartedAt).inMilliseconds;

    final vocabDeltas = Map<String, int>.from(s.vocabDeltas);
    vocabDeltas[question.vocabId] =
        (vocabDeltas[question.vocabId] ?? 0) + (correct ? 1 : -1);

    if (correct) {
      var combo = s.combo + 1;
      final bestCombo = combo > s.bestCombo ? combo : s.bestCombo;
      final multiplier = s.levelConfig.comboEnabled ? comboMultiplier(combo) : 1;
      var consecutiveFast = s.consecutiveFastAnswers;
      var speedAchieved = s.speedAchieved;
      if (responseMs < 2000) {
        consecutiveFast++;
        if (consecutiveFast >= 20) speedAchieved = true;
      } else {
        consecutiveFast = 0;
      }

      final nextIndex = s.currentIndex + 1;
      final isComplete = nextIndex >= s.questions.length;
      state = s.copyWith(
        currentIndex: isComplete ? s.currentIndex : nextIndex,
        combo: combo,
        bestCombo: bestCombo,
        xpEarned: s.xpEarned + 5 * multiplier,
        coinsEarned: s.coinsEarned + 2,
        correctCount: s.correctCount + 1,
        vocabDeltas: vocabDeltas,
        consecutiveFastAnswers: consecutiveFast,
        speedAchieved: speedAchieved,
        isComplete: isComplete,
        questionStartedAt: DateTime.now(),
      );
      return;
    }

    // Wrong: lives/combo/mistake bookkeeping happens now, but the round
    // doesn't advance until the player clears the recall challenge.
    final hasTextPrompt = question.promptText.isNotEmpty;
    state = s.copyWith(
      lives: (s.lives - 1).clamp(0, s.levelConfig.maxLives),
      combo: 0,
      mistakeCount: s.mistakeCount + 1,
      vocabDeltas: vocabDeltas,
      consecutiveFastAnswers: 0,
      questionStartedAt: DateTime.now(),
      pendingRecall: RecallChallenge(
        promptWord: hasTextPrompt ? question.promptText : (question.promptEmoji ?? question.correctAnswer),
        correctMeaning: question.correctAnswer,
        emoji: question.promptEmoji,
        userAnswer: userAnswer,
        listenText: question.learningLanguageText,
        ttsLocale: question.ttsLocale,
      ),
      recallAttempts: 0,
    );
  }

  /// The player typed a guess at the missed word's meaning.
  void submitRecallAnswer(String typed) {
    final s = state;
    if (s == null || s.pendingRecall == null) return;
    final correct =
        normalizeForMatch(typed) == normalizeForMatch(s.pendingRecall!.correctMeaning);
    if (correct) {
      _advanceAfterRecall();
    } else {
      state = s.copyWith(recallAttempts: s.recallAttempts + 1);
    }
  }

  /// The player acknowledged the revealed answer after exhausting their
  /// recall attempts.
  void acknowledgeRecall() {
    if (state?.pendingRecall == null) return;
    _advanceAfterRecall();
  }

  void _advanceAfterRecall() {
    final s = state!;
    final nextIndex = s.currentIndex + 1;
    final failed = s.lives <= 0;
    final isComplete = failed || nextIndex >= s.questions.length;
    state = s.copyWith(
      currentIndex: isComplete ? s.currentIndex : nextIndex,
      isComplete: isComplete,
      failed: failed,
      clearPendingRecall: true,
      recallAttempts: 0,
    );
  }

  /// Combo multiplier steps matching the 🔥5/10/20/30 escalation shown
  /// in the combo HUD.
  static int comboMultiplier(int combo) {
    if (combo >= 30) return 5;
    if (combo >= 20) return 4;
    if (combo >= 10) return 3;
    if (combo >= 5) return 2;
    return 1;
  }

  static int starsForAccuracy(double accuracy) {
    if (accuracy >= 0.95) return 3;
    if (accuracy >= 0.75) return 2;
    if (accuracy > 0) return 1;
    return 0;
  }

  LessonCompletionResult finishAndApply() {
    final s = state!;
    if (s.result != null) return s.result!;

    final result = ref.read(progressProvider.notifier).awardFunSession(
          xpEarned: s.xpEarned,
          coinsEarned: s.coinsEarned,
          vocabDeltas: s.vocabDeltas,
          isPerfectRound: s.isPerfectRound,
          isSpeedRound: s.speedAchieved,
        );

    final leveledUp = ref.read(funProgressProvider.notifier).recordRoundResult(
          mode: s.mode,
          accuracy: s.accuracy,
          comboAchieved: s.bestCombo,
          starsEarned: starsForAccuracy(s.accuracy),
        );

    final learnedToday = s.vocabDeltas.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet();
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

final fallingWordSessionProvider =
    NotifierProvider<FallingWordSessionController, FallingWordSessionState?>(
  FallingWordSessionController.new,
);

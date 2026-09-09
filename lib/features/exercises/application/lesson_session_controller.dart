import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/tts_locales.dart';
import '../../../core/utils/xp_utils.dart';
import '../../../data/models/course.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/last_activity.dart';
import '../../../data/models/lesson.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import 'exercise_labels.dart';
import 'exercise_validator.dart';
import 'lesson_attempt.dart';

enum ExerciseFeedback { none, correct, incorrect }

class LessonSessionState {
  final Course course;
  final int unitIndex; // -1 for a review session not tied to a unit
  final Lesson lesson;
  final bool isReviewSession;

  final List<Exercise> queue;
  final int totalUnique;
  final Set<String> completedUniqueIds;
  final Set<String> retriedIds;

  /// Exercises the learner explicitly gave up on. Counted as missed (so
  /// they surface in review and the mistake bank) but never re-queued —
  /// re-queuing a skip is exactly the trap skipping exists to break.
  final Set<String> skippedIds;

  /// Every graded answer, in the order it was given. Drives the results
  /// screen's per-question breakdown and the Review Mistakes list.
  final List<LessonAttempt> attempts;

  final int xpEarned;
  final int correctCount;
  final int incorrectCount;
  final int heartsLostThisSession;

  final ExerciseFeedback feedback;
  final bool? pendingCorrect;

  final bool isComplete;

  /// True when the session finished because the heart budget ran out
  /// rather than because every exercise was answered. Drives the "Out of
  /// hearts" results variant — there is no separate out-of-hearts screen,
  /// no timer and nothing to buy.
  final bool endedEarly;

  final DateTime startedAt;
  final LessonCompletionResult? result;

  const LessonSessionState({
    required this.course,
    required this.unitIndex,
    required this.lesson,
    required this.isReviewSession,
    required this.queue,
    required this.totalUnique,
    required this.completedUniqueIds,
    required this.retriedIds,
    this.skippedIds = const {},
    this.attempts = const [],
    required this.xpEarned,
    required this.correctCount,
    required this.incorrectCount,
    required this.heartsLostThisSession,
    required this.feedback,
    required this.pendingCorrect,
    required this.isComplete,
    this.endedEarly = false,
    required this.startedAt,
    required this.result,
  });

  Exercise get currentExercise => queue.first;
  double get progressRatio =>
      totalUnique == 0 ? 0 : completedUniqueIds.length / totalUnique;
  bool get isPerfect => retriedIds.isEmpty;

  /// One row per exercise — what the learner answered the first time
  /// they saw it. Retries are excluded, or every miss would read as
  /// correct simply because the session re-queues until it is.
  List<LessonAttempt> get firstAttempts => attempts.firstAttempts;

  /// The questions to review: first attempts that were wrong.
  List<LessonAttempt> get missedAttempts => attempts.missedAttempts;

  LessonSessionState copyWith({
    List<Exercise>? queue,
    Set<String>? completedUniqueIds,
    Set<String>? retriedIds,
    Set<String>? skippedIds,
    List<LessonAttempt>? attempts,
    int? xpEarned,
    int? correctCount,
    int? incorrectCount,
    int? heartsLostThisSession,
    ExerciseFeedback? feedback,
    bool? pendingCorrect,
    bool clearPendingCorrect = false,
    bool? isComplete,
    bool? endedEarly,
    LessonCompletionResult? result,
  }) {
    return LessonSessionState(
      course: course,
      unitIndex: unitIndex,
      lesson: lesson,
      isReviewSession: isReviewSession,
      queue: queue ?? this.queue,
      totalUnique: totalUnique,
      completedUniqueIds: completedUniqueIds ?? this.completedUniqueIds,
      retriedIds: retriedIds ?? this.retriedIds,
      skippedIds: skippedIds ?? this.skippedIds,
      attempts: attempts ?? this.attempts,
      xpEarned: xpEarned ?? this.xpEarned,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      heartsLostThisSession: heartsLostThisSession ?? this.heartsLostThisSession,
      feedback: feedback ?? this.feedback,
      pendingCorrect:
          clearPendingCorrect ? null : (pendingCorrect ?? this.pendingCorrect),
      isComplete: isComplete ?? this.isComplete,
      endedEarly: endedEarly ?? this.endedEarly,
      startedAt: startedAt,
      result: result ?? this.result,
    );
  }
}

/// Drives a single lesson (or mistake-review session) from first
/// exercise to completion: validates answers, tracks XP/accuracy,
/// re-queues missed exercises for retry within the same session, and
/// hands the final tally to [ProgressController] exactly once.
class LessonSessionController extends Notifier<LessonSessionState?> {
  @override
  LessonSessionState? build() => null;

  void start({
    required Course course,
    required int unitIndex,
    required Lesson lesson,
    bool isReviewSession = false,
  }) {
    // Hearts are this attempt's life budget, so every attempt starts with
    // a full one. That is what makes running out a "play again" moment
    // instead of a wait-or-pay wall.
    ref.read(progressProvider.notifier).refillHeartsForSession();

    // Remembered now, not at the end, so Home can offer to resume a
    // lesson that was walked away from. Review sessions are excluded:
    // "continue learning" should point at the course, not at a practice
    // detour.
    if (!isReviewSession) {
      ref.read(progressProvider.notifier).noteActivityStarted(
            LastActivity.pathLesson(
              at: DateTime.now(),
              courseId: course.id,
              lessonId: lesson.id,
              unitIndex: unitIndex,
              lessonIndex: _lessonIndexIn(course, unitIndex, lesson.id),
              title: lesson.title,
              subtitle: unitIndex >= 0 && unitIndex < course.units.length
                  ? course.units[unitIndex].title
                  : course.title,
            ),
          );
    }

    state = LessonSessionState(
      course: course,
      unitIndex: unitIndex,
      lesson: lesson,
      isReviewSession: isReviewSession,
      queue: List<Exercise>.from(lesson.exercises),
      totalUnique: lesson.exercises.length,
      completedUniqueIds: {},
      retriedIds: {},
      xpEarned: 0,
      correctCount: 0,
      incorrectCount: 0,
      heartsLostThisSession: 0,
      feedback: ExerciseFeedback.none,
      pendingCorrect: null,
      isComplete: false,
      startedAt: DateTime.now(),
      result: null,
    );
  }

  /// Where this lesson sits in its unit. -1 when it can't be located
  /// (a synthesized review lesson), which the Home card treats as
  /// "resolve it yourself" rather than trusting the stored position.
  static int _lessonIndexIn(Course course, int unitIndex, String lessonId) {
    if (unitIndex < 0 || unitIndex >= course.units.length) return -1;
    return course.units[unitIndex].lessons.indexWhere((l) => l.id == lessonId);
  }

  /// Builds the record of one graded answer. [attemptIndex] counts how
  /// many times this exercise has already been answered in this session,
  /// so the first sighting (index 0) is the one that scores.
  LessonAttempt _recordAttempt(
    LessonSessionState s,
    Exercise exercise,
    dynamic answer, {
    required bool wasCorrect,
  }) {
    return LessonAttempt(
      exerciseId: exercise.id,
      vocabId: exercise.vocabId,
      type: exercise.type,
      promptLabel: promptLabel(exercise),
      userAnswerLabel: userAnswerLabel(exercise, answer),
      correctLabel: correctAnswerLabel(exercise),
      correctMeaning: correctAnswerMeaning(exercise),
      wasCorrect: wasCorrect,
      attemptIndex: s.attempts.where((a) => a.exerciseId == exercise.id).length,
      spokenText: spokenTextFor(exercise),
      ttsLocale: ttsLocaleFor(exercise) ?? TtsLocales.forLanguageId(s.course.languageId),
    );
  }

  void submitAnswer(dynamic answer) {
    final s = state;
    if (s == null || s.feedback != ExerciseFeedback.none) return;

    final current = s.currentExercise;
    final correct = ExerciseValidator.isCorrect(current, answer);
    final attempt = _recordAttempt(s, current, answer, wasCorrect: correct);

    if (correct) {
      state = s.copyWith(
        attempts: [...s.attempts, attempt],
        correctCount: s.correctCount + 1,
        feedback: ExerciseFeedback.correct,
        pendingCorrect: true,
      );
    } else {
      ref.read(progressProvider.notifier).loseHeart();
      state = s.copyWith(
        attempts: [...s.attempts, attempt],
        incorrectCount: s.incorrectCount + 1,
        heartsLostThisSession: s.heartsLostThisSession + 1,
        retriedIds: {...s.retriedIds, current.id},
        feedback: ExerciseFeedback.incorrect,
        pendingCorrect: false,
      );
    }
  }

  /// Gives up on the current exercise and moves on permanently.
  ///
  /// Counted as missed so it reaches review and the mistake bank, but
  /// deliberately costs no heart: the escape hatch exists for a learner
  /// a recognizer or a device keeps failing, and charging them for that
  /// punishes a hardware problem.
  void skipCurrent() {
    final s = state;
    if (s == null || s.feedback != ExerciseFeedback.none) return;

    final current = s.currentExercise;
    state = s.copyWith(
      attempts: [
        ...s.attempts,
        _recordAttempt(s, current, 'Skipped', wasCorrect: false),
      ],
      incorrectCount: s.incorrectCount + 1,
      retriedIds: {...s.retriedIds, current.id},
      skippedIds: {...s.skippedIds, current.id},
      feedback: ExerciseFeedback.incorrect,
      pendingCorrect: false,
    );
  }

  void continueToNext() {
    final s = state;
    if (s == null || s.feedback == ExerciseFeedback.none) return;

    final queue = List<Exercise>.from(s.queue);
    final current = queue.removeAt(0);

    Set<String> completedUniqueIds = s.completedUniqueIds;
    int xpEarned = s.xpEarned;

    if (s.pendingCorrect == true) {
      final wasRetry = s.retriedIds.contains(current.id);
      xpEarned += XpUtils.xpForAnswer(isRetry: wasRetry);
      completedUniqueIds = {...completedUniqueIds, current.id};
    } else if (s.skippedIds.contains(current.id)) {
      // Consumed without XP: the learner moves on, and the exercise
      // still counts toward progress so the session can actually end.
      completedUniqueIds = {...completedUniqueIds, current.id};
    } else {
      final insertAt = queue.isEmpty ? 0 : min(1, queue.length);
      queue.insert(insertAt, current);
    }

    // Out of hearts ends this attempt here, rather than pushing a
    // separate "you're out of hearts" screen after every remaining
    // answer. The learner lands on the results screen with their
    // mistakes to review and a Play again button.
    final outOfHearts = ref.read(progressProvider).hearts <= 0;

    state = s.copyWith(
      queue: queue,
      completedUniqueIds: completedUniqueIds,
      xpEarned: xpEarned,
      feedback: ExerciseFeedback.none,
      clearPendingCorrect: true,
      isComplete: queue.isEmpty || outOfHearts,
      endedEarly: queue.isNotEmpty && outOfHearts,
    );
  }

  LessonCompletionResult finishAndApply() {
    final s = state;
    if (s == null) {
      throw StateError('No active lesson session');
    }
    if (s.result != null) return s.result!;

    final timeSpent = DateTime.now().difference(s.startedAt).inSeconds;
    final result = ref.read(progressProvider.notifier).completeLessonSession(
          course: s.course,
          unitIndex: s.unitIndex,
          lesson: s.lesson,
          xpEarned: s.xpEarned,
          isPerfect: s.isPerfect,
          timeSpentSeconds: timeSpent,
          mistakenExerciseIds: s.retriedIds,
          isReviewSession: s.isReviewSession,
          // An attempt that ran out of hearts still earns the XP and the
          // mastery/mistake updates it genuinely produced, but it does
          // not mark the lesson complete or unlock what comes next —
          // the learner didn't finish it.
          countsAsLessonCompletion: !s.endedEarly,
        );

    state = s.copyWith(result: result);
    return result;
  }

  void reset() {
    state = null;
  }
}

final lessonSessionProvider =
    NotifierProvider<LessonSessionController, LessonSessionState?>(
  LessonSessionController.new,
);

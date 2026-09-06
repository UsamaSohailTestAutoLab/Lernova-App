import '../../../core/constants/app_enums.dart';

/// One answer the learner actually gave, captured at the moment it was
/// graded.
///
/// Stores *rendered display strings* rather than a reference back to the
/// exercise: by the time a review screen reads this, the session's queue
/// has moved on, and an exercise may even have been re-asked in a
/// different generated form. What the learner needs to see is what they
/// were shown and what they typed/tapped at the time.
class LessonAttempt {
  final String exerciseId;
  final String vocabId;
  final ExerciseType type;

  /// The learning-language word or phrase this question was about, if it
  /// has one — this is what a Listen button on a review row speaks.
  final String? spokenText;
  final String ttsLocale;

  final String promptLabel;
  final String userAnswerLabel;
  final String correctLabel;
  final bool wasCorrect;

  /// 0 for the learner's first sighting of this exercise in the session;
  /// higher for the retries a miss re-queues.
  final int attemptIndex;

  const LessonAttempt({
    required this.exerciseId,
    required this.vocabId,
    required this.type,
    required this.promptLabel,
    required this.userAnswerLabel,
    required this.correctLabel,
    required this.wasCorrect,
    required this.attemptIndex,
    this.spokenText,
    this.ttsLocale = 'es-ES',
  });
}

extension LessonAttemptList on List<LessonAttempt> {
  /// One row per exercise: the learner's *first* answer to it. Scoring a
  /// lesson on retries would mark every miss correct simply because the
  /// session re-queues until it's right.
  List<LessonAttempt> get firstAttempts =>
      where((a) => a.attemptIndex == 0).toList();

  /// The first attempts that were wrong — the review list.
  List<LessonAttempt> get missedAttempts =>
      firstAttempts.where((a) => !a.wasCorrect).toList();
}

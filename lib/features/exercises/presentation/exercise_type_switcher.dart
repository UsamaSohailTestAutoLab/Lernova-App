import 'package:flutter/material.dart';

import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';
import 'fill_in_blank_exercise.dart';
import 'image_recognition_exercise.dart';
import 'listening_exercise.dart';
import 'multiple_choice_exercise.dart';
import 'sentence_arrangement_exercise.dart';
import 'speaking_exercise.dart';
import 'translation_exercise.dart';
import 'word_matching_exercise.dart';

/// Dispatches to the concrete widget for the current exercise's type.
/// Exhaustive over [ExercisePayload]'s sealed subtypes, so adding a new
/// exercise type is a compile error here until it's handled.
class ExerciseTypeSwitcher extends StatelessWidget {
  final Exercise exercise;
  final ExerciseFeedback feedback;
  final ValueChanged<dynamic> onAnswer;

  /// Gives up on the current exercise. Only exercise types that can
  /// genuinely strand a learner (currently speaking, which depends on a
  /// speech recognizer that may simply never cooperate) offer this.
  final VoidCallback? onSkip;

  const ExerciseTypeSwitcher({
    super.key,
    required this.exercise,
    required this.feedback,
    required this.onAnswer,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final payload = exercise.payload;
    return switch (payload) {
      MultipleChoicePayload p => MultipleChoiceExercise(
          payload: p,
          feedback: feedback,
          onSelect: onAnswer,
        ),
      TranslationPayload p => TranslationExercise(
          payload: p,
          feedback: feedback,
          onSubmit: onAnswer,
        ),
      ListeningPayload p => ListeningExercise(
          payload: p,
          feedback: feedback,
          onSelect: onAnswer,
        ),
      SpeakingPayload p => SpeakingExercise(
          payload: p,
          feedback: feedback,
          onSubmit: onAnswer,
          onSkip: onSkip,
        ),
      WordMatchingPayload p => WordMatchingExercise(
          payload: p,
          feedback: feedback,
          onComplete: onAnswer,
        ),
      SentenceArrangementPayload p => SentenceArrangementExercise(
          payload: p,
          feedback: feedback,
          onSubmit: onAnswer,
        ),
      FillInTheBlankPayload p => FillInBlankExercise(
          payload: p,
          feedback: feedback,
          onSelect: onAnswer,
        ),
      ImageRecognitionPayload p => ImageRecognitionExercise(
          payload: p,
          feedback: feedback,
          onSubmit: onAnswer,
        ),
    };
  }
}

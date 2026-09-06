import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/type_answer_field.dart';
import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';

class TranslationExercise extends StatelessWidget {
  final TranslationPayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<String> onSubmit;

  const TranslationExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(payload.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            payload.sourceText,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TypeAnswerField(
          hintText: 'Type the answer in ${payload.answerLanguage}',
          feedback: switch (feedback) {
            ExerciseFeedback.none => TypeAnswerFeedback.none,
            ExerciseFeedback.correct => TypeAnswerFeedback.correct,
            ExerciseFeedback.incorrect => TypeAnswerFeedback.incorrect,
          },
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

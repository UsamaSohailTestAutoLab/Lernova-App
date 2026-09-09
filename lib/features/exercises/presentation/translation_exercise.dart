import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(payload.prompt, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        // The phrase being translated is the subject of the screen, so
        // it gets the full width and a card of its own. It used to sit
        // in a small grey box shrink-wrapped to the text and pinned to
        // the left margin, which read as a label rather than the thing
        // the question is about.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: context.decor.tint(AppColors.primary),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Text(
            payload.sourceText,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        // The input disappears once the answer is graded. Left in place
        // it was a dead box — untypable, and holding a copy of an answer
        // the feedback bar below is already stating. Nothing to read,
        // nothing to do.
        if (feedback == ExerciseFeedback.none) ...[
          const SizedBox(height: AppSpacing.xl),
          TypeAnswerField(
            hintText: 'Type the answer in ${payload.answerLanguage}',
            feedback: TypeAnswerFeedback.none,
            onSubmit: onSubmit,
          ),
        ],
      ],
    );
  }
}

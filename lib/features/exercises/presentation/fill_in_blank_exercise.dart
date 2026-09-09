import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';
import 'widgets/option_choice_list.dart';

class FillInBlankExercise extends StatelessWidget {
  final FillInTheBlankPayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<String> onSelect;

  const FillInBlankExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final correctIndex = payload.options.indexOf(payload.correctAnswer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose the missing word to complete the sentence',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payload.sentenceTemplate,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              // The English under it. A Spanish sentence with a hole in
              // it is unanswerable if you can't read the rest of it —
              // the meaning was only ever shown *after* getting it wrong.
              if (payload.translation != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  payload.translation!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OptionChoiceList(
          options: payload.options,
          correctIndex: correctIndex,
          feedback: feedback,
          onSelect: (i) => onSelect(payload.options[i]),
        ),
      ],
    );
  }
}

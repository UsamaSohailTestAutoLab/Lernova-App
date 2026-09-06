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
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            payload.sentenceTemplate,
            style: Theme.of(context).textTheme.titleLarge,
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

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';
import 'widgets/option_choice_list.dart';

class MultipleChoiceExercise extends StatelessWidget {
  final MultipleChoicePayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<int> onSelect;

  const MultipleChoiceExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(payload.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        OptionChoiceList(
          options: payload.options,
          correctIndex: payload.correctIndex,
          feedback: feedback,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

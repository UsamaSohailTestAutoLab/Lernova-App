import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../application/lesson_session_controller.dart';

/// Slides up from the bottom after every answer — mirrors the
/// "immediate feedback" beat that makes short-form lesson apps feel
/// responsive. Correct = green, incorrect = coral with the right answer
/// shown, both ending in a single "Continue" CTA.
class AnswerFeedbackBar extends StatelessWidget {
  final ExerciseFeedback feedback;
  final String? correctAnswerLabel;
  final VoidCallback onContinue;

  const AnswerFeedbackBar({
    super.key,
    required this.feedback,
    this.correctAnswerLabel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    if (feedback == ExerciseFeedback.none) return const SizedBox.shrink();

    final isCorrect = feedback == ExerciseFeedback.correct;
    final color = isCorrect ? AppColors.success : AppColors.error;
    final bg = isCorrect ? AppColors.successLight : AppColors.errorLight;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: Offset.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(color: bg),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isCorrect ? 'Nice!' : 'Not quite',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color),
                  ),
                ],
              ),
              if (!isCorrect && correctAnswerLabel != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Correct answer: $correctAnswerLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Continue',
                backgroundColor: color,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

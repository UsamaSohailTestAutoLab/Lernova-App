import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decor.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../application/exercise_labels.dart';
import '../../application/lesson_session_controller.dart';

/// Slides up from the bottom after every answer — mirrors the
/// "immediate feedback" beat that makes short-form lesson apps feel
/// responsive. Correct = green, incorrect = coral with the right answer
/// shown, both ending in a single "Continue" CTA.
class AnswerFeedbackBar extends StatelessWidget {
  final ExerciseFeedback feedback;
  final String? correctAnswerLabel;

  /// What [correctAnswerLabel] means in English, when the answer itself
  /// is in the language being learned. Shown under it so a miss teaches
  /// the meaning and not just the spelling.
  final AnswerMeaning? correctAnswerMeaning;

  final VoidCallback onContinue;

  const AnswerFeedbackBar({
    super.key,
    required this.feedback,
    this.correctAnswerLabel,
    this.correctAnswerMeaning,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    if (feedback == ExerciseFeedback.none) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isCorrect = feedback == ExerciseFeedback.correct;
    final color = isCorrect ? AppColors.success : AppColors.error;
    // decor.tint() rather than the raw successLight/errorLight literals:
    // those are pale washes for light mode that the theme's near-white
    // dark-mode text is close to invisible against.
    final bg = context.decor.tint(color);

    return TweenAnimationBuilder<double>(
      key: ValueKey(isCorrect),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        // Rises from the bottom edge, so the verdict reads as a reply to
        // the tap rather than a panel that was always there.
        offset: Offset(0, 40 * (1 - t)),
        child: Opacity(opacity: t, child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          // A lip along the top edge and a shadow above it lift the bar
          // off the question instead of butting flat against it.
          border: Border(top: BorderSide(color: color, width: 3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(
                      isCorrect ? Icons.check_rounded : Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isCorrect ? 'Nice!' : 'Not quite',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (!isCorrect && correctAnswerLabel != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Correct answer: $correctAnswerLabel',
                  // Body ink on the tinted ground, not the accent colour
                  // on its own wash — that pairing was the hard-to-read
                  // one, and it's the line that matters most here.
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.onSurface),
                ),
                if (correctAnswerMeaning != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${correctAnswerMeaning!.label}: ${correctAnswerMeaning!.text}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
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

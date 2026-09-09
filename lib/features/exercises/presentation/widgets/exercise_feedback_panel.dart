import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decor.dart';
import '../../../../core/theme/app_spacing.dart';

/// In-question feedback: "Not quite", "That's it".
///
/// Replaces a flat pale-pink box that read as a footnote rather than a
/// verdict — and, being a raw `errorLight` literal, was close to
/// unreadable in dark mode. This gives the message a solid header band
/// and a raised edge so it registers as a response, on a surface the
/// theme's own text colours are legible against in both themes.
///
/// Deliberately not a modal: the question and the options stay visible
/// behind it, because the point of the feedback is to be read *against*
/// the answer that prompted it.
class ExerciseFeedbackPanel extends StatelessWidget {
  final bool isCorrect;
  final String title;
  final String message;

  /// What to do next, when that isn't obvious from the message.
  final String? hint;

  const ExerciseFeedbackPanel({
    super.key,
    required this.isCorrect,
    required this.title,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isCorrect ? AppColors.success : AppColors.error;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        // Rises into place rather than appearing — a verdict that slides
        // in reads as a reply to what you just did.
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: accent,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    // Body ink on the plain surface, not tinted red on a
                    // red wash — that combination was the unreadable part.
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hint!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "you got it" banner shown between an exercise's stages.
class ExerciseSuccessBanner extends StatelessWidget {
  final String message;
  const ExerciseSuccessBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.decor.tint(AppColors.success),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

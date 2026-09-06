import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/recall_challenge.dart';

/// The wrong-answer feedback for the *catching* games: a strip along the
/// bottom of the playfield naming the correct word, with the player's
/// pick underneath and a Listen button.
///
/// It replaces the full-screen recall interstitial in these modes. That
/// card asked the player to type the meaning before the round would move
/// on, which in a fast catching game interrupted play on every single
/// miss. Here the board stays on screen, the answer is readable in place,
/// and the round carries on by itself — [onNext] only skips the wait.
class MissBanner extends ConsumerWidget {
  final RecallChallenge challenge;
  final VoidCallback onNext;

  const MissBanner({super.key, required this.challenge, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listenText = challenge.listenText;
    final userAnswer = challenge.userAnswer;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      shadowColor: AppColors.primary.withValues(alpha: 0.25),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          border: Border(top: BorderSide(color: AppColors.error, width: 3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Correct answer',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        '${challenge.promptWord} = ${challenge.correctMeaning}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (listenText != null && listenText.isNotEmpty)
                  IconButton.filledTonal(
                    onPressed: () => ref
                        .read(ttsServiceProvider)
                        .speak(listenText, locale: challenge.ttsLocale),
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: 'Listen',
                  ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filled(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'Next',
                ),
              ],
            ),
            if (userAnswer != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'You picked: $userAnswer',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

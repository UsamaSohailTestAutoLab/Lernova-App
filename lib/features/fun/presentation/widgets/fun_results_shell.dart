import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decor.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/lernova_parrot.dart';

/// One stat shown in a [FunResultsShell]'s stat row.
class FunResultStat {
  final String label;
  final String value;
  final Color color;
  const FunResultStat({required this.label, required this.value, required this.color});
}

/// Shared "round results" chrome — mascot, headline, stat row, optional
/// speed/daily-challenge/missed-words callouts, and primary/secondary
/// actions — reused by every Fun game mode's results screen so each one
/// doesn't reimplement the same layout from scratch. [FunRoundResultsScreen]
/// (Falling Words/Word Rush/Listen & Catch/Meaning Shooter/Phrase
/// Builder/Country Challenge) predates this and isn't rebuilt on top of
/// it to avoid churning a screen that already works; every mode added
/// after it uses this shell directly.
class FunResultsShell extends StatelessWidget {
  final bool success;
  final bool leveledUp;
  final List<FunResultStat> stats;
  final bool speedAchieved;
  final bool dailyChallengeJustCompleted;
  final int missedCount;
  final String missedLabel;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback onDone;
  final ConfettiController? confettiController;

  const FunResultsShell({
    super.key,
    required this.success,
    required this.leveledUp,
    required this.stats,
    this.speedAchieved = false,
    this.dailyChallengeJustCompleted = false,
    this.missedCount = 0,
    this.missedLabel = 'words',
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    required this.onDone,
    this.confettiController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Spacer(),
                  // The same parrot that opens a level, so finishing one
                  // and starting one read as the same app.
                  LernovaParrot(
                    size: 130,
                    mood: success ? LernovaParrotMood.celebrate : LernovaParrotMood.sad,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    success ? 'Level Complete! 🎉' : 'Almost there! 💪',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (success && leveledUp) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "You've leveled up!",
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.accent),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.md,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final stat in stats)
                        Column(
                          children: [
                            Text(
                              stat.value,
                              style: theme.textTheme.headlineSmall?.copyWith(color: stat.color),
                            ),
                            Text(stat.label, style: theme.textTheme.bodySmall),
                          ],
                        ),
                    ],
                  ),
                  if (speedAchieved) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('⚡ Speed Learner bonus!', style: theme.textTheme.bodyMedium),
                  ],
                  if (dailyChallengeJustCompleted) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        // tint(), not the raw successLight literal, which
                        // is a pale mint that light text vanishes into in
                        // dark mode.
                        color: context.decor.tint(AppColors.success),
                        borderRadius: BorderRadius.circular(AppSpacing.xl),
                      ),
                      child: Text(
                        'Daily Challenge Complete! 🎉',
                        style: theme.textTheme.titleSmall?.copyWith(color: AppColors.success),
                      ),
                    ),
                  ],
                  if (missedCount > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      "Let's practice $missedCount missed $missedLabel",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const Spacer(),
                  PrimaryButton(label: primaryLabel, onPressed: onPrimary),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(label: secondaryLabel!, onPressed: onSecondary),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppTextButton(label: 'Back to Fun Zone', onPressed: onDone),
                ],
              ),
            ),
          ),
          if (confettiController != null)
            ConfettiWidget(
              confettiController: confettiController!,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              maxBlastForce: 18,
              minBlastForce: 6,
              gravity: 0.25,
              colors: const [
                AppColors.primary,
                AppColors.accent,
                AppColors.success,
                AppColors.gem,
              ],
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';

/// Covers the playfield while a timed round is paused.
///
/// The catching games run on a clock, so "put the phone down for a
/// second" previously meant losing the question. This freezes the timer
/// and blocks taps until the player chooses to come back.
class PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;

  const PauseOverlay({super.key, required this.onResume, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      // Swallows every tap underneath, so a paused board can't be played.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: AppColors.primaryDark.withValues(alpha: 0.55),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.xl),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pause_circle_filled_rounded,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text('Paused', style: theme.textTheme.displaySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The timer is stopped. Take your time.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(label: 'Resume', onPressed: onResume),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(label: 'Quit round', onPressed: onQuit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

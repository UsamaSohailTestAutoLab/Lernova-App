import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../../progress/application/progress_controller.dart';

/// Pro unlocks *content*, and nothing else. Hearts are deliberately not
/// on this list: they refill at the start of every lesson for everyone,
/// so there is no restriction here to sell relief from.
const _perks = [
  ('Every level on the Path', Icons.route_rounded),
  ('Every Fun Zone game and level', Icons.sports_esports_rounded),
  ('No ads', Icons.block_rounded),
  ('Offline-ready lessons', Icons.cloud_off_rounded),
  ('Exclusive mascot outfits', Icons.auto_awesome_rounded),
];

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const LernovaParrot(size: 110, mood: LernovaParrotMood.celebrate),
              const SizedBox(height: AppSpacing.lg),
              Text('Lernova Premium', style: theme.textTheme.displayMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Learn without limits.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final perk in _perks)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(perk.$2, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.md),
                      Text(perk.$1, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
              const Spacer(),
              if (progress.isPremium)
                Column(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: AppColors.accent, size: 40),
                    const SizedBox(height: AppSpacing.sm),
                    Text("You're a Premium member", style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Cancel Premium',
                      onPressed: () {
                        ref.read(progressProvider.notifier).setPremium(false);
                        AppSnackBar.show(context, 'Premium cancelled');
                      },
                    ),
                  ],
                )
              else
                PrimaryButton(
                  label: 'Start Premium — mock purchase',
                  onPressed: () {
                    ref.read(progressProvider.notifier).setPremium(true);
                    AppSnackBar.show(context, 'Welcome to Premium!');
                    context.pop();
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Demo app — no real payment is processed.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/lingoquest_parrot.dart';
import '../../access/application/entitlements.dart';
import '../../onboarding/application/user_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../application/fun_game_nav_args.dart';
import '../application/fun_progress_controller.dart';
import 'widgets/daily_challenge_card.dart';
import 'widgets/game_mode_card.dart';

class FunHubScreen extends ConsumerWidget {
  const FunHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final funProgress = ref.watch(funProgressProvider);
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    final overallLevel = FunGameMode.values
        .where((m) => m.isImplemented)
        .map((m) => funProgress.levelFor(m.name))
        .fold(1, (a, b) => a > b ? a : b);

    return Scaffold(
      // Transparent so the shell's textured backdrop shows through.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Fun Zone'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Mirrors Home's greeting card so the parrot reads as one
          // consistent mascot rather than a different face per tab.
          AppCard(
            variant: AppCardVariant.tinted,
            tint: AppColors.primary,
            child: Row(
              children: [
                const LingoQuestParrot(size: 64, mood: LingoQuestParrotMood.curious),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Fun Level $overallLevel', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Play a quick game and pick up new words along the way.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DailyChallengeCard(funProgress: funProgress),
          const SizedBox(height: AppSpacing.lg),
          Text('Games', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.95,
            children: [
              for (final mode in FunGameMode.values)
                Builder(
                  builder: (context) {
                    final level = funProgress.levelFor(mode.name);
                    final requiresPro = Entitlements.resolveFunAccess(
                          mode: mode,
                          level: level,
                          progress: progress,
                        ) ==
                        FunAccess.requiresPro;

                    return GameModeCard(
                      mode: mode,
                      level: level,
                      // Not `overallLevel >= mode.unlockLevel`: that
                      // ladder does not apply to a member, and applying
                      // it anyway left paid accounts with eight of ten
                      // games locked.
                      unlocked: Entitlements.isFunModeUnlockedByLevel(
                        mode: mode,
                        overallLevel: overallLevel,
                        progress: progress,
                      ),
                      requiresPro: requiresPro,
                      onTap: user.selectedLanguageId == null
                          ? null
                          // A Pro card is tappable on purpose. The whole
                          // grid being dead to the touch reads as a
                          // broken screen; opening the paywall at least
                          // answers why it is locked.
                          : requiresPro
                              ? () => context.push(AppRoutes.premium)
                              : () => context.push(
                                    AppRoutes.funGameIntro,
                                    extra: FunGameNavArgs(mode: mode),
                                  ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

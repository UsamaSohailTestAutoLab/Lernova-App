import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/xp_utils.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/gamification_indicators.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../application/lesson_flow_nav.dart';

class XpRewardScreen extends ConsumerWidget {
  const XpRewardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(lessonSessionProvider);
    final theme = Theme.of(context);

    if (session == null || session.result == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final result = session.result!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.bolt_rounded, size: 72, color: AppColors.accent),
              const SizedBox(height: AppSpacing.lg),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: result.xpEarned),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  '+$value XP',
                  style: theme.textTheme.displayLarge?.copyWith(color: AppColors.accent),
                ),
              ),
              if (result.gemsEarned > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('+${result.gemsEarned} gems earned', style: theme.textTheme.titleMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (result.leveledUp) ...[
                Text('Level up! You reached level ${result.newLevel}',
                    style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
              ],
              ProgressRing(
                progress: XpUtils.levelProgress(result.newTotalXp),
                size: 96,
                color: AppColors.primary,
                trackColor: theme.colorScheme.surfaceContainerHighest,
                center: Text(
                  'Lv ${result.newLevel}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  final next = nextResultRoute(result, afterThis: AppRoutes.xpReward);
                  if (next == AppRoutes.home) {
                    finishLessonFlow(ref, context);
                  } else {
                    context.pushReplacement(next);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

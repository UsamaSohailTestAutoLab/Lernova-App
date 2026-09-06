import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selectable_tile.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_step_scaffold.dart';

class DailyGoalSelectionScreen extends ConsumerWidget {
  const DailyGoalSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selections = ref.watch(onboardingProvider);

    return OnboardingStepScaffold(
      stepProgress: 0.6,
      title: 'Set your daily XP goal',
      subtitle: 'You can always change this later in Settings.',
      ctaLabel: 'Continue',
      onCta: () => context.push(AppRoutes.placement),
      content: Column(
        children: [
          for (final goal in DailyGoalXp.values) ...[
            SelectableTile(
              title: '${goal.xp} XP / day',
              subtitle: goal.label,
              leading: Icon(Icons.bolt_rounded, color: Colors.amber.shade700),
              selected: selections.dailyGoal == goal,
              onTap: () => ref.read(onboardingProvider.notifier).setDailyGoal(goal),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

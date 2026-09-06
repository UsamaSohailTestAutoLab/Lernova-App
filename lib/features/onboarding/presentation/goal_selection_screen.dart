import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selectable_tile.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_step_scaffold.dart';

const _goalCopy = {
  LearningGoal.casual: (
    'Casual',
    'A few minutes here and there',
    Icons.self_improvement_rounded,
  ),
  LearningGoal.regular: (
    'Regular',
    'Build a steady habit',
    Icons.directions_walk_rounded,
  ),
  LearningGoal.serious: (
    'Serious',
    'Make fast, real progress',
    Icons.directions_run_rounded,
  ),
  LearningGoal.intense: (
    'Intense',
    'Go all in every day',
    Icons.bolt_rounded,
  ),
};

class GoalSelectionScreen extends ConsumerWidget {
  const GoalSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selections = ref.watch(onboardingProvider);

    return OnboardingStepScaffold(
      stepProgress: 0.4,
      title: 'How much time can you give?',
      subtitle: "We'll shape your daily goal around this.",
      ctaLabel: 'Continue',
      onCta: () => context.push(AppRoutes.dailyGoalSelection),
      content: Column(
        children: [
          for (final goal in LearningGoal.values) ...[
            SelectableTile(
              title: _goalCopy[goal]!.$1,
              subtitle: _goalCopy[goal]!.$2,
              leading: Icon(_goalCopy[goal]!.$3),
              selected: selections.learningGoal == goal,
              onTap: () =>
                  ref.read(onboardingProvider.notifier).setLearningGoal(goal),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

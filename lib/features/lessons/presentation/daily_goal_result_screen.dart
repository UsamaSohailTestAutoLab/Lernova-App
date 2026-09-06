import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../application/lesson_flow_nav.dart';

class DailyGoalResultScreen extends ConsumerWidget {
  const DailyGoalResultScreen({super.key});

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
              const Icon(Icons.flag_circle_rounded, size: 96, color: AppColors.success),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Daily goal reached!',
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "You hit today's XP goal. Come back tomorrow to keep the streak alive.",
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  final next =
                      nextResultRoute(result, afterThis: AppRoutes.dailyGoalResult);
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

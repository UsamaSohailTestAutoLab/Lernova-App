import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../application/lesson_flow_nav.dart';

class StreakResultScreen extends ConsumerWidget {
  const StreakResultScreen({super.key});

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
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 96,
                  color: AppColors.streak,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${result.newStreakCount}-day streak!',
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "You're on fire. Keep it going tomorrow.",
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  final next =
                      nextResultRoute(result, afterThis: AppRoutes.streakResult);
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

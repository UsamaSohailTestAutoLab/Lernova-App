import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/icon_mapper.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/models/achievement.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../application/lesson_flow_nav.dart';

class AchievementUnlockScreen extends ConsumerWidget {
  const AchievementUnlockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(lessonSessionProvider);
    final theme = Theme.of(context);
    if (session == null || session.result == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final unlocked = achievementCatalog
        .where((a) => session.result!.newAchievements.contains(a.id))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Text(
                unlocked.length > 1 ? 'Achievements unlocked!' : 'Achievement unlocked!',
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final achievement in unlocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(achievementIconFor(achievement.icon), color: AppColors.accent, size: 32),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(achievement.title, style: theme.textTheme.titleMedium),
                              Text(achievement.description, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () => finishLessonFlow(ref, context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

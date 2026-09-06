import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/xp_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../application/progress_controller.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    final strengths = progress.vocabStrength.values;
    final mastered = strengths.where((s) => s >= 4).length;
    final learning = strengths.where((s) => s >= 0 && s < 4).length;
    final weak = strengths.where((s) => s < 0).length;
    final totalWords = strengths.length;

    final hours = progress.totalTimeSpentSeconds ~/ 3600;
    final minutes = (progress.totalTimeSpentSeconds % 3600) ~/ 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.6,
            children: [
              StatCard(
                icon: Icons.military_tech_rounded,
                emoji: '🎖️',
                color: AppColors.primary,
                label: 'Level',
                value: '${XpUtils.levelForXp(progress.totalXp)}',
              ),
              StatCard(
                icon: Icons.bolt_rounded,
                emoji: '⭐',
                color: AppColors.accent,
                label: 'Total XP',
                value: '${progress.totalXp}',
              ),
              StatCard(
                icon: Icons.local_fire_department_rounded,
                emoji: '🔥',
                color: AppColors.streak,
                label: 'Day streak',
                value: '${progress.streakCount}',
              ),
              StatCard(
                icon: Icons.checklist_rounded,
                emoji: '🛤️',
                color: AppColors.success,
                label: 'Lessons done',
                value: '${progress.totalLessonsCompleted}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This week', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _WeekStreakRow(streakCount: progress.streakCount),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vocabulary ($totalWords words touched)',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                if (totalWords == 0)
                  Text('Play a lesson to start building your vocabulary.',
                      style: theme.textTheme.bodyMedium)
                else ...[
                  _VocabBar(mastered: mastered, learning: learning, weak: weak),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Legend(color: AppColors.success, label: 'Mastered $mastered'),
                      _Legend(color: AppColors.accent, label: 'Learning $learning'),
                      _Legend(color: AppColors.error, label: 'Weak $weak'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.info),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Total time learning: ${hours}h ${minutes}m',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStreakRow extends StatelessWidget {
  final int streakCount;
  const _WeekStreakRow({required this.streakCount});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday; // 1..7
    final activeDays = streakCount.clamp(0, 7);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayNumber = i + 1;
        final distanceFromToday = today - dayNumber;
        final isActive = distanceFromToday >= 0 && distanceFromToday < activeDays;
        return Column(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: isActive ? AppColors.streak : Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 4),
            Text(_labels[i], style: Theme.of(context).textTheme.labelSmall),
          ],
        );
      }),
    );
  }
}

class _VocabBar extends StatelessWidget {
  final int mastered;
  final int learning;
  final int weak;
  const _VocabBar({required this.mastered, required this.learning, required this.weak});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            Expanded(flex: mastered, child: Container(color: AppColors.success)),
            Expanded(flex: learning, child: Container(color: AppColors.accent)),
            Expanded(flex: weak, child: Container(color: AppColors.error)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/icon_mapper.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/fun/phrase.dart';
import '../../../data/models/user_progress.dart';
import '../../progress/application/progress_controller.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  int _currentValue(Achievement a, UserProgress progress) {
    switch (a.id) {
      case AchievementId.firstLesson:
      case AchievementId.perfectLesson:
      case AchievementId.unitComplete:
      case AchievementId.courseComplete:
      case AchievementId.speedLearner:
      case AchievementId.perfectRound:
        return progress.unlockedAchievementIds.contains(a.id.name) ? 1 : 0;
      case AchievementId.streak3:
      case AchievementId.streak7:
      case AchievementId.streak30:
        return progress.streakCount;
      case AchievementId.xp100:
      case AchievementId.xp500:
      case AchievementId.xp1000:
        return progress.totalXp;
      case AchievementId.fiveLessonsInADay:
        return progress.lessonsCompletedToday;
      case AchievementId.wordMaster:
        return progress.vocabStrength.entries
            .where((e) => e.value >= 1 && !e.key.contains(Phrase.idMarker))
            .length;
      case AchievementId.phraseMaster:
        return progress.vocabStrength.entries
            .where((e) => e.value >= 1 && e.key.contains(Phrase.idMarker))
            .length;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.92,
        ),
        itemCount: achievementCatalog.length,
        itemBuilder: (context, i) {
          final achievement = achievementCatalog[i];
          final unlocked = progress.unlockedAchievementIds.contains(achievement.id.name);
          final current = _currentValue(achievement, progress).clamp(0, achievement.target);
          final ratio = achievement.target == 0 ? 1.0 : current / achievement.target;

          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.accentLight
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  achievementIconFor(achievement.icon),
                  size: 32,
                  color: unlocked ? AppColors.accent : theme.colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(achievement.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Expanded(
                  child: Text(
                    achievement.description,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.fade,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xl),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 6,
                    color: unlocked ? AppColors.accent : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked ? 'Unlocked' : '$current / ${achievement.target}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

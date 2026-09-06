import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/fun_daily_challenge_logic.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/gamification_indicators.dart';
import '../../../../data/models/fun_progress.dart';

class DailyChallengeCard extends StatelessWidget {
  final FunProgress funProgress;

  const DailyChallengeCard({super.key, required this.funProgress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordsLearned = funProgress.dailyChallengeWordIds.length;
    final target = FunDailyChallengeLogic.targetWordCount;
    final complete = funProgress.dailyChallengeCompletedToday;

    return AppCard(
      color: complete ? AppColors.successLight : null,
      borderColor: complete ? AppColors.success : null,
      child: Row(
        children: [
          ProgressRing(
            progress: FunDailyChallengeLogic.progressRatio(funProgress),
            size: 56,
            color: complete ? AppColors.success : AppColors.accent,
            trackColor: theme.colorScheme.surfaceContainerHighest,
            center: Icon(
              complete ? Icons.check_rounded : Icons.flag_rounded,
              color: complete ? AppColors.success : AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Challenge', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  complete
                      ? 'Complete! +50 XP · +20 coins'
                      : 'Learn $wordsLearned / $target words today',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

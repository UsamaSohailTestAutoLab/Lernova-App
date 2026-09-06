import 'package:flutter/material.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

class GameModeCard extends StatelessWidget {
  final FunGameMode mode;
  final int level;
  final bool unlocked;
  final VoidCallback? onTap;

  const GameModeCard({
    super.key,
    required this.mode,
    required this.level,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playable = unlocked && mode.isImplemented;

    return AppCard(
      onTap: playable ? onTap : null,
      color: playable ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(mode.emoji, style: const TextStyle(fontSize: 28)),
              const Spacer(),
              if (!playable)
                const Icon(Icons.lock_rounded, size: 18, color: AppColors.leagueSilver)
              else
                _LevelBadge(level: level),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mode.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: playable ? null : theme.colorScheme.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              mode.isImplemented
                  ? mode.blurb
                  : 'Unlocks at level ${mode.unlockLevel} — coming soon',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Lv $level',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.accent),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

class GameModeCard extends StatelessWidget {
  final FunGameMode mode;
  final int level;
  final bool unlocked;

  /// Behind the subscription rather than behind a Fun level.
  ///
  /// Kept apart from [unlocked] because the two locks want opposite
  /// treatments: a level lock tells the learner to go play more, which
  /// they can act on; a Pro lock is an offer, so the card stays lit,
  /// stays tappable, and opens the paywall.
  final bool requiresPro;

  final VoidCallback? onTap;

  const GameModeCard({
    super.key,
    required this.mode,
    required this.level,
    required this.unlocked,
    required this.onTap,
    this.requiresPro = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playable = unlocked && mode.isImplemented && !requiresPro;
    // Pro cards are not greyed out. Dimming the entire grid down to one
    // playable tile makes the Fun tab look broken rather than paid.
    final dimmed = !playable && !requiresPro;

    return AppCard(
      onTap: requiresPro ? onTap : (playable ? onTap : null),
      color: dimmed ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(mode.emoji, style: const TextStyle(fontSize: 28)),
              const Spacer(),
              if (requiresPro)
                const Icon(Icons.lock_rounded, size: 18, color: AppColors.accent)
              else if (!playable)
                const Icon(Icons.lock_rounded, size: 18, color: AppColors.leagueSilver)
              else
                _LevelBadge(level: level),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mode.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: dimmed ? theme.colorScheme.outline : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              requiresPro
                  ? 'Unlock with Pro'
                  : mode.isImplemented
                      ? mode.blurb
                      : 'Unlocks at level ${mode.unlockLevel} — coming soon',
              style: theme.textTheme.bodySmall?.copyWith(
                color: requiresPro ? AppColors.accent : null,
                fontWeight: requiresPro ? FontWeight.w700 : null,
              ),
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

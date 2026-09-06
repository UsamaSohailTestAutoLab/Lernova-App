import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/falling_word_session_controller.dart';

/// Combo counter with the spec's 🔥5/10/20/30 escalation — scales and
/// recolors as the multiplier climbs so a hot streak actually feels hot.
class ComboHud extends StatelessWidget {
  final int combo;
  final bool enabled;

  const ComboHud({super.key, required this.combo, required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (!enabled || combo < 2) return const SizedBox.shrink();

    final multiplier = FallingWordSessionController.comboMultiplier(combo);
    final color = switch (multiplier) {
      >= 5 => AppColors.error,
      4 => AppColors.accent,
      3 => AppColors.primary,
      _ => AppColors.success,
    };

    return TweenAnimationBuilder<double>(
      key: ValueKey(combo),
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.xl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              '$combo combo · x$multiplier',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

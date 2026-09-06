import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A generic icon+label pill — generalizes what was previously
/// `StatChip`-only. Used for "Lv 3", "+40 XP", "PRO", unlock
/// requirements, difficulty badges, and anywhere else a small colored
/// badge is needed.
class AppPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// A full-colour glyph shown instead of [icon]. Same reasoning as
  /// [AppMetricData.emoji]: a single-colour Material glyph reads flat
  /// next to the rest of the dashboard.
  final String? emoji;

  final Color color;

  /// Solid color fill with a light foreground (e.g. "PRO"), vs. the
  /// default translucent wash with a colored foreground (e.g. stat
  /// chips).
  final bool filled;

  final double size;
  final VoidCallback? onTap;

  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    required this.color,
    this.filled = false,
    this.size = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = filled ? Colors.white : color;
    final bg = filled ? color : color.withValues(alpha: 0.12);

    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md * size, vertical: 6 * size),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        // A rim in the pill's own colour. On the dark theme a
        // translucent wash alone barely separates from the backdrop;
        // the border is what makes it read as a chip.
        border: Border.all(color: color.withValues(alpha: filled ? 0.0 : 0.30)),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: TextStyle(fontSize: 15 * size)),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 18 * size, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
        ],
      ),
    );

    if (onTap == null) return pill;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.xl),
      onTap: onTap,
      child: pill,
    );
  }
}

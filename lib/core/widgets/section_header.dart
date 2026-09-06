import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A section heading with an optional icon, subtitle, and a trailing
/// action ("See all") — replaces bare `Text(..., titleLarge)` headers
/// used ad hoc on Home, the Fun hub, and Settings.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final IconData? icon;
  final Widget? trailing;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final bool dense;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.icon,
    this.trailing,
    this.trailingLabel,
    this.onTrailingTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailingWidget = trailing ??
        (trailingLabel != null
            ? TextButton(onPressed: onTrailingTap, child: Text(trailingLabel!))
            : null);

    return Padding(
      padding: EdgeInsets.only(bottom: dense ? AppSpacing.sm : AppSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                Text(title, style: dense ? theme.textTheme.titleMedium : theme.textTheme.titleLarge),
                if (subtitle != null)
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          ?trailingWidget,
        ],
      ),
    );
  }
}

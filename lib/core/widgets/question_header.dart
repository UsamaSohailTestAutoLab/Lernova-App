import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The exercise question header — every one of the 8 exercise types
/// previously wrote `Text(payload.prompt, style: headlineSmall)` as its
/// own first child independently. One shared widget now, with an
/// optional small "type" eyebrow (e.g. "Listening", "Speaking") and a
/// hint line for supplementary instructions.
class QuestionHeader extends StatelessWidget {
  final String prompt;
  final String? hint;
  final IconData? typeIcon;
  final String? typeLabel;

  const QuestionHeader({
    super.key,
    required this.prompt,
    this.hint,
    this.typeIcon,
    this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (typeIcon != null || typeLabel != null) ...[
          Row(
            children: [
              if (typeIcon != null) ...[
                Icon(typeIcon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              if (typeLabel != null)
                Text(
                  typeLabel!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(prompt, style: theme.textTheme.headlineSmall),
        if (hint != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(hint!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

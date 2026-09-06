import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decor.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius_ext.dart';
import '../theme/app_spacing.dart';

enum ChoiceTileState { idle, selected, correct, incorrect, disabled }

/// - [row] — leading + title/subtitle + trailing state icon. The most
///   common shape (multiple-choice, listening, fill-in-blank options).
/// - [stacked] — leading centered above the label. For an
///   image/emoji-plus-word tile (image recognition).
/// - [compact] — text only, tighter padding. For dense option lists
///   (the placement test).
enum ChoiceTileLayout { row, stacked, compact }

/// The single option-tile implementation replacing three independent
/// ones that had accumulated across `OptionChoiceList`, the placement
/// test, and the image-recognition exercise — plus [SelectableTile],
/// which now delegates here.
class AppChoiceTile extends StatelessWidget {
  final String label;
  final String? secondaryLabel;
  final Widget? leading;
  final Widget? trailing;
  final ChoiceTileState state;
  final ChoiceTileLayout layout;
  final VoidCallback? onTap;
  final bool showStateIcon;
  final bool animateState;
  final String? semanticLabel;

  const AppChoiceTile({
    super.key,
    required this.label,
    this.secondaryLabel,
    this.leading,
    this.trailing,
    this.state = ChoiceTileState.idle,
    this.layout = ChoiceTileLayout.row,
    this.onTap,
    this.showStateIcon = true,
    this.animateState = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final surfaceColors = context.surfaceColors;

    final Color bg;
    final Color border;
    final Color contentColor;
    final double borderWidth;
    IconData? stateIcon;

    switch (state) {
      case ChoiceTileState.idle:
        bg = surfaceColors.surface;
        border = surfaceColors.border;
        contentColor = theme.textTheme.titleMedium?.color ?? theme.colorScheme.onSurface;
        borderWidth = 1;
      case ChoiceTileState.selected:
        bg = theme.colorScheme.primary.withValues(alpha: 0.1);
        border = theme.colorScheme.primary;
        contentColor = theme.colorScheme.primary;
        borderWidth = 2;
        stateIcon = Icons.check_circle_rounded;
      case ChoiceTileState.correct:
        bg = decor.tint(AppColors.success);
        border = AppColors.success;
        contentColor = AppColors.success;
        borderWidth = 2;
        stateIcon = Icons.check_circle_rounded;
      case ChoiceTileState.incorrect:
        bg = decor.tint(AppColors.error);
        border = AppColors.error;
        contentColor = AppColors.error;
        borderWidth = 2;
        stateIcon = Icons.cancel_rounded;
      case ChoiceTileState.disabled:
        bg = surfaceColors.surfaceAlt;
        border = surfaceColors.border;
        contentColor = surfaceColors.textMuted;
        borderWidth = 1;
    }

    final padding = layout == ChoiceTileLayout.compact
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md)
        : const EdgeInsets.all(AppSpacing.md);

    // Only correct/incorrect force the secondary line to the state
    // color — idle/selected/disabled leave it at its natural secondary
    // shade, matching how the tiles this replaces behaved.
    final secondaryColorOverride =
        (state == ChoiceTileState.correct || state == ChoiceTileState.incorrect)
            ? contentColor
            : null;

    Widget content;
    switch (layout) {
      case ChoiceTileLayout.stacked:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?leading,
            if (leading != null) const SizedBox(height: AppSpacing.sm),
            Text(label, style: theme.textTheme.titleMedium?.copyWith(color: contentColor)),
            if (secondaryLabel != null)
              Text(
                secondaryLabel!,
                style: theme.textTheme.bodySmall?.copyWith(color: secondaryColorOverride),
              ),
          ],
        );
      case ChoiceTileLayout.row:
      case ChoiceTileLayout.compact:
        content = Row(
          children: [
            ?leading,
            if (leading != null) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.titleMedium?.copyWith(color: contentColor)),
                  if (secondaryLabel != null)
                    Text(
                      secondaryLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(color: secondaryColorOverride),
                    ),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && showStateIcon && stateIcon != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(stateIcon, color: contentColor),
            ],
          ],
        );
    }

    final tile = AnimatedContainer(
      duration: animateState ? AppMotion.d(context, AppMotion.fast) : Duration.zero,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: content,
    );

    final isInteractive = onTap != null && state != ChoiceTileState.disabled;

    Widget tappable = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: isInteractive ? onTap : null,
        child: tile,
      ),
    );

    return Semantics(
      selected: state == ChoiceTileState.selected,
      button: isInteractive,
      label: semanticLabel,
      child: tappable,
    );
  }
}

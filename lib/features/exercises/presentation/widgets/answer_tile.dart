import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decor.dart';
import '../../../../core/theme/app_spacing.dart';

/// How an answer option is currently being presented.
enum AnswerTileState {
  /// Untouched, waiting to be picked.
  idle,

  /// Picked, not yet graded.
  selected,

  /// Graded right — or revealed as the right one after a miss.
  correct,

  /// Graded wrong.
  incorrect,

  /// Still on screen but no longer in play, so it recedes rather than
  /// competing with the answer that matters.
  dimmed,
}

/// One tappable answer.
///
/// Replaces a flat 1px-outlined box that gave no sense of being a
/// button, no press feedback, and no indication of which option was
/// which. This adds:
///
///  * a **raised lip** — a darker edge under the tile that the tile
///    presses down onto, the same depth cue the Path nodes use, so it
///    reads as a physical button rather than a form field;
///  * a **letter badge**, which gives every option a name and a second
///    landmark for the eye;
///  * **animated** state changes, so grading feels like a response
///    rather than a repaint;
///  * theme-resolved colours, since the raw `successLight`/`errorLight`
///    literals it used before are pale washes that the theme's near-white
///    dark-mode text disappears into.
class AnswerTile extends StatefulWidget {
  final String label;
  final AnswerTileState state;

  /// A/B/C/D. Null hides the badge — used where options are already
  /// numbered by something else.
  final String? badge;
  final VoidCallback? onTap;

  const AnswerTile({
    super.key,
    required this.label,
    required this.state,
    this.badge,
    this.onTap,
  });

  @override
  State<AnswerTile> createState() => _AnswerTileState();
}

class _AnswerTileState extends State<AnswerTile> {
  bool _pressed = false;

  /// How far the tile sits above its lip. Pressing sinks it onto it.
  static const _lip = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final enabled = widget.onTap != null;

    final (face, edge, ink) = switch (widget.state) {
      AnswerTileState.correct => (
          decor.tint(AppColors.success),
          AppColors.success,
          AppColors.success,
        ),
      AnswerTileState.incorrect => (
          decor.tint(AppColors.error),
          AppColors.error,
          AppColors.error,
        ),
      AnswerTileState.selected => (
          decor.tint(AppColors.primary),
          AppColors.primary,
          AppColors.primary,
        ),
      AnswerTileState.dimmed => (
          theme.colorScheme.surface,
          theme.colorScheme.outlineVariant,
          theme.colorScheme.onSurfaceVariant,
        ),
      AnswerTileState.idle => (
          theme.colorScheme.surface,
          theme.colorScheme.outlineVariant,
          theme.colorScheme.onSurface,
        ),
    };

    final graded = widget.state == AnswerTileState.correct ||
        widget.state == AnswerTileState.incorrect;
    final sunk = _pressed && enabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.badge == null ? widget.label : '${widget.badge}. ${widget.label}',
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.state == AnswerTileState.dimmed ? 0.55 : 1,
          child: Padding(
            // Reserved so a tile sinking onto its lip doesn't shift the
            // ones below it.
            padding: const EdgeInsets.only(bottom: _lip),
            child: Stack(
              children: [
                // The lip: a darker slab the face sits on top of.
                Positioned.fill(
                  top: _lip,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        edge.withValues(alpha: 0.45),
                        theme.colorScheme.surfaceContainerHighest,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(0, sunk ? _lip : 0, 0),
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: face,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: edge, width: graded ? 2.5 : 1.5),
                  ),
                  child: Row(
                    children: [
                      if (widget.badge != null) ...[
                        _Badge(text: widget.badge!, color: ink, filled: graded),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Text(
                          widget.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: ink,
                            fontWeight: graded ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      // A tick or cross beside a graded answer, so the
                      // verdict does not rest on colour alone.
                      if (graded) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          widget.state == AnswerTileState.correct
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: ink,
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;

  const _Badge({required this.text, required this.color, required this.filled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.5), width: 1.5),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: filled ? Colors.white : color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

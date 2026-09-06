import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

enum BubbleVisualState { idle, correct, incorrect }

/// One answer bubble in the Word Bubble game: a clean white pill with a
/// green outline, an illustrative emoji, and bold dark-green text.
///
/// The white-on-green treatment is deliberate. Solid saturated bubbles
/// with white text were legible in isolation but read as confetti in a
/// group, and a translucent fill made the text fight the background
/// behind it. A white card with a green rim reads as a *button you can
/// press*, keeps contrast at its maximum (near-black green on white),
/// and stays on-brand without shouting.
///
/// Positioning is always owned by the parent; this widget renders only
/// the pill, its emoji/label, and its tap/burst state.
class WaterBubble extends StatelessWidget {
  final String label;

  /// Shown before the label when there's room. Purely supporting art —
  /// the word is always rendered, so an option is never a symbol the
  /// learner has to decode.
  final String? emoji;

  final BubbleVisualState state;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double fontSize;

  const WaterBubble({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.emoji,
    this.width = 168,
    this.height = 68,
    this.fontSize = 20,
  });

  /// Below this the pill is too narrow for an emoji *and* a readable
  /// word, and the word always wins.
  static const double _emojiMinWidth = 120;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final popped = state != BubbleVisualState.idle;

    final (fill, rim, ink) = switch (state) {
      BubbleVisualState.idle => (
          Colors.white,
          AppColors.primary,
          AppColors.primaryDark,
        ),
      BubbleVisualState.correct => (
          AppColors.successLight,
          AppColors.success,
          AppColors.primaryDark,
        ),
      BubbleVisualState.incorrect => (
          AppColors.errorLight,
          AppColors.error,
          AppColors.error,
        ),
    };

    final showEmoji = emoji != null && width >= _emojiMinWidth;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // The burst sits *behind* the vanishing pill so the droplets
            // read as it coming apart, not as a badge on top of it.
            if (popped)
              Positioned.fill(
                child: _BubbleBurst(
                  color: state == BubbleVisualState.correct
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            AnimatedScale(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              scale: popped ? 1.3 : 1,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                opacity: popped ? 0 : 1,
                child: Container(
                  width: width,
                  height: height,
                  padding: EdgeInsets.symmetric(
                    horizontal: showEmoji ? AppSpacing.md : AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(height / 2),
                    border: Border.all(color: rim, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: rim.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showEmoji) ...[
                        Text(emoji!, style: TextStyle(fontSize: fontSize * 1.15)),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: fontSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-shot pop: an expanding ring plus eight droplets thrown outward.
/// Deliberately short and cheap — it plays on every answer, so it has to
/// feel like punctuation rather than a cutscene.
class _BubbleBurst extends StatelessWidget {
  final Color color;
  const _BubbleBurst({required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return CustomPaint(painter: _BurstPainter(t: t, color: color));
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;

  _BurstPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = math.min(size.width, size.height) / 2;
    final fade = (1 - t).clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      base * (0.6 + t * 0.9),
      Paint()
        ..color = color.withValues(alpha: 0.45 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade + 1,
    );

    final droplet = Paint()..color = color.withValues(alpha: 0.75 * fade);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + 0.2;
      final distance = base * (0.5 + t * 1.05);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        (base * 0.13) * fade,
        droplet,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/fun/fun_question.dart';
import 'water_bubble.dart';

/// The Word Bubble playfield: two or three bubbles rise from the bottom
/// of the tank, drifting sideways as they go, and the round's timer runs
/// out when they reach the top.
///
/// Replaces the old top-to-bottom grid of solid pills. Two things drove
/// the change: bubbles that *rise* are what the mode is actually named
/// for, and — with options now capped at 2–3 (see
/// `FunLevelConfig.bubbleOptionCount`) — each one gets a wide lane, so
/// nothing overlaps and long words have real room instead of being
/// shrunk until they fit.
///
/// [progress] is the shared 0→1 round timer, so the rise stays exactly in
/// step with the existing timeout: one controller, one source of truth.
class BubbleField extends StatelessWidget {
  final FunQuestion question;
  final double progress;
  final int? tappedIndex;
  final BubbleVisualState tappedState;
  final ValueChanged<int> onSelect;

  const BubbleField({
    super.key,
    required this.question,
    required this.progress,
    required this.tappedIndex,
    required this.tappedState,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = question.options.length;
        final laneWidth = constraints.maxWidth / count;

        // Every bubble fits inside its own lane by construction, so there
        // is no clamp that can make one wider than the space it has.
        final bubbleWidth = math.min(laneWidth - 12.0, 200.0).clamp(72.0, 200.0);
        final bubbleHeight = math.min(bubbleWidth * 0.5, constraints.maxHeight * 0.28)
            .clamp(52.0, 84.0);

        final travel = math.max(0.0, constraints.maxHeight - bubbleHeight);
        // Rising: 0 = resting on the bottom, 1 = at the surface.
        final bottom = progress * travel;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _TankPainter(progress: progress))),
            for (var i = 0; i < count; i++)
              Positioned(
                left: laneWidth * i +
                    laneWidth / 2 -
                    bubbleWidth / 2 +
                    _drift(i, progress, laneWidth - bubbleWidth),
                bottom: bottom,
                child: WaterBubble(
                  label: question.options[i],
                  emoji: question.emojiFor(i),
                  width: bubbleWidth,
                  height: bubbleHeight,
                  fontSize: 17,
                  state: tappedIndex == i ? tappedState : BubbleVisualState.idle,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        );
      },
    );
  }

  /// A gentle sideways sway, phase-shifted per lane so the bubbles don't
  /// move as one rigid block. Bounded by the slack left in the lane, so
  /// drift can never push a bubble into its neighbour.
  static double _drift(int index, double progress, double slack) {
    if (slack <= 0) return 0;
    final amplitude = math.min(slack / 2, 14.0);
    return math.sin(progress * math.pi * 2 + index * 1.7) * amplitude;
  }
}

/// Faint background bubbles drifting up the tank. Purely decorative and
/// non-interactive — it gives the playfield depth without competing with
/// the answers.
class _TankPainter extends CustomPainter {
  final double progress;
  _TankPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.green300.withValues(alpha: 0.22);
    for (var i = 0; i < 9; i++) {
      final seedX = ((i * 37) % 100) / 100;
      final speed = 0.6 + ((i * 13) % 7) / 10;
      final y = size.height -
          ((progress * speed + i / 9) % 1.0) * (size.height + 40) +
          20;
      final radius = 3.0 + (i % 4) * 2.0;
      canvas.drawCircle(Offset(seedX * size.width, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TankPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

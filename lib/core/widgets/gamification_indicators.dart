import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_pill.dart';

/// Small pill showing an icon + value, used for hearts/gems/XP/streak
/// readouts in app bars and dashboard headers. A thin delegate onto
/// [AppPill].
class StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;

  /// Full-colour glyph shown instead of [icon] — see
  /// [AppMetricData.emoji].
  final String? emoji;

  final VoidCallback? onTap;

  const StatChip({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    this.emoji,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppPill(
      label: value,
      icon: icon,
      emoji: emoji,
      color: color,
      onTap: onTap,
    );
  }
}

/// Hearts remaining in the current attempt. Premium is deliberately not
/// a parameter: hearts are a per-session life budget that refills every
/// lesson, not something Pro removes.
class HeartsChip extends StatelessWidget {
  final int hearts;
  final VoidCallback? onTap;

  const HeartsChip({super.key, required this.hearts, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StatChip(
      icon: Icons.favorite_rounded,
      emoji: '❤️',
      color: AppColors.heart,
      value: '$hearts',
      onTap: onTap,
    );
  }
}

class GemsChip extends StatelessWidget {
  final int gems;
  final VoidCallback? onTap;
  const GemsChip({super.key, required this.gems, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StatChip(
      icon: Icons.diamond_rounded,
      emoji: '💎',
      color: AppColors.gem,
      value: '$gems',
      onTap: onTap,
    );
  }
}

class StreakChip extends StatelessWidget {
  final int streak;
  final VoidCallback? onTap;
  const StreakChip({super.key, required this.streak, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StatChip(
      icon: Icons.local_fire_department_rounded,
      emoji: '🔥',
      color: AppColors.streak,
      value: '$streak',
      onTap: onTap,
    );
  }
}

/// Circular XP/daily-goal progress ring with a label in the center.
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final Color color;
  final Color trackColor;
  final Widget? center;
  final double strokeWidth;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    required this.color,
    required this.trackColor,
    this.center,
    this.strokeWidth = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0, 1)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: value,
                  color: color,
                  trackColor: trackColor,
                  strokeWidth: strokeWidth,
                ),
              );
            },
          ),
          ?center,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * 3.14159265358979 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265358979 / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Linear lesson-progress bar used inside the exercise player.
class LessonProgressBar extends StatelessWidget {
  final double progress;
  const LessonProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 12,
          // Explicit colours rather than the theme defaults, which pair
          // a pale green fill with a pale green track — at the start of
          // a lesson that read as an empty grey pill with nothing in it,
          // as if the bar were broken.
          color: AppColors.primaryVivid,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

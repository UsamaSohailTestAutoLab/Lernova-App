import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

enum SparkMood { happy, celebrate, sad, sleepy, thinking }

/// Lernova's original mascot: an abstract geometric "spark" — a rounded
/// four-point star with a simple face. Entirely custom-painted (no
/// image assets, no owl/bird silhouette) so it carries no resemblance
/// to any existing brand's character.
class SparkMascot extends StatelessWidget {
  final double size;
  final SparkMood mood;
  final Color color;

  /// A thin darker stroke around the star body, for definition against
  /// tinted/gradient backgrounds. Off by default (today's flat look).
  final bool outline;

  /// A subtle two-stop gradient body fill instead of a flat color.
  final bool gradient;

  /// A soft shadow ellipse beneath the mascot, for a sense of it
  /// resting on the surface rather than floating flat against it.
  final bool groundShadow;

  /// A gentle idle breathing motion. Ambient-guarded — disabled
  /// automatically under the OS "remove animations" setting.
  final bool animate;

  const SparkMascot({
    super.key,
    this.size = 96,
    this.mood = SparkMood.happy,
    this.color = AppColors.primary,
    this.outline = false,
    this.gradient = false,
    this.groundShadow = false,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SparkPainter(
          mood: mood,
          color: color,
          outline: outline,
          gradient: gradient,
          groundShadow: groundShadow,
        ),
      ),
    );

    if (!animate) return content;
    return _BreathingMascot(child: content);
  }
}

class _BreathingMascot extends StatefulWidget {
  final Widget child;
  const _BreathingMascot({required this.child});

  @override
  State<_BreathingMascot> createState() => _BreathingMascotState();
}

class _BreathingMascotState extends State<_BreathingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _ambientChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ambientChecked) {
      _ambientChecked = true;
      if (AppMotion.ambientEnabled(context)) _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + Curves.easeInOut.transform(_controller.value) * 0.03;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

class _SparkPainter extends CustomPainter {
  final SparkMood mood;
  final Color color;
  final bool outline;
  final bool gradient;
  final bool groundShadow;

  _SparkPainter({
    required this.mood,
    required this.color,
    required this.outline,
    required this.gradient,
    required this.groundShadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    if (groundShadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, size.height * 0.94),
          width: size.width * 0.6,
          height: size.height * 0.08,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.14),
      );
    }

    final path = Path();
    // Four-point rounded "spark" star.
    for (var i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) - math.pi / 2;
      final tip = Offset(
        center.dx + r * 0.98 * _cos(angle),
        center.dy + r * 0.98 * _sin(angle),
      );
      final ctrl1Angle = angle + math.pi / 4;
      final ctrl1 = Offset(
        center.dx + r * 0.35 * _cos(ctrl1Angle),
        center.dy + r * 0.35 * _sin(ctrl1Angle),
      );
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.quadraticBezierTo(ctrl1.dx, ctrl1.dy, tip.dx, tip.dy);
      }
    }
    final closingAngle = -math.pi / 2 + math.pi / 4 - math.pi * 2;
    path.quadraticBezierTo(
      center.dx + r * 0.35 * _cos(closingAngle),
      center.dy + r * 0.35 * _sin(closingAngle),
      center.dx + r * 0.98 * _cos(-math.pi / 2),
      center.dy + r * 0.98 * _sin(-math.pi / 2),
    );
    path.close();

    final bodyPaint = Paint();
    if (gradient) {
      bodyPaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.18)!, color],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    } else {
      bodyPaint.color = color;
    }
    canvas.drawPath(path, bodyPaint);

    if (outline) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(color, Colors.black, 0.25)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.02,
      );
    }

    // Face.
    final facePaint = Paint()..color = Colors.white;
    final eyeOffset = size.width * 0.13;
    final eyeY = center.dy - size.height * 0.02;
    final eyeSize = mood == SparkMood.sleepy ? 2.0 : size.width * 0.06;

    canvas.drawCircle(Offset(center.dx - eyeOffset, eyeY), eyeSize, facePaint);
    canvas.drawCircle(Offset(center.dx + eyeOffset, eyeY), eyeSize, facePaint);

    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;

    final mouthCenter = Offset(center.dx, center.dy + size.height * 0.14);
    final mouthWidth = size.width * 0.16;

    switch (mood) {
      case SparkMood.happy:
      case SparkMood.celebrate:
        final rect = Rect.fromCenter(
          center: mouthCenter,
          width: mouthWidth,
          height: mouthWidth * 0.9,
        );
        canvas.drawArc(rect, 0.15, math.pi - 0.3, false, mouthPaint);
      case SparkMood.sad:
        final rect = Rect.fromCenter(
          center: Offset(mouthCenter.dx, mouthCenter.dy + 6),
          width: mouthWidth,
          height: mouthWidth * 0.9,
        );
        canvas.drawArc(rect, math.pi + 0.15, math.pi - 0.3, false, mouthPaint);
      case SparkMood.sleepy:
      case SparkMood.thinking:
        canvas.drawLine(
          Offset(mouthCenter.dx - mouthWidth * 0.3, mouthCenter.dy),
          Offset(mouthCenter.dx + mouthWidth * 0.3, mouthCenter.dy),
          mouthPaint,
        );
    }
  }

  double _cos(double radians) => math.cos(radians);
  double _sin(double radians) => math.sin(radians);

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.color != color ||
        oldDelegate.outline != outline ||
        oldDelegate.gradient != gradient ||
        oldDelegate.groundShadow != groundShadow;
  }
}

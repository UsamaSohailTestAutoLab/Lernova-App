import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

enum CartoonCharacterMood { happy, celebrate, worried, drowning }

/// An original chibi-style cartoon human, custom-painted (no image
/// assets) — the character in the Level 1 water-survival scene, and the
/// friendly face at the top of Home. A distinct character from the app's
/// abstract Spark mascot used elsewhere.
class CartoonCharacter extends StatefulWidget {
  final double size;
  final CartoonCharacterMood mood;

  /// Whether the idle bob loops. On for a scene the character *is* (the
  /// survival level); off where it's decoration on a screen the learner
  /// sits on, since a never-ending animation there repaints forever for
  /// no gain — and stops any `pumpAndSettle` in a test from settling.
  final bool animate;

  const CartoonCharacter({
    super.key,
    required this.size,
    required this.mood,
    this.animate = true,
  });

  @override
  State<CartoonCharacter> createState() => _CartoonCharacterState();
}

class _CartoonCharacterState extends State<CartoonCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _bob = CurvedAnimation(
    parent: _bobController,
    curve: Curves.easeInOut,
  );

  bool _ambientChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ambientChecked) {
      _ambientChecked = true;
      if (widget.animate && AppMotion.ambientEnabled(context)) {
        _bobController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        return Transform.translate(offset: Offset(0, -6 * _bob.value), child: child);
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.2,
        child: CustomPaint(painter: _CartoonCharacterPainter(mood: widget.mood)),
      ),
    );
  }
}

class _CartoonCharacterPainter extends CustomPainter {
  final CartoonCharacterMood mood;
  _CartoonCharacterPainter({required this.mood});

  static const _skin = Color(0xFFFFD3A6);
  static const _hair = Color(0xFF5B3A29);
  static const _shirt = Color(0xFFFFB020);
  static const _pants = Color(0xFF3D5A80); // denim, not brand
  static const _ink = Color(0xFF2B2140);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final headRadius = w * 0.34;
    final headCenter = Offset(w / 2, headRadius + h * 0.02);

    _drawLegs(canvas, w, h);
    final torsoRect = Rect.fromLTWH(w * 0.22, h * 0.46, w * 0.56, h * 0.32);
    final torsoRRect = RRect.fromRectAndRadius(torsoRect, Radius.circular(w * 0.18));
    _drawArms(canvas, torsoRect, w, h);
    canvas.drawRRect(torsoRRect, Paint()..color = _shirt);
    _drawHead(canvas, headCenter, headRadius);
  }

  void _drawLegs(Canvas canvas, double w, double h) {
    final legPaint = Paint()..color = _pants;
    final legWidth = w * 0.15;
    final legHeight = h * 0.22;
    final legY = h - legHeight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.30, legY, legWidth, legHeight),
        Radius.circular(legWidth / 2),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.55, legY, legWidth, legHeight),
        Radius.circular(legWidth / 2),
      ),
      legPaint,
    );
  }

  void _drawArms(Canvas canvas, Rect torsoRect, double w, double h) {
    final raised = mood == CartoonCharacterMood.celebrate;
    final tense = mood == CartoonCharacterMood.worried || mood == CartoonCharacterMood.drowning;
    final angle = raised ? -1.15 : (tense ? -0.35 : 0.2);
    final armPaint = Paint()
      ..color = _shirt
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round;
    final handPaint = Paint()..color = _skin;
    final armLength = h * 0.22;

    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(
        side < 0 ? torsoRect.left + w * 0.02 : torsoRect.right - w * 0.02,
        torsoRect.top + h * 0.02,
      );
      final a = side < 0 ? math.pi - angle : angle;
      final end = shoulder + Offset(armLength * math.cos(a), -armLength * math.sin(a) + armLength * 0.55);
      canvas.drawLine(shoulder, end, armPaint);
      canvas.drawCircle(end, w * 0.06, handPaint);
    }
  }

  void _drawHead(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r, Paint()..color = _skin);

    final hairPath = Path()
      ..moveTo(center.dx - r, center.dy - r * 0.1)
      ..quadraticBezierTo(
        center.dx - r * 0.3,
        center.dy - r * 1.55,
        center.dx + r * 0.15,
        center.dy - r * 1.15,
      )
      ..quadraticBezierTo(
        center.dx + r * 0.95,
        center.dy - r * 0.95,
        center.dx + r,
        center.dy - r * 0.15,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy - r * 1.35,
        center.dx - r,
        center.dy - r * 0.1,
      )
      ..close();
    canvas.drawPath(hairPath, Paint()..color = _hair);

    final cheekPaint = Paint()..color = const Color(0xFFFF9E9E).withValues(alpha: 0.55);
    canvas.drawCircle(Offset(center.dx - r * 0.55, center.dy + r * 0.15), r * 0.15, cheekPaint);
    canvas.drawCircle(Offset(center.dx + r * 0.55, center.dy + r * 0.15), r * 0.15, cheekPaint);

    _drawFace(canvas, center, r);
  }

  void _drawFace(Canvas canvas, Offset center, double r) {
    final eyeOffsetX = r * 0.4;
    final eyeY = center.dy - r * 0.05;
    final inkPaint = Paint()..color = _ink;

    switch (mood) {
      case CartoonCharacterMood.happy:
        canvas.drawCircle(Offset(center.dx - eyeOffsetX, eyeY), r * 0.09, inkPaint);
        canvas.drawCircle(Offset(center.dx + eyeOffsetX, eyeY), r * 0.09, inkPaint);
        _mouth(canvas, center, r, smile: true);
      case CartoonCharacterMood.celebrate:
        canvas.drawCircle(Offset(center.dx - eyeOffsetX, eyeY), r * 0.1, inkPaint);
        canvas.drawCircle(Offset(center.dx + eyeOffsetX, eyeY), r * 0.1, inkPaint);
        _mouth(canvas, center, r, smile: true, open: true);
      case CartoonCharacterMood.worried:
        _brows(canvas, center, r, eyeOffsetX, eyeY);
        canvas.drawCircle(Offset(center.dx - eyeOffsetX, eyeY + 2), r * 0.08, inkPaint);
        canvas.drawCircle(Offset(center.dx + eyeOffsetX, eyeY + 2), r * 0.08, inkPaint);
        _mouth(canvas, center, r, smile: false);
      case CartoonCharacterMood.drowning:
        canvas.drawCircle(Offset(center.dx - eyeOffsetX, eyeY), r * 0.13, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(center.dx + eyeOffsetX, eyeY), r * 0.13, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(center.dx - eyeOffsetX, eyeY), r * 0.065, inkPaint);
        canvas.drawCircle(Offset(center.dx + eyeOffsetX, eyeY), r * 0.065, inkPaint);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.34), width: r * 0.28, height: r * 0.34),
          inkPaint,
        );
    }
  }

  void _mouth(Canvas canvas, Offset center, double r, {required bool smile, bool open = false}) {
    final mouthCenter = Offset(center.dx, center.dy + r * 0.3);
    final rect = Rect.fromCenter(center: mouthCenter, width: r * 0.6, height: r * 0.42);
    if (open) {
      canvas.drawArc(rect, 0.15, math.pi - 0.3, true, Paint()..color = _ink);
      return;
    }
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;
    if (smile) {
      canvas.drawArc(rect, 0.25, math.pi - 0.5, false, paint);
    } else {
      canvas.drawArc(rect.translate(0, r * 0.18), math.pi + 0.35, math.pi - 0.7, false, paint);
    }
  }

  void _brows(Canvas canvas, Offset center, double r, double offsetX, double eyeY) {
    final browPaint = Paint()
      ..color = _ink
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - offsetX - r * 0.12, eyeY - r * 0.2),
      Offset(center.dx - offsetX + r * 0.1, eyeY - r * 0.08),
      browPaint,
    );
    canvas.drawLine(
      Offset(center.dx + offsetX + r * 0.12, eyeY - r * 0.2),
      Offset(center.dx + offsetX - r * 0.1, eyeY - r * 0.08),
      browPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CartoonCharacterPainter oldDelegate) => oldDelegate.mood != mood;
}

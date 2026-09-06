import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's backdrop: the scaffold colour plus a very faint repeating
/// motif of the shapes the brand is already made of — a leaf, a speech
/// bubble, a star.
///
/// Painted once, behind the whole tab shell, rather than per screen: it
/// costs a single [CustomPaint] for the entire app instead of one per
/// route, and every tab picks it up automatically by leaving its own
/// Scaffold transparent.
///
/// Deliberately near-invisible (a few percent alpha). It should register
/// as texture when you look for it and disappear entirely when you're
/// reading — anything stronger competes with the content on top.
class AppTextureBackdrop extends StatelessWidget {
  final Widget child;
  const AppTextureBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Opaque, self-contained colours: the wash must not depend on
    // whatever happens to be painted behind this widget, or it renders
    // washed-out anywhere the backdrop isn't sitting on the scaffold.
    final base = isDark ? AppColors.darkBg : AppColors.lightBg;
    final top = isDark
        ? Color.alphaBlend(AppColors.green900.withValues(alpha: 0.55), base)
        : AppColors.green50;

    return DecoratedBox(
      decoration: BoxDecoration(
        // A long vertical wash over the flat scaffold colour, so the top
        // of the screen sits a touch lighter than the bottom.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, base],
          stops: const [0.0, 0.55],
        ),
      ),
      child: CustomPaint(
        painter: _MotifPainter(
          color: (isDark ? AppColors.green400 : AppColors.primary)
              .withValues(alpha: isDark ? 0.045 : 0.030),
        ),
        child: child,
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  final Color color;
  _MotifPainter({required this.color});

  /// Grid pitch in logical pixels. Large enough that the motifs read as
  /// occasional texture rather than wallpaper.
  static const _cell = 96.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..color = color;

    final cols = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        // Offset every other row so the grid doesn't read as columns.
        final dx = col * _cell + (row.isEven ? 0 : _cell / 2);
        final dy = row * _cell;
        canvas.save();
        canvas.translate(dx, dy);
        // Rotate per cell so repeated motifs don't line up into stripes.
        canvas.rotate(((row * 3 + col) % 4) * math.pi / 6);
        switch ((row + col) % 3) {
          case 0:
            _leaf(canvas, paint);
          case 1:
            _bubble(canvas, paint);
          default:
            _spark(canvas, paint);
        }
        canvas.restore();
      }
    }
  }

  void _leaf(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, 14)
      ..quadraticBezierTo(-2, 0, 12, -10)
      ..quadraticBezierTo(14, 4, 0, 14)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _bubble(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -8, 20, 15),
        const Radius.circular(6),
      ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-4, 6)
        ..lineTo(2, 6)
        ..lineTo(-5, 13)
        ..close(),
      paint,
    );
  }

  void _spark(Canvas canvas, Paint paint) {
    final path = Path();
    const r = 11.0;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 - math.pi / 2;
      final tip = Offset(r * math.cos(angle), r * math.sin(angle));
      final ctrlAngle = angle + math.pi / 4;
      final ctrl = Offset(r * 0.3 * math.cos(ctrlAngle), r * 0.3 * math.sin(ctrlAngle));
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MotifPainter oldDelegate) =>
      oldDelegate.color != color;
}

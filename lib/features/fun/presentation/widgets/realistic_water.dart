import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

/// A gently animated water surface — two phase-shifted sine-wave layers
/// over a vertical gradient body, giving the rising water in the Level 1
/// survival scene real motion instead of a flat colored block. Takes no
/// size of its own: it always paints to fill whatever box its parent
/// gives it, so wrapping it in an [AnimatedContainer] with a changing
/// height animates the water level smoothly without fighting a fixed
/// internal size.
class RealisticWater extends StatefulWidget {
  const RealisticWater({super.key});

  @override
  State<RealisticWater> createState() => _RealisticWaterState();
}

class _RealisticWaterState extends State<RealisticWater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  bool _ambientChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ambientChecked) {
      _ambientChecked = true;
      if (AppMotion.ambientEnabled(context)) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WavePainter(phase: _controller.value * 2 * math.pi),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double phase;
  _WavePainter({required this.phase});

  static const _waveAmplitude = 7.0;
  static const _waveLength = 70.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6FD3EE), AppColors.info],
      ).createShader(rect);

    final body = Path()..moveTo(0, _waveAmplitude);
    for (double x = 0; x <= size.width; x += 4) {
      final y = _waveAmplitude * math.sin((x / _waveLength) + phase) + _waveAmplitude;
      body.lineTo(x, y);
    }
    body.lineTo(size.width, size.height);
    body.lineTo(0, size.height);
    body.close();
    canvas.drawPath(body, bodyPaint);

    // Second, lighter wave layer for depth/parallax.
    final foamPaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    final foam = Path()..moveTo(0, _waveAmplitude + 3);
    for (double x = 0; x <= size.width; x += 4) {
      final y = _waveAmplitude * 0.7 * math.sin((x / (_waveLength * 0.6)) - phase * 1.4) +
          _waveAmplitude +
          5;
      foam.lineTo(x, y);
    }
    foam.lineTo(size.width, _waveAmplitude + 18);
    foam.lineTo(0, _waveAmplitude + 18);
    foam.close();
    canvas.drawPath(foam, foamPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.phase != phase;
}

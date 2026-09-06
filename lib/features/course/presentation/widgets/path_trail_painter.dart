import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws one row's share of the Path's connecting trail: a curved
/// segment from the previous row's exit point down to this row's node
/// center, then a straight stub continuing to the row's bottom edge
/// (which lines up exactly with the next row's own incoming point,
/// since both reference the same [toDx]). Entirely self-contained per
/// row — no cross-item painting, so `ListView.builder`'s incremental
/// build is untouched and a state change repaints only the 1-2 rows
/// that actually changed.
///
/// [nodeCenterY] is where the curve ends and the stub begins. Passing
/// [nodeCenterY] equal to the canvas height (as unit banners do) makes
/// the stub zero-length, since a banner has no node circle to stub
/// past.
class PathTrailPainter extends CustomPainter {
  final double fromDx;
  final double toDx;
  final double nodeCenterY;
  final Color track;
  final Color filled;

  /// True once this row's own node/banner has been reached — draws a
  /// solid filled overlay ("the road behind you") instead of a plain
  /// track. Distinct from [dashed], which is for segments not yet
  /// reachable at all.
  final bool isFilled;

  /// True when this row is locked/not yet reachable — the track is
  /// drawn dashed rather than solid.
  final bool isDashed;

  PathTrailPainter({
    required this.fromDx,
    required this.toDx,
    required this.nodeCenterY,
    required this.track,
    required this.filled,
    required this.isFilled,
    required this.isDashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final start = Offset(centerX + fromDx, 0);
    final end = Offset(centerX + toDx, nodeCenterY);

    final curve = Path()..moveTo(start.dx, start.dy);
    final c1 = Offset(start.dx, start.dy + (end.dy - start.dy) * 0.4);
    final c2 = Offset(end.dx, start.dy + (end.dy - start.dy) * 0.6);
    curve.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    _paintTrack(canvas, curve);

    if (nodeCenterY < size.height) {
      final stub = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(centerX + toDx, size.height);
      _paintTrack(canvas, stub);
    }
  }

  void _paintTrack(Canvas canvas, Path path) {
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    if (isDashed) {
      _drawDashed(canvas, path, trackPaint);
    } else {
      canvas.drawPath(path, trackPaint);
    }

    if (isFilled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = filled
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dashLength = 10.0;
    const gapLength = 10.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant PathTrailPainter oldDelegate) {
    return oldDelegate.fromDx != fromDx ||
        oldDelegate.toDx != toDx ||
        oldDelegate.nodeCenterY != nodeCenterY ||
        oldDelegate.track != track ||
        oldDelegate.filled != filled ||
        oldDelegate.isFilled != isFilled ||
        oldDelegate.isDashed != isDashed;
  }
}

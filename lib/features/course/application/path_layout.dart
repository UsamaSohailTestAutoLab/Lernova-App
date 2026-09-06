import 'dart:math' as math;

import 'package:flutter/widgets.dart' show TextDirection;

import '../../../data/models/course.dart';

/// The Path screen flattened into one addressable 1-D list, so each
/// `ListView.builder` row (a unit banner or a lesson node) knows its
/// own fixed vertical extent without any layout pass — which is what
/// lets scroll-to-current-lesson be pure arithmetic (see
/// [PathLayout.offsetForIndex]) instead of a `GlobalKey` measurement.
sealed class PathItem {
  const PathItem();
}

class PathUnitBanner extends PathItem {
  final int unitIndex;
  const PathUnitBanner(this.unitIndex);
}

class PathNodeItem extends PathItem {
  final int unitIndex;
  final int lessonIndex;
  const PathNodeItem(this.unitIndex, this.lessonIndex);
}

class PathLayout {
  PathLayout._();

  // 84px lip-adjusted current-node circle + 6px gap + up to 2 caption
  // lines + the top inset that centers a node at nodeCenterY (see
  // path_node.dart) — 132 keeps every combination overflow-free.
  static const double nodeRowHeight = 132;
  static const double bannerHeight = 104;
  static const double bannerGap = 16;

  static List<PathItem> flatten(Course course) {
    final items = <PathItem>[];
    for (var u = 0; u < course.units.length; u++) {
      items.add(PathUnitBanner(u));
      for (var l = 0; l < course.units[u].lessons.length; l++) {
        items.add(PathNodeItem(u, l));
      }
    }
    return items;
  }

  static double heightOf(PathItem item) =>
      item is PathUnitBanner ? bannerHeight + bannerGap : nodeRowHeight;

  /// The scroll offset at which [items[index]] begins — pure arithmetic
  /// over fixed per-item extents, no measurement required.
  static double offsetForIndex(int index, List<PathItem> items) {
    var total = 0.0;
    for (var i = 0; i < index && i < items.length; i++) {
      total += heightOf(items[i]);
    }
    return total;
  }

  static int? indexForLesson(List<PathItem> items, int unitIndex, int lessonIndex) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is PathNodeItem && item.unitIndex == unitIndex && item.lessonIndex == lessonIndex) {
        return i;
      }
    }
    return null;
  }
}

/// Horizontal placement for lesson nodes — replaces the old
/// `Alignment(offset / 100, 0)` trick, which used a *fractional*
/// alignment (so its physical displacement scaled with screen width,
/// spreading far too wide on a tablet) and reset to the same side at
/// the start of every unit (breaking the zigzag at unit boundaries).
class PathGeometry {
  final double amplitude;
  final double nodeSize;
  final double currentNodeSize;
  final TextDirection direction;

  const PathGeometry._({
    required this.amplitude,
    required this.nodeSize,
    required this.currentNodeSize,
    required this.direction,
  });

  factory PathGeometry.forWidth(double width, TextDirection direction) {
    final amplitude = math.min(76.0, math.max(28.0, (width - 128) / 2 - 24));
    return PathGeometry._(
      amplitude: amplitude,
      nodeSize: 68,
      currentNodeSize: 80,
      direction: direction,
    );
  }

  /// A 4-phase S-curve (0, +1, 0, -1) over the *within-unit* lesson
  /// index — reads as a winding road rather than a hard left/right
  /// zigzag, and keeps lesson 0 of every unit dead center so the trail
  /// exits a unit banner straight down with no kink, and so the
  /// zigzag no longer resets to the same side at every unit boundary.
  double dxFor(int lessonIndexWithinUnit) {
    final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
    return sign * amplitude * math.sin(lessonIndexWithinUnit * math.pi / 2);
  }
}

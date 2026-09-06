import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decor.dart';
import '../../../../core/theme/app_radius_ext.dart';
import '../../../../core/utils/app_icons.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../data/models/lesson.dart';
import '../../application/path_layout.dart';
import 'path_trail_painter.dart';

/// Where the node circle's vertical center sits within its row — fixed
/// so [PathTrailPainter] can terminate its curve there regardless of
/// which node size (68 vs 80 for the current lesson) is in play.
const double _nodeCenterY = 44;

class PathNode extends StatefulWidget {
  final Lesson lesson;
  final LessonNodeState state;

  /// Horizontal offset (px from center) of the node/banner directly
  /// above this one — the trail's start point.
  final double incomingDx;

  /// This node's own horizontal offset.
  final double dx;

  final double nodeSize;
  final double currentNodeSize;
  final VoidCallback? onTap;

  /// Shown as haptic + shake + a snackbar when a locked node is tapped.
  final String? lockedMessage;

  const PathNode({
    super.key,
    required this.lesson,
    required this.state,
    required this.incomingDx,
    required this.dx,
    required this.nodeSize,
    required this.currentNodeSize,
    this.onTap,
    this.lockedMessage,
  });

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    HapticFeedback.mediumImpact();
    _shake.forward(from: 0);
    if (widget.lockedMessage != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(widget.lockedMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final surfaceColors = context.surfaceColors;

    final isCurrent = widget.state == LessonNodeState.current;
    final isLocked = widget.state == LessonNodeState.locked;
    final size = isCurrent ? widget.currentNodeSize : widget.nodeSize;

    final (color, icon) = switch (widget.state) {
      LessonNodeState.locked => (theme.colorScheme.outlineVariant, AppIcons.lock),
      LessonNodeState.current => (
          AppColors.primary,
          lessonIconFor(
            iconKey: widget.lesson.icon,
            lessonId: widget.lesson.id,
            title: widget.lesson.title,
            subtitle: widget.lesson.subtitle,
          ),
        ),
      LessonNodeState.unlocked => (
          AppColors.primary,
          lessonIconFor(
            iconKey: widget.lesson.icon,
            lessonId: widget.lesson.id,
            title: widget.lesson.title,
            subtitle: widget.lesson.subtitle,
          ),
        ),
      LessonNodeState.completed => (AppColors.success, Icons.check_rounded),
      LessonNodeState.perfect => (AppColors.accent, AppIcons.perfect),
    };

    final trailFilled = widget.state == LessonNodeState.completed ||
        widget.state == LessonNodeState.perfect;

    final stateLabel = switch (widget.state) {
      LessonNodeState.locked => 'locked',
      LessonNodeState.current => 'current lesson',
      LessonNodeState.unlocked => 'unlocked',
      LessonNodeState.completed => 'completed',
      LessonNodeState.perfect => 'completed perfectly',
    };

    return SizedBox(
      height: PathLayout.nodeRowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: PathTrailPainter(
                    fromDx: widget.incomingDx,
                    toDx: widget.dx,
                    nodeCenterY: _nodeCenterY,
                    track: decor.trailTrack,
                    filled: decor.trailFilled,
                    isFilled: trailFilled,
                    isDashed: isLocked,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: _nodeCenterY - size / 2),
              child: Transform.translate(
                offset: Offset(widget.dx, 0),
                child: AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final t = _shake.value;
                    final wiggle = (t == 0) ? 0.0 : (t < 0.5 ? t : 1 - t);
                    return Transform.translate(offset: Offset(wiggle * 12 - 3, 0), child: child);
                  },
                  child: Semantics(
                    button: true,
                    label: '${widget.lesson.title}, $stateLabel',
                    child: GestureDetector(
                      onTap: _handleTap,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _circle(color, icon, size, isCurrent, isLocked, surfaceColors),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 112,
                            child: Text(
                              widget.lesson.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: isCurrent ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(
    Color color,
    IconData icon,
    double size,
    bool isCurrent,
    bool isLocked,
    AppSurfaceColors surfaceColors,
  ) {
    final lip = Color.lerp(color, Colors.black, 0.22)!;

    return SizedBox(
      width: size,
      height: size + 4,
      child: Stack(
        children: [
          if (!isLocked)
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: lip),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLocked ? surfaceColors.surfaceAlt : color,
                border: isCurrent
                    ? Border.all(color: AppColors.primaryLight, width: 4)
                    : (isLocked ? Border.all(color: surfaceColors.border, width: 2) : null),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primaryVivid.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isLocked ? surfaceColors.textMuted : Colors.white,
                  size: size * 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

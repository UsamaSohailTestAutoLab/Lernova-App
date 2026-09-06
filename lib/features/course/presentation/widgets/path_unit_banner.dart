import 'package:flutter/material.dart';

import '../../../../core/theme/app_decor.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../core/utils/topic_palette.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/course_unit.dart';
import '../../application/path_layout.dart';
import 'path_trail_painter.dart';

/// A full-bleed gradient card marking a unit — previously just a single
/// line of text with no color, no progress, and no rendering of
/// [CourseUnit.description] at all. Sits as a milestone directly on the
/// trail: its lead-in strip carries the incoming curve from the last
/// lesson of the previous unit down to dead-center (dx 0), which is
/// also where the unit's first lesson node sits, so there's no kink.
class PathUnitBannerCard extends StatelessWidget {
  final CourseUnit unit;
  final int unitIndex;
  final int completedCount;
  final int totalCount;
  final bool reachable;

  /// Horizontal offset of the previous unit's last lesson — 0 for the
  /// first unit, since there's nothing above it to connect from.
  final double incomingDx;

  const PathUnitBannerCard({
    super.key,
    required this.unit,
    required this.unitIndex,
    required this.completedCount,
    required this.totalCount,
    required this.reachable,
    required this.incomingDx,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final accent = unitAccentFor(unit.accent);
    final icon = unitIconFor(iconKey: unit.icon, unitId: unit.id, title: unit.title);
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: CustomPaint(
            painter: PathTrailPainter(
              fromDx: incomingDx,
              toDx: 0,
              nodeCenterY: 32,
              track: decor.trailTrack,
              filled: decor.trailFilled,
              isFilled: unitIndex > 0 && completedCount == totalCount && totalCount > 0,
              isDashed: !reachable,
            ),
          ),
        ),
        AppCard(
          variant: AppCardVariant.gradient,
          tint: accent,
          padding: const EdgeInsets.all(AppSpacing.lg),
          semanticLabel: '${unit.title}${reachable ? '' : ', locked'}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'UNIT ${unitIndex + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        Text(
                          unit.title,
                          style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (!reachable)
                    const Icon(Icons.lock_rounded, color: Colors.white70),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                unit.description,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.xl),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PathLayout.bannerGap),
      ],
    );
  }
}

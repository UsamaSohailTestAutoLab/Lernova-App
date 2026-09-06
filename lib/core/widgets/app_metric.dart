import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decor.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';
import 'gamification_indicators.dart';

class AppMetricData {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  /// A full-colour glyph shown instead of [icon] where one suits the
  /// metric.
  ///
  /// Material icons are single-colour by definition, which makes a wall
  /// of them read as flat regardless of how they're tinted. An emoji is
  /// genuinely multi-coloured and dimensional on every platform that
  /// ships a colour emoji font, which is what gives the dashboard its
  /// depth. [icon] stays required as the fallback for anywhere the
  /// emoji can't render.
  final String? emoji;

  /// A small "+N" / "-N" style annotation next to the value.
  final String? delta;

  const AppMetricData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.emoji,
    this.delta,
  });
}

/// The icon side of a metric: a full-colour emoji where the metric has
/// one, otherwise the Material icon on a tinted chip.
///
/// The emoji is lit from behind with a soft radial glow in the metric's
/// own colour rather than being boxed in. A flat glyph in a flat square
/// reads as a form field; a glowing one reads as something that belongs
/// on a game dashboard, which is the whole difference between the two
/// treatments.
class MetricGlyph extends StatelessWidget {
  final AppMetricData data;
  final double size;

  const MetricGlyph({super.key, required this.data, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final emoji = data.emoji;

    if (emoji == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.decor.tint(data.color),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: data.color.withValues(alpha: 0.28)),
        ),
        child: Icon(data.icon, color: data.color, size: size * 0.55),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The halo does the work a chip border used to: it anchors the
          // glyph and ties it to the metric's colour without caging it.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.color.withValues(alpha: 0.34),
                  data.color.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: SizedBox(width: size, height: size),
          ),
          Text(emoji, style: TextStyle(fontSize: size * 0.62)),
        ],
      ),
    );
  }
}

/// - [tile] — icon + value/label in a card, optionally with a thin
///   progress bar underneath. Home's dashboard grid, Statistics.
/// - [inline] — icon + value + label on one line.
/// - [column] — icon above value above label, centered. Celebration
///   stat rows (accuracy/correct/time).
/// - [ring] — a [ProgressRing] with the value centered, label below.
enum MetricLayout { tile, inline, column, ring }

/// A single dashboard metric. Replaces bare colored-number rows (e.g.
/// the vocabulary stats on Home, which previously had no proportional
/// visual at all) with a consistent, optionally progress-bearing shape.
class AppMetric extends StatelessWidget {
  final AppMetricData data;
  final MetricLayout layout;
  final VoidCallback? onTap;

  /// Optional 0..1 progress — a thin bar under [tile], the ring's sweep
  /// under [ring]. Ignored by [inline]/[column].
  final double? progress;

  const AppMetric({
    super.key,
    required this.data,
    this.layout = MetricLayout.tile,
    this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      MetricLayout.tile => _tile(context),
      MetricLayout.inline => _inline(context),
      MetricLayout.column => _column(context),
      MetricLayout.ring => _ring(context),
    };
  }

  Widget _tile(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          MetricGlyph(data: data),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        data.value,
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data.delta != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        data.delta!,
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.success),
                      ),
                    ],
                  ],
                ),
                Text(
                  data.label,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0, 1),
                      minHeight: 4,
                      color: data.color,
                      backgroundColor: data.color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inline(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.emoji != null)
          Text(data.emoji!, style: const TextStyle(fontSize: 16))
        else
          Icon(data.icon, color: data.color, size: 18),
        const SizedBox(width: 6),
        Text(data.value, style: theme.textTheme.titleMedium),
        const SizedBox(width: 4),
        Text(data.label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _column(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.emoji != null)
          MetricGlyph(data: data, size: 34)
        else
          Icon(data.icon, color: data.color, size: 20),
        const SizedBox(height: 4),
        Text(data.value, style: theme.textTheme.headlineSmall?.copyWith(color: data.color)),
        Text(data.label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _ring(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          progress: progress ?? 0,
          color: data.color,
          trackColor: data.color.withValues(alpha: 0.15),
          center: Text(data.value, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(data.label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

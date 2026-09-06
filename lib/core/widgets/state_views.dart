import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import 'app_buttons.dart';
import 'app_card.dart';
import 'spark_mascot.dart';

/// Shared empty-state used across Home, Achievements, Leaderboard, etc.
/// whenever there's genuinely nothing to show yet.
class EmptyStateView extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const EmptyStateView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SparkMascot(size: 88, mood: SparkMood.thinking),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Shared error-state with retry — used whenever content fails to load.
/// Mirrors [EmptyStateView]'s structure (mascot, not a bare icon) so the
/// two no-longer read as two unrelated designs.
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SparkMascot(size: 88, mood: SparkMood.sad),
          const SizedBox(height: AppSpacing.lg),
          Text('Something went wrong', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(label: 'Try again', onPressed: onRetry, icon: Icons.refresh_rounded),
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextButton(label: secondaryActionLabel!, onPressed: onSecondaryAction),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loading block — a shimmering placeholder rectangle. The
/// shimmer is a moving highlight band (via [ShaderMask]) rather than a
/// same-hue pulse, which was previously a ~4%-luminance flicker and
/// effectively invisible. Ambient-guarded: with the OS "remove
/// animations" setting on, it renders as a static base-colored block.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder;
    final highlight = isDark ? AppColors.darkBorder : AppColors.lightBg;

    final box = Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: base,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      ),
    );

    if (!AppMotion.ambientEnabled(context)) return box;

    return AnimatedBuilder(
      animation: _controller,
      child: box,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1 + t * 3, 0),
              end: Alignment(0 + t * 3, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}

/// A skeleton shaped like [AppCard] — used while a card-shaped section
/// is loading, so the placeholder matches the eventual layout instead of
/// being a generic grey slab.
class SkeletonCard extends StatelessWidget {
  final double height;

  const SkeletonCard({super.key, this.height = 88});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            SkeletonBox(height: 40, width: 40, borderRadius: BorderRadius.circular(12)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 14, width: 140),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(height: 12, width: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical run of [SkeletonCard]s.
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const SkeletonList({super.key, this.count = 3, this.itemHeight = 88});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          SkeletonCard(height: itemHeight),
        ],
      ],
    );
  }
}

/// A skeleton shaped like a path lesson node — a circle plus a caption
/// line — for the Path screen's initial loading state.
class SkeletonPathNode extends StatelessWidget {
  final double size;

  const SkeletonPathNode({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SkeletonBox(height: size, width: size, borderRadius: BorderRadius.circular(size / 2)),
        const SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 11, width: size * 0.9),
      ],
    );
  }
}

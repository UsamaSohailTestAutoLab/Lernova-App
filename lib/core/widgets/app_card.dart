import 'package:flutter/material.dart';

import '../theme/app_decor.dart';
import '../theme/app_radius_ext.dart';
import '../theme/app_spacing.dart';

/// - [plain] — today's default: surface color, hairline border, no shadow.
/// - [outlined] — transparent fill, a stronger border. Ghost/secondary cards.
/// - [tinted] — a brightness-correct wash of [AppCard.tint] (via
///   [AppDecor.tint]) — replaces hardcoded `*Light` color literals.
/// - [raised] — a lifted surface with a real shadow, for content that
///   should sit above the page rather than blend into it.
/// - [gradient] — a saturated hero card (continue-learning, celebration).
///   Callers are responsible for using light text on top of it.
enum AppCardVariant { plain, outlined, tinted, raised, gradient }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// Visual treatment. Defaults to [AppCardVariant.plain], which
  /// reproduces this widget's pre-redesign pixels exactly.
  final AppCardVariant variant;

  /// The hue driving [AppCardVariant.tinted]/[AppCardVariant.gradient].
  /// Defaults to the theme's primary color.
  final Color? tint;

  final double radius;

  /// Explicit shadow override. Null means "the variant's default" —
  /// none for plain/outlined/tinted, [AppDecor.shadowMd] for
  /// raised/gradient.
  final List<BoxShadow>? elevation;

  final bool showBorder;

  /// Optional slots rendered outside the card's own tap/ripple area.
  final Widget? header;
  final Widget? footer;

  /// A small badge overlaid at the top-right corner (e.g. "Lv 5", a lock).
  final Widget? badge;

  /// Gamified press-depth feedback, matching the button system. Only
  /// takes effect when [onTap] is set.
  final bool pressScale;

  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.borderColor,
    this.variant = AppCardVariant.plain,
    this.tint,
    this.radius = AppRadius.card,
    this.elevation,
    this.showBorder = true,
    this.header,
    this.footer,
    this.badge,
    this.pressScale = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColors = context.surfaceColors;
    final decor = context.decor;
    final resolvedTint = tint ?? Theme.of(context).colorScheme.primary;

    Color? bg;
    Gradient? gradient;
    Color border;
    List<BoxShadow> shadow;

    switch (variant) {
      // Plain and tinted carry a resting lift by default. On the dark
      // theme that lift is a faint green glow (see AppShadows.level0),
      // which is what separates a panel from a near-black backdrop —
      // a border alone reads as a hairline drawn on one flat sheet.
      case AppCardVariant.plain:
        bg = color ?? surfaceColors.surface;
        border = borderColor ?? surfaceColors.border;
        shadow = elevation ?? decor.shadowSm;
      case AppCardVariant.outlined:
        bg = color ?? Colors.transparent;
        border = borderColor ?? decor.cardBorderStrong;
        shadow = elevation ?? const [];
      case AppCardVariant.tinted:
        bg = color ?? decor.tint(resolvedTint);
        border = borderColor ?? resolvedTint.withValues(alpha: 0.30);
        shadow = elevation ?? decor.shadowSm;
      case AppCardVariant.raised:
        bg = color ?? decor.cardSurfaceRaised;
        border = borderColor ?? Colors.transparent;
        shadow = elevation ?? decor.shadowMd;
      case AppCardVariant.gradient:
        gradient = color != null
            ? null
            : (tint == null
                ? decor.brandGradient
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [resolvedTint, Color.lerp(resolvedTint, Colors.black, 0.25)!],
                  ));
        bg = color;
        border = borderColor ?? Colors.white.withValues(alpha: 0.18);
        shadow = elevation ?? decor.shadowMd;
    }

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: border) : null,
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: card,
        ),
      );
      if (pressScale) card = _PressableScale(child: card);
    }

    if (header != null || footer != null) {
      card = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header!, const SizedBox(height: AppSpacing.sm)],
          card,
          if (footer != null) ...[const SizedBox(height: AppSpacing.sm), footer!],
        ],
      );
    }

    if (badge != null) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [card, Positioned(top: -8, right: 12, child: badge!)],
      );
    }

    if (semanticLabel != null) {
      card = Semantics(label: semanticLabel, container: true, child: card);
    }

    return card;
  }
}

/// Raw pointer-driven press scale (not a gesture recognizer, so it never
/// competes with the inner [InkWell]'s own tap handling in the gesture
/// arena) — the same technique [PrimaryButton] uses.
class _PressableScale extends StatefulWidget {
  final Widget child;
  const _PressableScale({required this.child});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    lowerBound: 0,
    upperBound: 0.04,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(scale: 1 - _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

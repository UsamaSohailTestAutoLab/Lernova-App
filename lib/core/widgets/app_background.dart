import 'package:flutter/material.dart';

import '../theme/app_decor.dart';
import '../theme/app_motion.dart';

/// - [plain] — the base color only, no bloom. For screens that are
///   themselves full-bleed (splash) or content-dense (Settings lists).
/// - [brand] — a soft green bloom top-trailing, a warm accent bloom
///   bottom-leading. The default "this is Lernova" backdrop.
/// - [journey] — a stronger, taller brand bloom for the Path screen.
/// - [celebration] — a centered, larger bloom for result/reward screens.
/// - [focus] — a single quiet bloom, low contrast, for the lesson player
///   (content must stay the visual lead there).
enum AppBackdrop { plain, brand, journey, celebration, focus }

/// The decorative screen background that replaces the app's flat
/// `#F6FAF6` wash. Deliberately built from [RadialGradient] stops only —
/// no `BackdropFilter`, no `MaskFilter.blur` — those are the two biggest
/// per-frame costs on a low-end device, and gradient stops cost close to
/// nothing by comparison.
class AppBackground extends StatelessWidget {
  final AppBackdrop variant;
  final Color? tint;

  /// Ambient drift of the blooms. Off by default, and should stay off
  /// under a scrolling list (Path, Fun) where a repainting background
  /// is the one place a gradient becomes expensive; fine on static
  /// screens (splash, Pro, celebrations).
  final bool animate;

  final Widget child;

  const AppBackground({
    super.key,
    this.variant = AppBackdrop.brand,
    this.tint,
    this.animate = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == AppBackdrop.plain) {
      return ColoredBox(color: context.decor.backdropBase, child: child);
    }

    return _AnimatedBloomBackdrop(
      variant: variant,
      tint: tint,
      animate: animate,
      child: child,
    );
  }
}

class _AnimatedBloomBackdrop extends StatefulWidget {
  final AppBackdrop variant;
  final Color? tint;
  final bool animate;
  final Widget child;

  const _AnimatedBloomBackdrop({
    required this.variant,
    required this.tint,
    required this.animate,
    required this.child,
  });

  @override
  State<_AnimatedBloomBackdrop> createState() => _AnimatedBloomBackdropState();
}

class _AnimatedBloomBackdropState extends State<_AnimatedBloomBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  bool _ambientChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ambientChecked) {
      _ambientChecked = true;
      if (widget.animate && AppMotion.ambientEnabled(context)) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final topTint = widget.tint ?? decor.backdropTintTop;
    final bottomTint = decor.backdropTintBottom;

    if (!widget.animate) {
      return CustomPaint(
        painter: _BloomPainter(
          variant: widget.variant,
          base: decor.backdropBase,
          topTint: topTint,
          bottomTint: bottomTint,
          drift: 0,
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _BloomPainter(
            variant: widget.variant,
            base: decor.backdropBase,
            topTint: topTint,
            bottomTint: bottomTint,
            drift: _controller.value,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _BloomPainter extends CustomPainter {
  final AppBackdrop variant;
  final Color base;
  final Color topTint;
  final Color bottomTint;
  final double drift;

  _BloomPainter({
    required this.variant,
    required this.base,
    required this.topTint,
    required this.bottomTint,
    required this.drift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final driftPx = drift * size.height * 0.03;

    switch (variant) {
      case AppBackdrop.plain:
        return;
      case AppBackdrop.brand:
        _bloom(canvas, size, const Alignment(0.7, -0.9), size.width * 0.9, topTint, 0.30, driftPx);
        _bloom(canvas, size, const Alignment(-0.8, 0.95), size.width * 0.8, bottomTint, 0.20, -driftPx);
      case AppBackdrop.journey:
        _bloom(canvas, size, const Alignment(0.6, -1.0), size.width * 1.1, topTint, 0.34, driftPx);
        _bloom(canvas, size, const Alignment(-0.7, 0.4), size.width * 0.9, bottomTint, 0.16, -driftPx);
      case AppBackdrop.celebration:
        _bloom(canvas, size, const Alignment(0, -0.4), size.width * 1.3, topTint, 0.32, driftPx);
        _bloom(canvas, size, const Alignment(0, 1.0), size.width * 1.0, bottomTint, 0.22, -driftPx);
      case AppBackdrop.focus:
        _bloom(canvas, size, const Alignment(0.8, -1.0), size.width * 0.7, topTint, 0.18, driftPx);
    }
  }

  void _bloom(
    Canvas canvas,
    Size size,
    Alignment alignment,
    double radius,
    Color color,
    double alpha,
    double driftPx,
  ) {
    final center = alignment.alongSize(size) + Offset(0, driftPx);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _BloomPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.base != base ||
        oldDelegate.topTint != topTint ||
        oldDelegate.bottomTint != bottomTint ||
        oldDelegate.drift != drift;
  }
}

/// The scaffold wrapper every screen adopts in place of a bare
/// `Scaffold`. Composes [AppBackground] behind a transparent `Scaffold`
/// so the app bar (already transparent via the theme) shows the
/// decorative backdrop through it rather than a flat filled rectangle.
///
/// Screens migrate to this one at a time — it changes nothing for a
/// screen that keeps using a plain `Scaffold` directly.
class AppScreen extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final AppBackdrop backdrop;
  final Color? backdropTint;
  final bool animateBackdrop;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;
  final Widget body;

  const AppScreen({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBack = true,
    this.backdrop = AppBackdrop.brand,
    this.backdropTint,
    this.animateBackdrop = false,
    this.bottomBar,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      variant: backdrop,
      tint: backdropTint,
      animate: animateBackdrop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: (title != null || titleWidget != null || actions != null || leading != null)
            ? AppBar(
                automaticallyImplyLeading: showBack,
                leading: leading,
                title: titleWidget ?? (title != null ? Text(title!) : null),
                actions: actions,
              )
            : null,
        body: SafeArea(
          child: Padding(padding: padding, child: body),
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

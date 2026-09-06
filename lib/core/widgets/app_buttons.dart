import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_decor.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

enum AppButtonSize { small, regular, large }

/// - [brand] — theme default (or explicit [PrimaryButton.backgroundColor]).
/// - [gradient] — [AppDecor.brandGradient] (or a gradient built from
///   [PrimaryButton.backgroundColor] if one is supplied).
/// - [danger] — destructive actions.
/// - [onColor] — white bg / brand fg, for use on top of a colored or
///   gradient card (e.g. the Home continue-learning card).
enum PrimaryButtonVariant { brand, gradient, danger, onColor }

/// Primary CTA button with a press micro-interaction and haptic tap —
/// used for every "main action" across the app.
///
/// [depth] adds a gamified pressed "lip" (the button translates down
/// into a darker shade on press) instead of the plain press-scale.
/// Defaults to `false` so existing call sites are pixel-unchanged;
/// screens opt in explicitly as they're redesigned.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final AppButtonSize size;
  final PrimaryButtonVariant variant;
  final bool expand;
  final bool depth;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.size = AppButtonSize.regular,
    this.variant = PrimaryButtonVariant.brand,
    this.expand = true,
    this.depth = false,
  });

  double get _height => switch (size) {
        AppButtonSize.small => 44,
        AppButtonSize.regular => 56,
        AppButtonSize.large => 64,
      };

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  // Listener observes raw pointer events (not a gesture recognizer), so
  // it never competes with ElevatedButton's own tap recognizer in the
  // gesture arena — unlike an outer GestureDetector, which would win
  // that arena and silently swallow the real onPressed below.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.md);
    final height = widget._height;

    Color? bg = widget.backgroundColor;
    Color? fg = widget.foregroundColor;
    Gradient? gradient;

    switch (widget.variant) {
      case PrimaryButtonVariant.brand:
        break;
      case PrimaryButtonVariant.gradient:
        gradient = widget.backgroundColor == null
            ? decor.brandGradient
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.backgroundColor!,
                  Color.lerp(widget.backgroundColor!, Colors.black, 0.25)!,
                ],
              );
        fg ??= Colors.white;
      case PrimaryButtonVariant.danger:
        bg ??= AppColors.error;
        fg ??= Colors.white;
      case PrimaryButtonVariant.onColor:
        bg ??= Colors.white;
        fg ??= theme.colorScheme.primary;
    }

    final lipColor = switch (widget.variant) {
      PrimaryButtonVariant.onColor => Color.lerp(Colors.white, Colors.black, 0.15)!,
      PrimaryButtonVariant.danger => Color.lerp(AppColors.error, Colors.black, 0.25)!,
      _ => AppColors.primaryDark,
    };

    Widget elevatedButton = ElevatedButton(
      onPressed: _enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: gradient != null ? Colors.transparent : bg,
        foregroundColor: fg,
        elevation: widget.depth ? 0 : null,
        minimumSize: Size(widget.expand ? double.infinity : 0, height),
      ),
      child: widget.isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(widget.label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
    );

    if (gradient != null) {
      elevatedButton = DecoratedBox(
        decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
        child: elevatedButton,
      );
    }

    Widget pressable;
    if (widget.depth) {
      pressable = SizedBox(
        width: widget.expand ? double.infinity : null,
        height: height + 4,
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: lipColor, borderRadius: radius),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 4 * _controller.value),
                  child: child,
                );
              },
              child: SizedBox(height: height, child: elevatedButton),
            ),
          ],
        ),
      );
    } else {
      pressable = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(scale: 1 - _controller.value * 0.05, child: child);
        },
        child: elevatedButton,
      );
    }

    return Listener(
      onPointerDown: _enabled ? (_) => _controller.forward() : null,
      onPointerUp: _enabled ? (_) => _controller.reverse() : null,
      onPointerCancel: _enabled ? (_) => _controller.reverse() : null,
      child: pressable,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AppTextButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      child: Text(label),
    );
  }
}

/// A circular action button — the 88px "press to speak/listen" control,
/// replacing what was previously copy-pasted independently in the
/// listening and speaking exercises.
class CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? foregroundColor;

  /// True while actively recording/playing — swaps to an alert color.
  final bool isActive;

  /// An ambient pulsing ring, guarded by [AppMotion.ambientEnabled].
  final bool pulse;

  final String? label;
  final String? semanticLabel;

  const CircleActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 88,
    this.color,
    this.foregroundColor,
    this.isActive = false,
    this.pulse = false,
    this.label,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color ?? (isActive ? AppColors.error : theme.colorScheme.primary);
    final fg = foregroundColor ?? Colors.white;

    Widget circle = Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: fg, size: size * 0.45),
        ),
      ),
    );

    if (pulse) {
      circle = _PulsingRing(color: bg, size: size, child: circle);
    }

    final button = Semantics(button: true, label: semanticLabel, child: circle);

    if (label == null) return button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 6),
        Text(label!, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _PulsingRing extends StatefulWidget {
  final Color color;
  final double size;
  final Widget child;
  const _PulsingRing({required this.color, required this.size, required this.child});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t).clamp(0.0, 1.0) * 0.35,
              child: Transform.scale(
                scale: 1 + t * 0.4,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// A small tinted-bubble icon button — a brand-consistent alternative to
/// a bare [IconButton].
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? semanticLabel;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 40,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final decor = context.decor;
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: decor.tint(tint),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: tint, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Theme extension exposing surface-level colors that aren't part of
/// Flutter's default [ColorScheme] (secondary surfaces, borders, muted text).
@immutable
class AppSurfaceColors extends ThemeExtension<AppSurfaceColors> {
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textMuted;

  const AppSurfaceColors({
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textMuted,
  });

  @override
  AppSurfaceColors copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textMuted,
  }) {
    return AppSurfaceColors(
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppSurfaceColors lerp(ThemeExtension<AppSurfaceColors>? other, double t) {
    if (other is! AppSurfaceColors) return this;
    return AppSurfaceColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

extension AppSurfaceColorsX on BuildContext {
  AppSurfaceColors get surfaceColors =>
      Theme.of(this).extension<AppSurfaceColors>()!;
}

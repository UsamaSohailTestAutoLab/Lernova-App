import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';

/// Brightness-aware decoration tokens: screen backdrops, card surfaces,
/// shadows, the path trail palette, and the app's three brand gradients.
///
/// This is what lets a widget write `context.decor.tint(AppColors.success)`
/// instead of reaching for the light-only `AppColors.successLight` literal
/// directly — the single fix for every tinted panel that was previously
/// wrong in dark mode.
@immutable
class AppDecor extends ThemeExtension<AppDecor> {
  final Brightness brightness;

  // Screen backdrop (consumed by AppBackground).
  final Color backdropBase;
  final Color backdropTintTop;
  final Color backdropTintBottom;

  // Card system.
  final Color cardSurface;
  final Color cardSurfaceRaised;
  final Color cardBorder;
  final Color cardBorderStrong;

  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

  // Path trail.
  final Color trailTrack;
  final Color trailFilled;
  final Color trailLocked;

  /// primary -> primaryDark. White-safe — the only gradient allowed
  /// under white text/icons.
  final Gradient brandGradient;

  /// primaryVivid -> primary. Decoration-only: primaryVivid is ~2.0:1
  /// against white and fails contrast for text/icon foregrounds.
  final Gradient vividGradient;

  /// accent -> a deeper gold. Pro / perfect-lesson halos.
  final Gradient goldGradient;

  const AppDecor({
    required this.brightness,
    required this.backdropBase,
    required this.backdropTintTop,
    required this.backdropTintBottom,
    required this.cardSurface,
    required this.cardSurfaceRaised,
    required this.cardBorder,
    required this.cardBorderStrong,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.trailTrack,
    required this.trailFilled,
    required this.trailLocked,
    required this.brandGradient,
    required this.vividGradient,
    required this.goldGradient,
  });

  factory AppDecor.light() {
    const brandGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primary, AppColors.primaryDark],
    );
    const vividGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [AppColors.primaryVivid, AppColors.primary],
    );
    const goldGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.accent, Color(0xFFE8B93B)],
    );

    return AppDecor(
      brightness: Brightness.light,
      backdropBase: AppColors.lightBg,
      backdropTintTop: AppColors.green100,
      backdropTintBottom: AppColors.accentLight,
      cardSurface: AppColors.lightSurface,
      cardSurfaceRaised: AppColors.lightSurface,
      cardBorder: AppColors.lightBorder,
      cardBorderStrong: AppColors.green200,
      shadowSm: AppShadows.level0(Brightness.light),
      shadowMd: AppShadows.level1(Brightness.light),
      shadowLg: AppShadows.level2(Brightness.light),
      trailTrack: AppColors.lightSurfaceAlt,
      trailFilled: AppColors.green500,
      trailLocked: AppColors.lightBorder,
      brandGradient: brandGradient,
      vividGradient: vividGradient,
      goldGradient: goldGradient,
    );
  }

  factory AppDecor.dark() {
    const brandGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primary, AppColors.primaryDark],
    );
    const vividGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [AppColors.primaryVivid, AppColors.primary],
    );
    const goldGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.accent, Color(0xFFE8B93B)],
    );

    return AppDecor(
      brightness: Brightness.dark,
      backdropBase: AppColors.darkBg,
      backdropTintTop: AppColors.green800,
      backdropTintBottom: AppColors.accent,
      cardSurface: AppColors.darkSurface,
      cardSurfaceRaised: AppColors.darkSurfaceAlt,
      cardBorder: AppColors.darkBorder,
      cardBorderStrong: AppColors.green800,
      shadowSm: AppShadows.level0(Brightness.dark),
      shadowMd: AppShadows.level1(Brightness.dark),
      shadowLg: AppShadows.level2(Brightness.dark),
      trailTrack: AppColors.darkSurfaceAlt,
      trailFilled: AppColors.green400,
      trailLocked: AppColors.darkBorder,
      brandGradient: brandGradient,
      vividGradient: vividGradient,
      goldGradient: goldGradient,
    );
  }

  /// The correct light/dark surface wash for a semantic color — replaces
  /// hardcoded `successLight`/`accentLight`/`errorLight` literals used
  /// directly in widgets (which are wrong half the time in dark mode).
  /// Recognised brand semantics resolve to their curated pair; anything
  /// else falls back to an alpha blend over [cardSurface].
  Color tint(Color base) {
    final isDark = brightness == Brightness.dark;
    if (base == AppColors.success) {
      return isDark ? AppColors.successLightDark : AppColors.successLight;
    }
    if (base == AppColors.accent || base == AppColors.streak) {
      return isDark ? AppColors.accentLightDark : AppColors.accentLight;
    }
    if (base == AppColors.error || base == AppColors.heart) {
      return isDark ? AppColors.errorLightDark : AppColors.errorLight;
    }
    if (base == AppColors.info) {
      return isDark ? AppColors.infoLightDark : AppColors.infoLight;
    }
    if (base == AppColors.teal) {
      return isDark ? AppColors.tealLightDark : AppColors.tealLight;
    }
    if (base == AppColors.violet) {
      return isDark ? AppColors.violetLightDark : AppColors.violetLight;
    }
    if (base == AppColors.primary || base == AppColors.primaryVivid) {
      return isDark ? AppColors.green900 : AppColors.green100;
    }
    return Color.alphaBlend(base.withValues(alpha: isDark ? 0.20 : 0.12), cardSurface);
  }

  /// The foreground color to pair with [tint]'s output. The curated
  /// tint pairs above were chosen so the saturated brand color itself
  /// reads correctly on its own wash in both themes.
  Color onTint(Color base) => base;

  @override
  AppDecor copyWith({
    Brightness? brightness,
    Color? backdropBase,
    Color? backdropTintTop,
    Color? backdropTintBottom,
    Color? cardSurface,
    Color? cardSurfaceRaised,
    Color? cardBorder,
    Color? cardBorderStrong,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    Color? trailTrack,
    Color? trailFilled,
    Color? trailLocked,
    Gradient? brandGradient,
    Gradient? vividGradient,
    Gradient? goldGradient,
  }) {
    return AppDecor(
      brightness: brightness ?? this.brightness,
      backdropBase: backdropBase ?? this.backdropBase,
      backdropTintTop: backdropTintTop ?? this.backdropTintTop,
      backdropTintBottom: backdropTintBottom ?? this.backdropTintBottom,
      cardSurface: cardSurface ?? this.cardSurface,
      cardSurfaceRaised: cardSurfaceRaised ?? this.cardSurfaceRaised,
      cardBorder: cardBorder ?? this.cardBorder,
      cardBorderStrong: cardBorderStrong ?? this.cardBorderStrong,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      trailTrack: trailTrack ?? this.trailTrack,
      trailFilled: trailFilled ?? this.trailFilled,
      trailLocked: trailLocked ?? this.trailLocked,
      brandGradient: brandGradient ?? this.brandGradient,
      vividGradient: vividGradient ?? this.vividGradient,
      goldGradient: goldGradient ?? this.goldGradient,
    );
  }

  @override
  AppDecor lerp(ThemeExtension<AppDecor>? other, double t) {
    if (other is! AppDecor) return this;
    return AppDecor(
      brightness: t < 0.5 ? brightness : other.brightness,
      backdropBase: Color.lerp(backdropBase, other.backdropBase, t)!,
      backdropTintTop: Color.lerp(backdropTintTop, other.backdropTintTop, t)!,
      backdropTintBottom: Color.lerp(backdropTintBottom, other.backdropTintBottom, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardSurfaceRaised: Color.lerp(cardSurfaceRaised, other.cardSurfaceRaised, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBorderStrong: Color.lerp(cardBorderStrong, other.cardBorderStrong, t)!,
      shadowSm: BoxShadow.lerpList(shadowSm, other.shadowSm, t) ?? shadowSm,
      shadowMd: BoxShadow.lerpList(shadowMd, other.shadowMd, t) ?? shadowMd,
      shadowLg: BoxShadow.lerpList(shadowLg, other.shadowLg, t) ?? shadowLg,
      trailTrack: Color.lerp(trailTrack, other.trailTrack, t)!,
      trailFilled: Color.lerp(trailFilled, other.trailFilled, t)!,
      trailLocked: Color.lerp(trailLocked, other.trailLocked, t)!,
      brandGradient: Gradient.lerp(brandGradient, other.brandGradient, t)!,
      vividGradient: Gradient.lerp(vividGradient, other.vividGradient, t)!,
      goldGradient: Gradient.lerp(goldGradient, other.goldGradient, t)!,
    );
  }
}

extension AppDecorX on BuildContext {
  /// Falls back to a brightness-matched default rather than throwing —
  /// several widget tests pump a bare `MaterialApp()` with no `theme:`
  /// (so no extensions registered) around a single widget, and a
  /// component reaching for decorative tokens shouldn't crash just
  /// because it's being tested in isolation.
  AppDecor get decor {
    final theme = Theme.of(this);
    return theme.extension<AppDecor>() ??
        (theme.brightness == Brightness.dark ? AppDecor.dark() : AppDecor.light());
  }
}

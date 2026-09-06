import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 2-tier elevation system implemented as explicit box shadows so it
/// renders identically regardless of Material elevation tinting.
class AppShadows {
  AppShadows._();

  /// Hairline lift — scroll-aware app bars, resting list rows, and the
  /// default card.
  ///
  /// In dark mode this is a faint *green* glow rather than a black drop
  /// shadow: on a near-black background a black shadow is invisible, so
  /// a panel only reads as lifted if it throws a little light instead.
  static List<BoxShadow> level0(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: AppColors.green500.withValues(alpha: 0.10),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppColors.lightTextPrimary.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// A tight, saturated glow for a single emphasized element (e.g. the
  /// current path node) — deliberately not used for lists of elements,
  /// since a blurred shadow per row is the top per-frame cost on
  /// low-end devices.
  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.35,
    double blurRadius = 16,
    Offset offset = const Offset(0, 6),
  }) {
    return [
      BoxShadow(color: color.withValues(alpha: alpha), blurRadius: blurRadius, offset: offset),
    ];
  }

  static List<BoxShadow> level1(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? Colors.black : AppColors.lightTextPrimary)
            .withValues(alpha: isDark ? 0.35 : 0.06),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> level2(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (isDark ? Colors.black : AppColors.lightTextPrimary)
            .withValues(alpha: isDark ? 0.45 : 0.10),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

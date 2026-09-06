import 'package:flutter/material.dart';

/// Shared durations/curves for every animation added in the visual
/// redesign, plus the one rule that keeps them testable:
/// [ambientEnabled] must gate every looping/ambient animation so a
/// widget test that sets `accessibilityFeaturesTestValue(disableAnimations:
/// true)` gets a tree that actually settles under `pumpAndSettle`.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration emphasis = Duration(milliseconds: 360);
  static const Duration celebrate = Duration(milliseconds: 700);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;

  /// False when the OS "remove animations" accessibility setting is on.
  /// Every ambient/looping animation (idle mascot breathing, background
  /// drift, skeleton shimmer, node halo pulse) must check this before
  /// starting a `repeat()`'d controller.
  static bool ambientEnabled(BuildContext context) {
    return !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  /// Collapses [value] to zero when ambient animation is disabled —
  /// convenient for one-shot durations that should still skip instantly
  /// under the same setting.
  static Duration d(BuildContext context, Duration value) {
    return ambientEnabled(context) ? value : Duration.zero;
  }
}

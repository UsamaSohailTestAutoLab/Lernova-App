/// 4/8pt spacing scale used across the entire app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radius scale. [sm]/[md]/[lg]/[pill] are the original 3-tier scale;
/// [xs] and [xl] extend it outward. [card]/[tile] are semantic aliases —
/// prefer them at call sites so a future scale change is one edit here
/// rather than a find-and-replace.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  /// Cards are rounder than the raw [md] step — the softer corner is a
  /// large part of what makes a panel read as a friendly game surface
  /// rather than a form.
  static const double card = 20;
  static const double tile = sm;
}

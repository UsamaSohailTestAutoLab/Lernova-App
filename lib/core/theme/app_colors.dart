import 'package:flutter/material.dart';

/// Original Lernova color identity — parrot green primary with a warm
/// amber accent for XP/streak.
///
/// [primary] is deliberately a *deep* parrot green rather than the
/// brightest one: white sits on it constantly (buttons, nav, progress)
/// and a vivid green would fail WCAG AA contrast. The bright, saturated
/// end of the palette lives in [primaryVivid], used for accents and
/// fills where nothing is written on top.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF277A1C); // ~5.4:1 with white
  static const Color primaryDark = Color(0xFF1B5A13);
  static const Color primaryVivid = Color(0xFF3FBF2B);
  static const Color primaryLight = Color(0xFFE8F6E3);

  // Full green ramp backing the brand tokens above (green500/700/800 are
  // the same values as primaryVivid/primary/primaryDark — kept as one
  // source of truth so callers can pick a stop this scale doesn't name
  // yet, e.g. a lighter chip fill or a deeper pressed-state lip).
  static const Color green50 = Color(0xFFF2FAF0);
  static const Color green100 = Color(0xFFE8F6E3); // == primaryLight
  static const Color green200 = Color(0xFFCBEBC2);
  static const Color green300 = Color(0xFF9ADB8B);
  static const Color green400 = Color(0xFF6ACF54);
  static const Color green500 = Color(0xFF3FBF2B); // == primaryVivid
  static const Color green600 = Color(0xFF2E9A20);
  static const Color green700 = Color(0xFF277A1C); // == primary
  static const Color green800 = Color(0xFF1B5A13); // == primaryDark
  static const Color green900 = Color(0xFF103C0C);

  static const Color accent = Color(0xFFFFB020);
  static const Color accentLight = Color(0xFFFFF3DA);
  static const Color accentLightDark = Color(0xFF3D3117); // dark-theme tint

  static const Color success = Color(0xFF12B76A);
  static const Color successLight = Color(0xFFE3FBEF);
  static const Color successLightDark = Color(0xFF11301F); // dark-theme tint

  static const Color error = Color(0xFFF04438);
  static const Color errorLight = Color(0xFFFEE7E5);
  static const Color errorLightDark = Color(0xFF3A1A17); // dark-theme tint

  static const Color info = Color(0xFF2E90FA);
  static const Color infoLight = Color(0xFFE3F1FE);
  static const Color infoLightDark = Color(0xFF122A3D);

  static const Color heart = Color(0xFFF04438);
  static const Color gem = Color(0xFF2ED3C6);
  static const Color gemLight = Color(0xFFE0F9F7);
  static const Color gemLightDark = Color(0xFF12302D);
  static const Color streak = Color(0xFFFFB020);
  static const Color violet = Color(0xFF7C5CFF); // Pro-only accent
  static const Color violetLight = Color(0xFFEEE9FF);
  static const Color violetLightDark = Color(0xFF241C3D);

  // Neutrals — light theme. Very slightly green-tinted greys, so the
  // whole surface reads as part of the brand rather than the app being
  // green accents floating on a cool-grey background.
  static const Color lightBg = Color(0xFFF6FAF6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFF5EF);
  static const Color lightBorder = Color(0xFFE2EDE2);
  static const Color lightTextPrimary = Color(0xFF16231A);
  static const Color lightTextSecondary = Color(0xFF5F6D62);
  static const Color lightTextMuted = Color(0xFF9BA89E);

  // Neutrals — dark theme. Deliberately a deep *green*-black rather than
  // a neutral charcoal: the whole surface should read as part of the
  // brand, and cards need to lift off it clearly enough to look like
  // panels rather than tonal shifts in one flat sheet.
  static const Color darkBg = Color(0xFF071108);
  static const Color darkSurface = Color(0xFF0F2013);
  static const Color darkSurfaceAlt = Color(0xFF17301C);
  static const Color darkBorder = Color(0xFF27492F);
  static const Color darkTextPrimary = Color(0xFFF2F7F2);
  static const Color darkTextSecondary = Color(0xFFB4C4B7);
  static const Color darkTextMuted = Color(0xFF7C8F80);

  /// Heading accent on dark surfaces. Gold reads as "premium" against
  /// the green-black far better than white does, and it's the same
  /// amber family already used for XP and streaks.
  static const Color goldHeading = Color(0xFFF5C86B);

  // League tiers
  static const Color leagueBronze = Color(0xFFB08D57);
  static const Color leagueSilver = Color(0xFFA7ADBA);
  static const Color leagueGold = Color(0xFFE8B93B);
  static const Color leagueSapphire = Color(0xFF3D6DF2);
  static const Color leagueEmerald = Color(0xFF1FAE7A);
  static const Color leagueDiamond = Color(0xFF6FE3E8);
}

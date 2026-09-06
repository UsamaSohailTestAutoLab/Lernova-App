import 'package:flutter/material.dart';

/// Type system: "Baloo 2" for display/headings (friendly, rounded,
/// original brand voice), "Inter" for body/UI text. Both are bundled
/// local assets (see pubspec.yaml) rather than fetched via google_fonts
/// at runtime, so headings render correctly on a first launch with no
/// network connection.
///
/// Every style carries a Noto Sans Arabic fallback so Arabic text (which
/// neither Baloo 2 nor Inter can render) doesn't fall back to tofu boxes
/// ahead of interface localization landing. Japanese/CJK fallback is
/// deferred until Noto Sans JP is subsetted and bundled in that same
/// pass — until then CJK text falls back to the platform's own system
/// font, which still renders correctly, just not in this exact face.
class AppTypography {
  AppTypography._();

  static const _display = 'Baloo 2';
  static const _body = 'Inter';
  static const _fallback = ['Noto Sans Arabic'];

  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.15,
      ),
      displayMedium: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.15,
      ),
      // Was undefined and silently fell back to Roboto (notably on the
      // Lernova wordmark) — now a real style between displayMedium and
      // headlineLarge.
      displaySmall: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.15,
      ),
      headlineLarge: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      headlineMedium: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      headlineSmall: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      // Moved from Inter to Baloo 2 — previously the family switch landed
      // between titleLarge (18, Inter) and headlineSmall (20, Baloo 2),
      // two adjacent sizes in two different families. The rule is now
      // "Baloo 2 >= 18 = expressive, Inter <= 16 = UI/reading."
      titleLarge: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      titleMedium: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleSmall: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primaryText,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryText,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryText,
      ),
      labelLarge: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      labelMedium: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondaryText,
      ),
      labelSmall: TextStyle(
        fontFamily: _body,
        fontFamilyFallback: _fallback,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondaryText,
      ),
    );
  }
}

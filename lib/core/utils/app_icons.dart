import 'package:flutter/material.dart';

/// Named icon registry: one semantic meaning maps to exactly one glyph.
/// Before this existed, `Icons.bolt_rounded` alone was used across 7
/// call sites to mean XP, a daily-goal ring, the PRO badge, learning
/// intensity, and an achievement all at once. Call sites migrate to
/// these constants screen by screen rather than all at once — this
/// file is the single source of truth they migrate toward.
class AppIcons {
  AppIcons._();

  static const IconData xp = Icons.bolt_rounded;
  static const IconData streak = Icons.local_fire_department_rounded;

  /// PRO no longer shares [xp]'s bolt — a distinct premium-medal glyph,
  /// consistent with the icon already used on the Pro/Settings screens.
  static const IconData pro = Icons.workspace_premium_rounded;

  /// Daily goal gets its own target glyph rather than sharing [xp].
  static const IconData goal = Icons.track_changes_rounded;

  static const IconData hearts = Icons.favorite_rounded;
  static const IconData league = Icons.shield_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData achievement = Icons.emoji_events_rounded;
  static const IconData level = Icons.military_tech_rounded;

  /// A path "perfect lesson" node — distinct from [achievement]'s trophy.
  static const IconData perfect = Icons.star_rounded;
}

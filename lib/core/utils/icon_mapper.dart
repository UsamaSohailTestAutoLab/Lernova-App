import 'package:flutter/material.dart';

/// Achievement/shop content JSON and catalogs store icons as plain
/// strings so content stays presentation-agnostic; this maps those
/// keys to the concrete Material icon used on screen.
IconData achievementIconFor(String name) {
  switch (name) {
    case 'flag':
      return Icons.flag_rounded;
    case 'local_fire_department':
      return Icons.local_fire_department_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'whatshot':
      return Icons.whatshot_rounded;
    case 'military_tech':
      return Icons.military_tech_rounded;
    case 'emoji_events':
      return Icons.emoji_events_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'record_voice_over':
      return Icons.record_voice_over_rounded;
    case 'speed':
      return Icons.speed_rounded;
    case 'verified':
      return Icons.verified_rounded;
    default:
      // Distinct from the explicit 'emoji_events' case above — an
      // unrecognised achievement key previously fell back to the same
      // trophy glyph as a real 'emoji_events' achievement, making the
      // two indistinguishable.
      return Icons.workspace_premium_rounded;
  }
}

const Map<String, IconData> _lessonIconKeys = {
  'greeting': Icons.waving_hand_rounded,
  'agreement': Icons.thumbs_up_down_rounded,
  'manners': Icons.volunteer_activism_rounded,
  'family': Icons.groups_rounded,
  'food': Icons.restaurant_rounded,
  'table': Icons.local_dining_rounded,
  'numbers': Icons.tag_rounded,
  'directions': Icons.explore_rounded,
  'travel': Icons.flight_takeoff_rounded,
  'essentials': Icons.checklist_rounded,
};

const List<(List<String>, IconData)> _lessonKeywordRules = [
  (['hello', 'greet', 'hola', 'bonjour'], Icons.waving_hand_rounded),
  (['yes', 'no,', 'sorry', 'agree'], Icons.thumbs_up_down_rounded),
  (['polite', 'courtesy', 'manner'], Icons.volunteer_activism_rounded),
  (['family', 'mother', 'father', 'brother', 'sister'], Icons.groups_rounded),
  (['table', 'dinner', 'lunch'], Icons.local_dining_rounded),
  (['food', 'eat', 'meal', 'drink'], Icons.restaurant_rounded),
  (['number', 'count'], Icons.tag_rounded),
  (['direction', 'around', 'navigate'], Icons.explore_rounded),
  (['travel', 'trip', 'airport', 'passport'], Icons.flight_takeoff_rounded),
  (['everyday', 'essential', 'common', 'basic'], Icons.checklist_rounded),
];

/// A stable, visually distinct fallback pool for content with no
/// explicit key and no keyword match — chosen by `lessonId.hashCode` so
/// the same lesson always gets the same icon, and neighbouring lessons
/// are unlikely to collide.
const List<IconData> _iconVarietyPool = [
  Icons.translate_rounded,
  Icons.chat_bubble_outline_rounded,
  Icons.menu_book_rounded,
  Icons.quiz_rounded,
  Icons.spellcheck_rounded,
  Icons.record_voice_over_rounded,
  Icons.language_rounded,
  Icons.auto_stories_rounded,
  Icons.forum_rounded,
  Icons.edit_note_rounded,
  Icons.psychology_rounded,
  Icons.lightbulb_rounded,
  Icons.extension_rounded,
  Icons.celebration_rounded,
  Icons.map_rounded,
  Icons.public_rounded,
];

/// Resolves a lesson's Path icon in three tiers: an explicit
/// `"icon"` key from content JSON, a keyword heuristic over the
/// title/subtitle (so future content needs no code change), then a
/// deterministic pick from [_iconVarietyPool] — never the same generic
/// icon for every lesson, even for content nobody has tagged yet.
IconData lessonIconFor({
  String? iconKey,
  required String lessonId,
  required String title,
  String? subtitle,
}) {
  if (iconKey != null && _lessonIconKeys.containsKey(iconKey)) {
    return _lessonIconKeys[iconKey]!;
  }

  final haystack = '$title ${subtitle ?? ''}'.toLowerCase();
  for (final (keywords, icon) in _lessonKeywordRules) {
    if (keywords.any(haystack.contains)) return icon;
  }

  return _iconVarietyPool[lessonId.hashCode.abs() % _iconVarietyPool.length];
}

const Map<String, IconData> _unitIconKeys = {
  'greeting': Icons.waving_hand_rounded,
  'food': Icons.restaurant_rounded,
  'travel': Icons.flight_takeoff_rounded,
};

/// Same three-tier approach as [lessonIconFor], for unit-level icons.
IconData unitIconFor({String? iconKey, required String unitId, required String title}) {
  if (iconKey != null && _unitIconKeys.containsKey(iconKey)) {
    return _unitIconKeys[iconKey]!;
  }
  final haystack = title.toLowerCase();
  for (final (keywords, icon) in _lessonKeywordRules) {
    if (keywords.any(haystack.contains)) return icon;
  }
  return _iconVarietyPool[unitId.hashCode.abs() % _iconVarietyPool.length];
}


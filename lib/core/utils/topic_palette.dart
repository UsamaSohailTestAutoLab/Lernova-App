import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const Map<String, Color> _unitAccents = {
  'green': AppColors.primary,
  'amber': AppColors.accent,
  'teal': AppColors.gem,
};

/// Resolves a unit's `"accent"` content key to a hue drawn from a small
/// approved set inside the brand palette — units read as visually
/// distinct topics without the app leaving its green identity. Falls
/// back to the brand primary for untagged content.
Color unitAccentFor(String? accentKey) {
  if (accentKey != null && _unitAccents.containsKey(accentKey)) {
    return _unitAccents[accentKey]!;
  }
  return AppColors.primary;
}

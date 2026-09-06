import 'package:flutter/material.dart';

import 'choice_tile.dart';

/// Single-select "radio card" used across onboarding pickers (language,
/// goal, daily XP target). A thin delegate onto [AppChoiceTile] — kept
/// as its own widget so onboarding call sites don't need to change.
class SelectableTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  const SelectableTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return AppChoiceTile(
      label: title,
      secondaryLabel: subtitle,
      leading: leading,
      state: selected ? ChoiceTileState.selected : ChoiceTileState.idle,
      onTap: onTap,
      trailing: selected ? null : Icon(Icons.circle_outlined, color: outline),
    );
  }
}

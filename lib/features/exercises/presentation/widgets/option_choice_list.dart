import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/lesson_session_controller.dart';

/// Shared single-select option list used by Multiple Choice, Listening
/// and Fill-in-the-Blank exercises — tapping an option submits
/// immediately, then locks and color-codes once feedback arrives.
class OptionChoiceList extends StatefulWidget {
  final List<String> options;
  final int correctIndex;
  final ExerciseFeedback feedback;
  final ValueChanged<int> onSelect;

  const OptionChoiceList({
    super.key,
    required this.options,
    required this.correctIndex,
    required this.feedback,
    required this.onSelect,
  });

  @override
  State<OptionChoiceList> createState() => _OptionChoiceListState();
}

class _OptionChoiceListState extends State<OptionChoiceList> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final locked = widget.feedback != ExerciseFeedback.none;

    return Column(
      children: [
        for (var i = 0; i < widget.options.length; i++) ...[
          _OptionTile(
            label: widget.options[i],
            state: _stateFor(i, locked),
            onTap: locked
                ? null
                : () {
                    setState(() => _selected = i);
                    widget.onSelect(i);
                  },
          ),
          if (i != widget.options.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  _OptionState _stateFor(int i, bool locked) {
    if (!locked) {
      return _selected == i ? _OptionState.selected : _OptionState.idle;
    }
    if (i == widget.correctIndex) return _OptionState.correct;
    if (i == _selected) return _OptionState.incorrect;
    return _OptionState.idle;
  }
}

enum _OptionState { idle, selected, correct, incorrect }

class _OptionTile extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionTile({required this.label, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, border, fg) = switch (state) {
      _OptionState.idle => (null, theme.colorScheme.outlineVariant, null),
      _OptionState.selected => (
          theme.colorScheme.primary.withValues(alpha: 0.1),
          theme.colorScheme.primary,
          theme.colorScheme.primary,
        ),
      _OptionState.correct => (AppColors.successLight, AppColors.success, AppColors.success),
      _OptionState.incorrect => (AppColors.errorLight, AppColors.error, AppColors.error),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: state == _OptionState.idle ? 1 : 2),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(color: fg),
        ),
      ),
    );
  }
}

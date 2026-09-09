import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../application/lesson_session_controller.dart';
import 'answer_tile.dart';

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

  /// A, B, C… so every option has a name and the eye has a second
  /// landmark besides the answer text itself.
  static String _badge(int i) => String.fromCharCode(65 + i);

  @override
  Widget build(BuildContext context) {
    final locked = widget.feedback != ExerciseFeedback.none;

    return Column(
      children: [
        for (var i = 0; i < widget.options.length; i++) ...[
          AnswerTile(
            label: widget.options[i],
            badge: _badge(i),
            state: _stateFor(i, locked),
            onTap: locked
                ? null
                : () {
                    setState(() => _selected = i);
                    widget.onSelect(i);
                  },
          ),
          if (i != widget.options.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  AnswerTileState _stateFor(int i, bool locked) {
    if (!locked) {
      return _selected == i ? AnswerTileState.selected : AnswerTileState.idle;
    }
    if (i == widget.correctIndex) return AnswerTileState.correct;
    if (i == _selected) return AnswerTileState.incorrect;
    // Once graded, the options that were never in play step back rather
    // than sitting at full strength beside the two that matter.
    return AnswerTileState.dimmed;
  }
}

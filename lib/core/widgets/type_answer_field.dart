import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_decor.dart';
import '../theme/app_spacing.dart';
import 'app_buttons.dart';

enum TypeAnswerFeedback { none, correct, incorrect }

/// A free-text "type your answer" input with a locked/tinted state once
/// feedback arrives and a "Check" button gated on non-empty input.
/// Promoted out of the Path translation exercise so both Path (via
/// [TypeAnswerFeedback]) and Fun's active-recall interstitial share one
/// implementation instead of two near-identical text fields.
class TypeAnswerField extends StatefulWidget {
  final String hintText;
  final TypeAnswerFeedback feedback;
  final ValueChanged<String> onSubmit;

  const TypeAnswerField({
    super.key,
    this.hintText = 'Type your answer',
    required this.feedback,
    required this.onSubmit,
  });

  @override
  State<TypeAnswerField> createState() => _TypeAnswerFieldState();
}

class _TypeAnswerFieldState extends State<TypeAnswerField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.feedback != TypeAnswerFeedback.none;
    final isCorrect = widget.feedback == TypeAnswerFeedback.correct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: !locked,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            // decor.tint(), not the raw successLight/errorLight literals:
            // those are pale washes for light mode, and a disabled
            // field's grey text on them is unreadable in dark mode.
            fillColor: locked
                ? context.decor.tint(isCorrect ? AppColors.success : AppColors.error)
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onSubmit(v);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!locked)
          PrimaryButton(
            label: 'Check',
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => widget.onSubmit(_controller.text),
          ),
      ],
    );
  }
}

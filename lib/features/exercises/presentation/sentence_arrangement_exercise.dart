import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decor.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';

class SentenceArrangementExercise extends StatefulWidget {
  final SentenceArrangementPayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<List<String>> onSubmit;

  const SentenceArrangementExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onSubmit,
  });

  @override
  State<SentenceArrangementExercise> createState() =>
      _SentenceArrangementExerciseState();
}

class _SentenceArrangementExerciseState extends State<SentenceArrangementExercise> {
  final List<int> _chosen = []; // indices into payload.shuffledChips

  List<int> get _available =>
      List.generate(widget.payload.shuffledChips.length, (i) => i)
          .where((i) => !_chosen.contains(i))
          .toList();

  void _choose(int chipIndex) {
    if (widget.feedback != ExerciseFeedback.none) return;
    setState(() => _chosen.add(chipIndex));
  }

  void _remove(int position) {
    if (widget.feedback != ExerciseFeedback.none) return;
    setState(() => _chosen.removeAt(position));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.feedback != ExerciseFeedback.none;
    final complete = _chosen.length == widget.payload.shuffledChips.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.payload.prompt, style: theme.textTheme.headlineSmall),
        // The sentence to build, in English. Without it the prompt was
        // "Build the sentence" and nothing else — the learner had to
        // guess which sentence was wanted as well as its word order.
        if (widget.payload.translation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.decor.tint(AppColors.primary),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '“${widget.payload.translation}”',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < _chosen.length; i++)
                _Chip(
                  label: widget.payload.shuffledChips[_chosen[i]],
                  onTap: () => _remove(i),
                  filled: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final i in _available)
              _Chip(
                label: widget.payload.shuffledChips[i],
                onTap: () => _choose(i),
                filled: false,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!locked)
          PrimaryButton(
            label: 'Check',
            onPressed: complete
                ? () => widget.onSubmit(
                      _chosen.map((i) => widget.payload.shuffledChips[i]).toList(),
                    )
                : null,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  final VoidCallback onTap;
  final bool filled;

  const _Chip({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary.withValues(alpha: 0.12) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: filled ? AppColors.primary : theme.colorScheme.outlineVariant,
          ),
        ),
        // No per-word English here on purpose. Glossing every chip
        // turned the exercise into copying labels rather than recalling
        // the words — they are taught by the multiple-choice questions
        // earlier in the round instead.
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/type_answer_field.dart';
import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';

enum _Stage { recognize, revealed, recall }

/// Teaches a word in three bounded steps: Recognize (the word is shown
/// *with* its image and the learner picks its English meaning), Reveal
/// (confirmation), then Recall (type the word back, graded through the
/// normal lesson feedback flow like every other exercise).
///
/// The learner is never asked to decode a bare picture: the emoji
/// supports the word rather than standing in for it. Content without
/// English meanings falls back to the older pick-the-word form.
///
/// A wrong pick names the correct answer instead of silently resetting —
/// a miss should teach, not just cost a heart.
class ImageRecognitionExercise extends StatefulWidget {
  final ImageRecognitionPayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<String> onSubmit;

  const ImageRecognitionExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onSubmit,
  });

  @override
  State<ImageRecognitionExercise> createState() => _ImageRecognitionExerciseState();
}

class _ImageRecognitionExerciseState extends State<ImageRecognitionExercise> {
  _Stage _stage = _Stage.recognize;
  late final List<String> _options;
  late final String _correctOption;
  int? _wrongIndex;

  /// True when options are English meanings (the current form); false
  /// for legacy content that still asks the learner to pick the
  /// target-language word.
  bool get _asksMeaning => widget.payload.hasMeaning;

  @override
  void initState() {
    super.initState();
    final payload = widget.payload;
    _correctOption = _asksMeaning ? payload.meaning! : payload.targetWord;
    _options = [
      _correctOption,
      ...(_asksMeaning ? payload.distractorMeanings : payload.distractorWords),
    ]..shuffle();
  }

  void _tapOption(int index) {
    setState(() {
      if (_options[index] == _correctOption) {
        _wrongIndex = null;
        _stage = _Stage.revealed;
      } else {
        // Stays flagged (with the answer named below) until the next
        // attempt, rather than blinking away before it can be read.
        _wrongIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.payload.prompt, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        Center(child: Text(widget.payload.emoji, style: const TextStyle(fontSize: 96))),
        // The word sits with its image from the very first frame — the
        // picture supports the word, it never replaces it. (Legacy
        // content that asks the learner to pick the word still has to
        // withhold it until the reveal, or the answer would be printed
        // on screen.)
        if (_asksMeaning || _stage != _Stage.recognize) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              widget.payload.targetWord,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: _stage == _Stage.recognize ? null : AppColors.success,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        switch (_stage) {
          _Stage.recognize => _buildRecognize(theme),
          _Stage.revealed => _buildRevealed(theme),
          _Stage.recall => _buildRecall(theme),
        },
      ],
    );
  }

  Widget _buildRecognize(ThemeData theme) {
    final missed = _wrongIndex != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legacy content's prompt is generic ("What does this mean?"),
        // so it needs this extra instruction. Meaning-first content
        // already asks the question in its own prompt — repeating it
        // here would print the same sentence twice.
        if (!_asksMeaning) ...[
          Text('Which word means this?', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
        ],
        for (var i = 0; i < _options.length; i++) ...[
          _RecognizeTile(
            label: _options[i],
            wrong: _wrongIndex == i,
            onTap: () => _tapOption(i),
          ),
          if (i != _options.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        if (missed) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Not quite',
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _asksMeaning
                      ? '“${widget.payload.targetWord}” ${widget.payload.emoji} '
                          'means “$_correctOption”. Tap it to carry on.'
                      : '${widget.payload.emoji} is “${widget.payload.targetWord}”. '
                          'Tap it to carry on.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRevealed(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _asksMeaning
                      ? '“${widget.payload.targetWord}” it is — now write what it means.'
                      : '“${widget.payload.targetWord}” it is — now try writing it.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Continue',
          backgroundColor: AppColors.success,
          onPressed: () => setState(() => _stage = _Stage.recall),
        ),
      ],
    );
  }

  Widget _buildRecall(ThemeData theme) {
    // The instruction has to name the language being asked for. In
    // meaning-first content the target word is on screen throughout, so
    // "type the word" would have the learner copy the answer off the
    // screen and then be told the correct answer was the thing they
    // copied. What's actually being recalled there is the meaning.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _asksMeaning
              ? 'Type the English meaning of this word'
              : 'Type the word for this',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        TypeAnswerField(
          hintText: _asksMeaning ? 'Type the meaning in English' : 'Type the word',
          feedback: switch (widget.feedback) {
            ExerciseFeedback.none => TypeAnswerFeedback.none,
            ExerciseFeedback.correct => TypeAnswerFeedback.correct,
            ExerciseFeedback.incorrect => TypeAnswerFeedback.incorrect,
          },
          onSubmit: widget.onSubmit,
        ),
      ],
    );
  }
}

class _RecognizeTile extends StatelessWidget {
  final String label;
  final bool wrong;
  final VoidCallback onTap;

  const _RecognizeTile({required this.label, required this.wrong, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: wrong ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: wrong ? AppColors.errorLight : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: wrong ? AppColors.error : theme.colorScheme.outlineVariant,
            width: wrong ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(color: wrong ? AppColors.error : null),
        ),
      ),
    );
  }
}

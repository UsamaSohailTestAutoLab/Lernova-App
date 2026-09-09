import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'widgets/answer_tile.dart';
import 'widgets/exercise_feedback_panel.dart';
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
          AnswerTile(
            label: _options[i],
            badge: String.fromCharCode(65 + i),
            // After a miss the right answer turns green instead of
            // staying anonymous. It used to be named only in the
            // feedback text, leaving the learner to match a sentence
            // back to a row before they could tap it.
            state: _wrongIndex == i
                ? AnswerTileState.incorrect
                : (missed && _options[i] == _correctOption
                    ? AnswerTileState.correct
                    : AnswerTileState.idle),
            onTap: _wrongIndex == i ? null : () => _tapOption(i),
          ),
          if (i != _options.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        if (missed) ...[
          const SizedBox(height: AppSpacing.lg),
          ExerciseFeedbackPanel(
            isCorrect: false,
            title: 'Not quite',
            message: _asksMeaning
                ? '“${widget.payload.targetWord}” ${widget.payload.emoji} '
                    'means “$_correctOption”.'
                : '${widget.payload.emoji} is “${widget.payload.targetWord}”.',
            // The green tile above is now the instruction, so the hint
            // points at it rather than describing it again.
            hint: 'Tap the green answer to carry on.',
          ),
        ],
      ],
    );
  }

  Widget _buildRevealed(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExerciseSuccessBanner(
          message: _asksMeaning
              ? '“${widget.payload.targetWord}” it is — now write what it means.'
              : '“${widget.payload.targetWord}” it is — now try writing it.',
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
        // Gone once graded — see translation_exercise: an untypable box
        // holding an answer the feedback bar is already stating.
        if (widget.feedback == ExerciseFeedback.none) ...[
          const SizedBox(height: AppSpacing.md),
          TypeAnswerField(
            hintText: _asksMeaning ? 'Type the meaning in English' : 'Type the word',
            feedback: TypeAnswerFeedback.none,
            onSubmit: widget.onSubmit,
          ),
        ],
      ],
    );
  }
}

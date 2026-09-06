import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/similarity.dart';
import '../../../core/utils/string_normalize.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../data/models/exercise.dart';
import '../application/exercise_validator.dart';
import '../application/lesson_session_controller.dart';

enum _SpeakingStage { idle, listening, checking, success, retry }

/// Failures of ANY kind after which the escape hatch appears. Counting
/// only silent failures (as this used to) meant a learner who spoke the
/// wrong word every time never saw Skip at all, and had no way out of
/// the exercise.
const _maxFailedAttempts = 3;

/// Real recording UI backed by real on-device speech recognition
/// ([SttService]) — the recognized text is scored against the target
/// phrase (see [ExerciseValidator]'s fuzzy-match threshold) rather than
/// asking the user to self-report whether they said it correctly.
class SpeakingExercise extends ConsumerStatefulWidget {
  final SpeakingPayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<String> onSubmit;

  /// Gives up on this exercise entirely. Distinct from [onSubmit] with
  /// the target phrase, which would silently grade a skip as a correct
  /// answer, and from submitting a wrong answer, which would re-queue
  /// the exercise and trap the learner all over again.
  final VoidCallback? onSkip;

  const SpeakingExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onSubmit,
    this.onSkip,
  });

  @override
  ConsumerState<SpeakingExercise> createState() => _SpeakingExerciseState();
}

class _SpeakingExerciseState extends ConsumerState<SpeakingExercise> {
  _SpeakingStage _stage = _SpeakingStage.idle;
  String? _recognizedText;
  int _failedAttempts = 0;

  Future<void> _startListening() async {
    setState(() {
      _stage = _SpeakingStage.listening;
      _recognizedText = null;
    });

    final recognized = await ref.read(sttServiceProvider).listenOnce(
          locale: widget.payload.ttsLocale,
        );

    if (!mounted) return;
    setState(() => _stage = _SpeakingStage.checking);

    // A short, perceptible pause so "Checking pronunciation…" registers
    // as a real step rather than flickering past instantly.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (recognized == null || recognized.trim().isEmpty) {
      setState(() {
        _failedAttempts++;
        _recognizedText = null;
        _stage = _SpeakingStage.retry;
      });
      return;
    }

    final similarity = levenshteinSimilarity(
      normalizeForMatch(recognized),
      normalizeForMatch(widget.payload.targetPhrase),
    );
    final passed = similarity >= speakingSimilarityThreshold;

    setState(() {
      _recognizedText = recognized;
      // Counts every kind of failure, not just silence.
      if (!passed) _failedAttempts++;
      _stage = passed ? _SpeakingStage.success : _SpeakingStage.retry;
    });
  }

  void _retry() {
    setState(() => _stage = _SpeakingStage.idle);
  }

  Future<void> _listenToTarget() {
    return ref.read(ttsServiceProvider).speak(
          widget.payload.targetPhrase,
          locale: widget.payload.ttsLocale,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.feedback != ExerciseFeedback.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.payload.prompt, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.payload.targetPhrase, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(widget.payload.translation, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Always available: a learner who can't pronounce it needs
              // to be able to hear it, not just guess repeatedly.
              IconButton.filledTonal(
                onPressed: _listenToTarget,
                icon: const Icon(Icons.volume_up_rounded),
                tooltip: 'Listen',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!locked) ...[
          Center(
            child: GestureDetector(
              onTap: _stage == _SpeakingStage.idle ? _startListening : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _stage == _SpeakingStage.listening ? AppColors.error : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _stage == _SpeakingStage.listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              switch (_stage) {
                _SpeakingStage.idle => 'Tap to speak',
                _SpeakingStage.listening => 'Listening…',
                _SpeakingStage.checking => 'Checking pronunciation…',
                _SpeakingStage.success => '🎉 Excellent!',
                _SpeakingStage.retry => '❌ Try again',
              },
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (_stage == _SpeakingStage.retry) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _recognizedText != null
                  ? 'You said: "$_recognizedText"'
                  : "We didn't catch that.",
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try saying it again.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: 'Try again', onPressed: _retry),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _listenToTarget,
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                label: const Text('Listen to the correct pronunciation'),
              ),
            ),
          ],
          // The way out is offered from the very first failure, and is
          // still there in the idle state. A learner blocked by a
          // microphone, an accent, or background noise must never have to
          // earn their way past a recognizer to continue — the exercise
          // is recorded as missed and shows up in review instead.
          if (widget.onSkip != null &&
              (_stage == _SpeakingStage.retry || _stage == _SpeakingStage.idle)) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: widget.onSkip,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(
                  _failedAttempts >= _maxFailedAttempts
                      ? "Skip this one — we'll bring it back later"
                      : 'Skip this one',
                ),
              ),
            ),
          ],
          if (_stage == _SpeakingStage.success) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Continue',
              onPressed: () => widget.onSubmit(_recognizedText ?? widget.payload.targetPhrase),
            ),
          ],
        ],
      ],
    );
  }
}

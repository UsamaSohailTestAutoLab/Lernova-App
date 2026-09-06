import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/gamification_indicators.dart';
import '../../exercises/application/exercise_labels.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../../exercises/presentation/exercise_type_switcher.dart';
import '../../exercises/presentation/widgets/answer_feedback_bar.dart';
import '../../progress/application/progress_controller.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({super.key});

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  bool _navigatedToCompletion = false;

  Future<void> _confirmExit() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Exit lesson?',
      message: 'Your progress in this lesson will be lost.',
      confirmLabel: 'Exit',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      ref.read(lessonSessionProvider.notifier).reset();
      context.pop();
    }
  }

  /// Running out of hearts is handled inside the session (it ends the
  /// attempt and routes to the results screen). There is no
  /// out-of-hearts screen to push.
  void _onContinue() {
    ref.read(lessonSessionProvider.notifier).continueToNext();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lessonSessionProvider);
    final progress = ref.watch(progressProvider);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (session.isComplete && !_navigatedToCompletion) {
      _navigatedToCompletion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lessonSessionProvider.notifier).finishAndApply();
        if (mounted) context.pushReplacement(AppRoutes.lessonComplete);
      });
    }

    // Navigation above only runs after this frame, so a finished
    // session still builds once with an empty queue — reading
    // `currentExercise` here threw "Bad state: No element" at the end of
    // every single lesson.
    if (session.queue.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final exercise = session.currentExercise;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmExit,
          ),
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: LessonProgressBar(progress: session.progressRatio),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: HeartsChip(hearts: progress.hearts),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: ExerciseTypeSwitcher(
                      key: ValueKey(exercise.id),
                      exercise: exercise,
                      feedback: session.feedback,
                      onAnswer: (answer) =>
                          ref.read(lessonSessionProvider.notifier).submitAnswer(answer),
                      onSkip: () =>
                          ref.read(lessonSessionProvider.notifier).skipCurrent(),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: AnswerFeedbackBar(
                  feedback: session.feedback,
                  correctAnswerLabel:
                      session.feedback == ExerciseFeedback.incorrect
                          ? correctAnswerLabel(exercise)
                          : null,
                  onContinue: _onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

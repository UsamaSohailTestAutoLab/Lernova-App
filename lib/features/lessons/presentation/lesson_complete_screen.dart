import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_metric.dart';
import '../../../core/widgets/celebration_scaffold.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../application/lesson_nav_args.dart';
import 'lesson_review_screen.dart';

/// End-of-attempt results. Three outcomes share one shape:
///
///  * finished with no mistakes — "Perfect lesson!"
///  * finished with mistakes — "Lesson complete!"
///  * ran out of hearts — "Out of hearts", with **Play again** as the
///    primary action. This replaces the old out-of-hearts screen
///    entirely: there is no timer, no ad, no gem refill and nothing to
///    buy, just the results and a way back in.
///
/// Every outcome offers **Review mistakes** whenever there are any.
class LessonCompleteScreen extends ConsumerWidget {
  const LessonCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(lessonSessionProvider);

    if (session == null || session.result == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final answered = session.firstAttempts.length;
    final missed = session.missedAttempts;
    final correct = answered - missed.length;
    final accuracy = answered == 0 ? 1.0 : correct / answered;
    final outOfHearts = session.endedEarly;
    final isPerfect = !outOfHearts && session.isPerfect;

    void playAgain() {
      final lesson = session.lesson;
      final unitIndex = session.unitIndex;
      ref.read(lessonSessionProvider.notifier).reset();
      if (session.isReviewSession || unitIndex < 0) {
        context.pushReplacement(AppRoutes.lessonIntro, extra: 'review');
        return;
      }
      // Straight back through the intro, so the retry gets a freshly
      // reshuffled arrangement and its own full heart budget.
      context.pushReplacement(
        AppRoutes.lessonIntro,
        extra: LessonNavArgs(
          course: session.course,
          unitIndex: unitIndex,
          lessonIndex: _lessonIndexOf(session),
          lesson: lesson,
        ),
      );
    }

    /// Back out of a failed attempt to the level's own start screen.
    ///
    /// Only offered when the attempt ended early: a finished lesson has
    /// XP and a streak waiting behind Continue, and skipping that would
    /// silently drop rewards the learner earned. Running out of hearts
    /// earns none of that, so leaving costs nothing — and without a way
    /// out, the only exit is replaying the level that just beat you.
    void backToLevelStart() {
      final unitIndex = session.unitIndex;
      final lesson = session.lesson;
      ref.read(lessonSessionProvider.notifier).reset();
      if (session.isReviewSession || unitIndex < 0) {
        context.go(AppRoutes.home);
        return;
      }
      context.pushReplacement(
        AppRoutes.lessonIntro,
        extra: LessonNavArgs(
          course: session.course,
          unitIndex: unitIndex,
          lessonIndex: _lessonIndexOf(session),
          lesson: lesson,
        ),
      );
    }

    return CelebrationScaffold(
      onBack: outOfHearts ? backToLevelStart : null,
      headline: outOfHearts
          ? 'Out of hearts'
          : (isPerfect ? 'Perfect lesson!' : 'Lesson complete!'),
      subline: outOfHearts
          ? 'That attempt is over — review what tripped you up, then go again.'
          : null,
      hero: CelebrationHero.mascot,
      mascotMood: outOfHearts
          ? LernovaParrotMood.sad
          : (isPerfect ? LernovaParrotMood.celebrate : LernovaParrotMood.happy),
      intensity: outOfHearts
          ? CelebrationIntensity.none
          : (isPerfect ? CelebrationIntensity.full : CelebrationIntensity.medium),
      accent: outOfHearts ? AppColors.heart : AppColors.primary,
      stats: [
        AppMetricData(
          icon: Icons.percent_rounded,
          color: AppColors.success,
          label: 'Accuracy',
          value: '${(accuracy * 100).round()}%',
        ),
        AppMetricData(
          icon: Icons.check_circle_rounded,
          color: AppColors.primary,
          label: 'Correct',
          value: '$correct',
        ),
        AppMetricData(
          icon: Icons.cancel_rounded,
          color: AppColors.error,
          label: 'Incorrect',
          value: '${missed.length}',
        ),
      ],
      primaryLabel: outOfHearts ? 'Play again' : 'Continue',
      onPrimary: outOfHearts
          ? playAgain
          : () => context.pushReplacement(AppRoutes.xpReward),
      secondaryLabel: missed.isEmpty ? null : 'Review mistakes',
      onSecondary: missed.isEmpty
          ? null
          : () => context.push(
                AppRoutes.lessonReview,
                extra: const LessonReviewArgs(showMissedOnly: true),
              ),
    );
  }

  /// The session doesn't carry a lesson index (it doesn't need one), so
  /// it's recovered from the course for the replay args. -1 if the
  /// lesson can't be located, which the intro screen tolerates.
  int _lessonIndexOf(LessonSessionState session) {
    if (session.unitIndex < 0 || session.unitIndex >= session.course.units.length) {
      return -1;
    }
    return session.course.units[session.unitIndex].lessons
        .indexWhere((l) => l.id == session.lesson.id);
  }
}

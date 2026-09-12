import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../../progress/application/lesson_completion_result.dart';
import '../../progress/application/progress_controller.dart';
import '../../reviews/application/review_prompt_controller.dart';

/// The post-lesson result beats (XP → streak → daily goal → achievement
/// unlock) are each optional depending on what actually happened, so
/// every screen in the chain asks this for where to go next instead of
/// hard-coding a route.
String nextResultRoute(LessonCompletionResult result, {required String afterThis}) {
  const order = [
    AppRoutes.streakResult,
    AppRoutes.dailyGoalResult,
    AppRoutes.achievementUnlock,
  ];
  final startIndex = order.indexOf(afterThis) + 1;
  for (var i = startIndex; i < order.length; i++) {
    final route = order[i];
    if (route == AppRoutes.streakResult && result.streakContinued) return route;
    if (route == AppRoutes.dailyGoalResult && result.dailyGoalJustReached) return route;
    if (route == AppRoutes.achievementUnlock && result.newAchievements.isNotEmpty) {
      return route;
    }
  }
  return AppRoutes.home;
}

/// The single exit from the post-lesson reward chain back to Home, and
/// therefore the one moment in the app where asking for a store review
/// is neither an interruption nor a surprise: the learner has just
/// finished something and is being handed back to the dashboard.
///
/// The request is deliberately made *after* [context.go], so the system
/// sheet — which iOS draws over whatever is frontmost — lands on Home
/// rather than on a reward screen that is being torn down. It is also
/// deliberately not awaited: navigation must not wait on a store, and
/// the platform never reports what the learner did with the prompt.
///
/// [ReviewPromptController] decides whether anything is asked at all.
void finishLessonFlow(WidgetRef ref, BuildContext context) {
  // Read before the reset clears it.
  final result = ref.read(lessonSessionProvider)?.result;
  final lessonsDone = ref.read(progressProvider).totalLessonsCompleted;

  ref.read(lessonSessionProvider.notifier).reset();
  context.go(AppRoutes.home);

  if (result == null) return;
  // Not awaited, and errors swallowed: a store that is unreachable or
  // throws must never keep a learner on a dead screen or crash the app
  // on the way home.
  ref
      .read(reviewPromptProvider)
      .maybeAskAfterLesson(
        result: result,
        totalLessonsCompleted: lessonsDone,
      )
      .catchError((Object _) => ReviewPromptOutcome.storeUnavailable);
}

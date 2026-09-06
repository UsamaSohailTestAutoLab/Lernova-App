import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../exercises/application/lesson_session_controller.dart';
import '../../progress/application/lesson_completion_result.dart';

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

void finishLessonFlow(WidgetRef ref, BuildContext context) {
  ref.read(lessonSessionProvider.notifier).reset();
  context.go(AppRoutes.home);
}

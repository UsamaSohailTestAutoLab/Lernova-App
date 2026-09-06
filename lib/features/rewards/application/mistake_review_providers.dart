import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/course.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/lesson.dart';
import '../../onboarding/application/user_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../../../data/repositories/content_providers.dart';

final mistakeExerciseCountProvider = Provider<int>((ref) {
  return ref.watch(progressProvider).mistakeBank.length;
});

/// Builds a synthetic "review" lesson made only of exercises currently
/// sitting in the mistake bank, pulled from wherever they live in the
/// user's active course.
final reviewLessonProvider = FutureProvider<Lesson?>((ref) async {
  final progress = ref.watch(progressProvider);
  final user = ref.watch(userProvider);
  if (progress.mistakeBank.isEmpty || user.currentCourseId == null) return null;

  final course = await ref.watch(courseByIdProvider(user.currentCourseId!).future);
  if (course == null) return null;

  final exercisesById = <String, Exercise>{};
  for (final unit in course.units) {
    for (final lesson in unit.lessons) {
      for (final exercise in lesson.exercises) {
        exercisesById[exercise.id] = exercise;
      }
    }
  }

  final reviewExercises = progress.mistakeBank.keys
      .map((id) => exercisesById[id])
      .whereType<Exercise>()
      .toList();

  if (reviewExercises.isEmpty) return null;

  return Lesson(
    id: 'review_session',
    title: 'Review Mistakes',
    subtitle: 'Practice the words you missed',
    exercises: reviewExercises,
  );
});

final reviewCourseProvider = FutureProvider<Course?>((ref) async {
  final user = ref.watch(userProvider);
  if (user.currentCourseId == null) return null;
  return ref.watch(courseByIdProvider(user.currentCourseId!).future);
});

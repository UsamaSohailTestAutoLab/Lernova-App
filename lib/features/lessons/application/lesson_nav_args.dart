import '../../../data/models/course.dart';
import '../../../data/models/lesson.dart';

/// Passed as `extra` through go_router to the lesson intro/player
/// routes — avoids re-fetching course content by id on every push.
class LessonNavArgs {
  final Course course;
  final int unitIndex;
  final int lessonIndex;
  final Lesson lesson;
  final bool isReviewSession;

  const LessonNavArgs({
    required this.course,
    required this.unitIndex,
    required this.lessonIndex,
    required this.lesson,
    this.isReviewSession = false,
  });
}

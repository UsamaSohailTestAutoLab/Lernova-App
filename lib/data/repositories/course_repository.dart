import '../models/course.dart';
import '../models/language.dart';

/// Abstract content source. [LocalCourseRepository] reads bundled JSON
/// today; a future `RemoteCourseRepository` can implement this same
/// interface against a real backend with zero UI changes.
abstract class CourseRepository {
  Future<List<Language>> getLanguages();
  Future<List<Course>> getCourses();
  Future<Course?> getCourseByLanguage(String languageId);
  Future<Course?> getCourseById(String courseId);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/service_providers.dart';
import '../models/course.dart';
import '../models/language.dart';

final languagesProvider = FutureProvider<List<Language>>((ref) {
  return ref.watch(courseRepositoryProvider).getLanguages();
});

final coursesProvider = FutureProvider<List<Course>>((ref) {
  return ref.watch(courseRepositoryProvider).getCourses();
});

// Both resolve one course through the repository rather than through
// [coursesProvider]: the catalogue is ten languages now, and a screen
// that needs Spanish should not wait on Japanese being parsed. Only the
// language list actually wants them all.
final courseByIdProvider = FutureProvider.family<Course?, String>(
  (ref, courseId) => ref.watch(courseRepositoryProvider).getCourseById(courseId),
);

final courseByLanguageProvider = FutureProvider.family<Course?, String>(
  (ref, languageId) =>
      ref.watch(courseRepositoryProvider).getCourseByLanguage(languageId),
);

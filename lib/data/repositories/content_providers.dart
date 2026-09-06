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

final courseByIdProvider =
    FutureProvider.family<Course?, String>((ref, courseId) async {
  final courses = await ref.watch(coursesProvider.future);
  for (final course in courses) {
    if (course.id == courseId) return course;
  }
  return null;
});

final courseByLanguageProvider =
    FutureProvider.family<Course?, String>((ref, languageId) async {
  final courses = await ref.watch(coursesProvider.future);
  for (final course in courses) {
    if (course.languageId == languageId) return course;
  }
  return null;
});

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/course.dart';
import '../models/language.dart';
import '../repositories/course_repository.dart';

/// Loads course/language content from bundled JSON assets. Swappable
/// later for a `RemoteCourseRepository` implementing the same interface.
///
/// The set of languages is read from `languages.json` and each course
/// file is found by convention (`course_<id>.json`), so shipping a new
/// language is a matter of adding two assets — never of editing this
/// file. A language whose course asset is missing is skipped rather
/// than crashing the app, which keeps a half-authored language from
/// taking the whole course list down with it.
class LocalCourseRepository implements CourseRepository {
  List<Language>? _languagesCache;
  final Map<String, Course> _courseCache = {};
  bool _loadedAllCourses = false;

  static String courseAssetPath(String languageId) =>
      'assets/data/course_$languageId.json';

  @override
  Future<List<Language>> getLanguages() async {
    if (_languagesCache != null) return _languagesCache!;
    final raw = await rootBundle.loadString('assets/data/languages.json');
    final list = jsonDecode(raw) as List;
    _languagesCache =
        list.map((e) => Language.fromJson(e as Map<String, dynamic>)).toList();
    return _languagesCache!;
  }

  @override
  Future<List<Course>> getCourses() async {
    if (_loadedAllCourses) return _courseCache.values.toList();
    for (final language in await getLanguages()) {
      await _loadCourseForLanguage(language.id);
    }
    _loadedAllCourses = true;
    return _courseCache.values.toList();
  }

  Future<Course?> _loadCourseForLanguage(String languageId) async {
    for (final course in _courseCache.values) {
      if (course.languageId == languageId) return course;
    }
    try {
      final raw = await rootBundle.loadString(courseAssetPath(languageId));
      final course = Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _courseCache[course.id] = course;
      return course;
    } catch (_) {
      // Listed in languages.json but no course authored yet.
      return null;
    }
  }

  @override
  Future<Course?> getCourseByLanguage(String languageId) =>
      _loadCourseForLanguage(languageId);

  @override
  Future<Course?> getCourseById(String courseId) async {
    final cached = _courseCache[courseId];
    if (cached != null) return cached;

    // Course ids are `course_<languageId>` by convention, so the one
    // file can be found directly. Worth the special case: Home and the
    // Path both resolve a course before they can render, and making
    // that wait on parsing every other language's JSON is a startup
    // cost paid by everyone to answer a question about one course.
    if (courseId.startsWith('course_')) {
      final direct = await _loadCourseForLanguage(courseId.substring(7));
      if (direct != null && direct.id == courseId) return direct;
    }

    final courses = await getCourses();
    for (final course in courses) {
      if (course.id == courseId) return course;
    }
    return null;
  }
}

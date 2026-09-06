import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/course.dart';
import '../models/language.dart';
import '../repositories/course_repository.dart';

/// Loads course/language content from bundled JSON assets. Swappable
/// later for a `RemoteCourseRepository` implementing the same interface.
class LocalCourseRepository implements CourseRepository {
  List<Language>? _languagesCache;
  final Map<String, Course> _courseCache = {};

  static const _courseAssetPaths = [
    'assets/data/course_es.json',
    'assets/data/course_fr.json',
  ];

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
    if (_courseCache.length == _courseAssetPaths.length) {
      return _courseCache.values.toList();
    }
    for (final path in _courseAssetPaths) {
      final raw = await rootBundle.loadString(path);
      final course = Course.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _courseCache[course.id] = course;
    }
    return _courseCache.values.toList();
  }

  @override
  Future<Course?> getCourseByLanguage(String languageId) async {
    final courses = await getCourses();
    for (final course in courses) {
      if (course.languageId == languageId) return course;
    }
    return null;
  }

  @override
  Future<Course?> getCourseById(String courseId) async {
    final courses = await getCourses();
    for (final course in courses) {
      if (course.id == courseId) return course;
    }
    return null;
  }
}

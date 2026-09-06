import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/utils/icon_mapper.dart';
import 'package:lernova/data/models/course.dart';

Course _loadCourse(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return Course.fromJson(json);
}

void main() {
  final es = _loadCourse('assets/data/course_es.json');
  final fr = _loadCourse('assets/data/course_fr.json');
  final courses = [es, fr];

  group('lessonIconFor', () {
    test('every bundled lesson resolves to an icon', () {
      for (final course in courses) {
        for (final unit in course.units) {
          for (final lesson in unit.lessons) {
            final icon = lessonIconFor(
              iconKey: lesson.icon,
              lessonId: lesson.id,
              title: lesson.title,
              subtitle: lesson.subtitle,
            );
            expect(icon, isNotNull, reason: '${lesson.id} produced no icon');
          }
        }
      }
    });

    test('no two lessons within the same unit share an icon', () {
      for (final course in courses) {
        for (final unit in course.units) {
          final icons = unit.lessons
              .map((l) => lessonIconFor(
                    iconKey: l.icon,
                    lessonId: l.id,
                    title: l.title,
                    subtitle: l.subtitle,
                  ))
              .toList();
          expect(
            icons.toSet().length,
            icons.length,
            reason: 'unit ${unit.id} has a duplicate lesson icon: $icons',
          );
        }
      }
    });

    test('an unrecognised lesson still varies across different ids', () {
      final iconA = lessonIconFor(lessonId: 'zzz_unknown_a', title: 'Mystery A');
      final iconB = lessonIconFor(lessonId: 'zzz_unknown_b', title: 'Mystery B');
      final iconC = lessonIconFor(lessonId: 'zzz_unknown_c', title: 'Mystery C');
      expect({iconA, iconB, iconC}.length, greaterThan(1));
    });

    test('resolution is stable across repeated calls', () {
      final first = lessonIconFor(lessonId: 'es_u1_l1', title: 'Say Hello', subtitle: 'x');
      final second = lessonIconFor(lessonId: 'es_u1_l1', title: 'Say Hello', subtitle: 'x');
      expect(first, second);
    });

    test('an explicit icon key wins over a keyword match', () {
      // Without a key, "Family dinner" keyword-matches 'family' first.
      final byKeyword = lessonIconFor(lessonId: 'x', title: 'Family dinner');
      // With an explicit key, that keyword match is bypassed entirely.
      final byKey = lessonIconFor(iconKey: 'travel', lessonId: 'x', title: 'Family dinner');
      expect(byKey, isNot(byKeyword));
      expect(byKey, lessonIconFor(iconKey: 'travel', lessonId: 'y', title: 'unrelated'));
    });
  });

  group('unitIconFor', () {
    test('every bundled unit resolves to an icon', () {
      for (final course in courses) {
        for (final unit in course.units) {
          final icon = unitIconFor(iconKey: unit.icon, unitId: unit.id, title: unit.title);
          expect(icon, isNotNull, reason: '${unit.id} produced no icon');
        }
      }
    });
  });

  group('achievementIconFor', () {
    test('an unrecognised key differs from the explicit emoji_events key', () {
      expect(achievementIconFor('totally_unknown_key'), isNot(achievementIconFor('emoji_events')));
    });
  });
}

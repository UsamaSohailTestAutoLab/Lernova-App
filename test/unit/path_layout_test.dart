import 'package:flutter/widgets.dart' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/data/models/course.dart';
import 'package:lernova/data/models/course_unit.dart';
import 'package:lernova/data/models/lesson.dart';
import 'package:lernova/features/course/application/path_layout.dart';

Course _buildCourse() {
  Lesson lesson(String id) => Lesson(id: id, title: id, subtitle: '', exercises: const []);
  return Course(
    id: 'course_test',
    languageId: 'es',
    title: 'Test Course',
    description: '',
    placementQuestions: const [],
    units: [
      CourseUnit(id: 'u0', title: 'Unit 0', description: '', lessons: [
        lesson('u0_l0'),
        lesson('u0_l1'),
        lesson('u0_l2'),
      ]),
      CourseUnit(id: 'u1', title: 'Unit 1', description: '', lessons: [
        lesson('u1_l0'),
        lesson('u1_l1'),
      ]),
    ],
  );
}

void main() {
  final course = _buildCourse();

  group('PathLayout.flatten', () {
    test('emits a banner before each unit, then one node per lesson, in order', () {
      final items = PathLayout.flatten(course);
      expect(items.length, 2 + 3 + 2); // 2 banners + 3 + 2 lessons

      expect(items[0], isA<PathUnitBanner>());
      expect((items[0] as PathUnitBanner).unitIndex, 0);
      expect(items[1], isA<PathNodeItem>());
      expect((items[1] as PathNodeItem), predicate<PathNodeItem>((n) => n.unitIndex == 0 && n.lessonIndex == 0));
      expect((items[2] as PathNodeItem).lessonIndex, 1);
      expect((items[3] as PathNodeItem).lessonIndex, 2);
      expect(items[4], isA<PathUnitBanner>());
      expect((items[4] as PathUnitBanner).unitIndex, 1);
      expect((items[5] as PathNodeItem).lessonIndex, 0);
      expect((items[6] as PathNodeItem).lessonIndex, 1);
    });
  });

  group('PathLayout.indexForLesson', () {
    test('finds the flattened index for a given unit/lesson pair', () {
      final items = PathLayout.flatten(course);
      expect(PathLayout.indexForLesson(items, 0, 0), 1);
      expect(PathLayout.indexForLesson(items, 1, 1), 6);
    });

    test('returns null for a lesson that does not exist', () {
      final items = PathLayout.flatten(course);
      expect(PathLayout.indexForLesson(items, 5, 0), isNull);
    });
  });

  group('PathLayout.offsetForIndex', () {
    test('is zero at the first item and grows by each item\'s own height', () {
      final items = PathLayout.flatten(course);
      expect(PathLayout.offsetForIndex(0, items), 0);
      expect(
        PathLayout.offsetForIndex(1, items),
        PathLayout.bannerHeight + PathLayout.bannerGap,
      );
      expect(
        PathLayout.offsetForIndex(2, items),
        PathLayout.bannerHeight + PathLayout.bannerGap + PathLayout.nodeRowHeight,
      );
    });
  });

  group('PathGeometry.dxFor', () {
    test('follows a 0, +1, 0, -1 phase pattern scaled by amplitude', () {
      final geometry = PathGeometry.forWidth(400, TextDirection.ltr);
      expect(geometry.dxFor(0), closeTo(0, 0.001));
      expect(geometry.dxFor(1), closeTo(geometry.amplitude, 0.001));
      expect(geometry.dxFor(2), closeTo(0, 0.001));
      expect(geometry.dxFor(3), closeTo(-geometry.amplitude, 0.001));
    });

    test('every unit\'s first lesson sits dead center, matching the banner exit point', () {
      final geometry = PathGeometry.forWidth(400, TextDirection.ltr);
      expect(geometry.dxFor(0), 0);
    });

    test('RTL mirrors the sign without changing magnitude', () {
      final ltr = PathGeometry.forWidth(400, TextDirection.ltr);
      final rtl = PathGeometry.forWidth(400, TextDirection.rtl);
      expect(rtl.dxFor(1), -ltr.dxFor(1));
      expect(rtl.amplitude, ltr.amplitude);
    });

    test('amplitude is clamped within [28, 76] across phone and tablet widths', () {
      for (final width in [320.0, 400.0, 840.0]) {
        final geometry = PathGeometry.forWidth(width, TextDirection.ltr);
        expect(geometry.amplitude, greaterThanOrEqualTo(28.0));
        expect(geometry.amplitude, lessThanOrEqualTo(76.0));
      }
    });

    test('amplitude grows with width up to the cap', () {
      final narrow = PathGeometry.forWidth(320, TextDirection.ltr);
      final wide = PathGeometry.forWidth(600, TextDirection.ltr);
      expect(wide.amplitude, greaterThanOrEqualTo(narrow.amplitude));
    });
  });
}

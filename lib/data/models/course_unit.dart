import 'lesson.dart';

class CourseUnit {
  final String id;
  final String title;
  final String description;
  final List<Lesson> lessons;

  /// Optional content-side icon/accent keys, resolved by `unitIconFor`/
  /// `unitAccentFor` in icon_mapper.dart. See [Lesson.icon] for why
  /// these are nullable rather than required.
  final String? icon;
  final String? accent;

  const CourseUnit({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
    this.icon,
    this.accent,
  });

  factory CourseUnit.fromJson(Map<String, dynamic> json) {
    return CourseUnit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String?,
      accent: json['accent'] as String?,
      lessons: (json['lessons'] as List)
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

import 'exercise.dart';

class Lesson {
  final String id;
  final String title;
  final String subtitle;
  final List<Exercise> exercises;

  /// Optional content-side icon key (e.g. `"greeting"`, `"family"`),
  /// resolved to a concrete glyph by `lessonIconFor` in icon_mapper.dart.
  /// Null is fine — the resolver falls back to a keyword heuristic over
  /// [title]/[subtitle], then a stable per-id pick, so older content
  /// with no `"icon"` key still gets a distinct icon rather than one
  /// generic glyph everywhere.
  final String? icon;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.exercises,
    this.icon,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      icon: json['icon'] as String?,
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

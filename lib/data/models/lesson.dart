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

  /// Extra vocabulary the Review Words step should teach, beyond the one
  /// word each exercise is keyed to.
  ///
  /// A lesson's questions use more language than its `vocabId`s name: a
  /// sentence like "El aeropuerto está cerca" is keyed to *aeropuerto*
  /// alone, so "cerca" reached the learner for the first time as part of
  /// a question they were being graded on. Listing those supporting
  /// words here means the review step covers everything the lesson
  /// actually puts on screen. Empty is valid — the derived-from-exercises
  /// behaviour is unchanged for content that doesn't set it.
  final List<String> reviewVocabIds;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.exercises,
    this.icon,
    this.reviewVocabIds = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      icon: json['icon'] as String?,
      reviewVocabIds: (json['reviewVocabIds'] as List? ?? const []).cast<String>(),
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

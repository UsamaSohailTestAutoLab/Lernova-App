import 'course_unit.dart';

class PlacementQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final int unlocksUnitIndex;

  const PlacementQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.unlocksUnitIndex,
  });

  factory PlacementQuestion.fromJson(Map<String, dynamic> json) {
    return PlacementQuestion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      options: (json['options'] as List).cast<String>(),
      correctIndex: json['correctIndex'] as int,
      unlocksUnitIndex: json['unlocksUnitIndex'] as int,
    );
  }
}

class Course {
  final String id;
  final String languageId;
  final String title;
  final String description;
  final List<CourseUnit> units;
  final List<PlacementQuestion> placementQuestions;

  const Course({
    required this.id,
    required this.languageId,
    required this.title,
    required this.description,
    required this.units,
    required this.placementQuestions,
  });

  int get totalLessons => units.fold(0, (sum, u) => sum + u.lessons.length);

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      languageId: json['languageId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      units: (json['units'] as List)
          .map((e) => CourseUnit.fromJson(e as Map<String, dynamic>))
          .toList(),
      placementQuestions: (json['placementQuestions'] as List? ?? [])
          .map((e) => PlacementQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

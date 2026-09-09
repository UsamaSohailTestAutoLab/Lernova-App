import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/features/exercises/application/exercise_labels.dart';

import '../support/course_assets.dart';

/// Types whose correct answer is in the language being learned and whose
/// question never states the English. Getting one wrong shows
/// "Correct answer: El aeropuerto está cerca" — which teaches word order
/// and nothing else unless the content also carries the meaning.
const _needsGloss = {
  ExerciseType.listening,
  ExerciseType.sentenceArrangement,
  ExerciseType.fillInTheBlank,
  ExerciseType.speaking,
};

void main() {
  final courses = loadAllCourseAssets().map((a) => a.course).toList();

  Iterable<Exercise> allExercises() sync* {
    for (final course in courses) {
      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          yield* lesson.exercises;
        }
      }
    }
  }

  group('authored content', () {
    test('every target-language answer ships an English meaning', () {
      final missing = <String>[
        for (final e in allExercises())
          if (_needsGloss.contains(e.type) && correctAnswerMeaning(e) == null)
            '${e.id} (${e.type.name})',
      ];
      expect(
        missing,
        isEmpty,
        reason: 'these would tell the learner the answer without its meaning',
      );
    });

    test('a gloss is never just the answer repeated back', () {
      for (final e in allExercises()) {
        final meaning = correctAnswerMeaning(e);
        if (meaning == null) continue;
        expect(
          meaning.text.toLowerCase(),
          isNot(correctAnswerLabel(e).toLowerCase()),
          reason: '${e.id} glosses its answer with itself',
        );
      }
    });

    test('types answered in English are not glossed redundantly', () {
      for (final e in allExercises()) {
        if (e.type == ExerciseType.translation ||
            e.type == ExerciseType.multipleChoice ||
            e.type == ExerciseType.wordMatching) {
          expect(correctAnswerMeaning(e), isNull, reason: '${e.id} needs no gloss');
        }
      }
    });
  });
}

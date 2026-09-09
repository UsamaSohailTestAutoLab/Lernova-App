import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/data/models/course.dart';
import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/features/lessons/application/lesson_variant_generator.dart';

import '../support/course_assets.dart';

Iterable<Exercise> _allExercises(Course course) sync* {
  for (final unit in course.units) {
    for (final lesson in unit.lessons) {
      yield* lesson.exercises;
    }
  }
}

void main() {
  final assets = loadAllCourseAssets();
  final courses = assets.map((a) => a.course).toList();
  final spanish = assets.firstWhere((a) => a.languageId == 'es').course;

  // The reported problem: "Yo / tengo / dos / hermanos" is four opaque
  // tokens. The learner knew "brothers" and "two" but had never been
  // told what "Yo tengo" means — pronouns and verbs like "have" are
  // nobody's vocabulary lesson, yet every sentence is built of them.
  //
  // The fix is to *teach* them earlier in the round, not to print the
  // English on the chips: a glossed chip is copied, not recalled.
  group('the words a sentence needs are taught first', () {
    /// Words a beginner is not expected to meet as their own card —
    /// articles and prepositions picked up from context. Spanish is the
    /// only course that reaches this list; `tool/build_courses.mjs`
    /// refuses to emit a generated lesson that would need it.
    const glue = {'a', 'al', 'de', 'del', 'el', 'en', 'la', 'por', 'un', 'una'};

    const properNouns = {
      'ana', 'anna', 'rosa', 'آنا', 'روزا', 'アンナ', 'ローザ', '安娜', '罗莎',
    };

    test('every content word in a sentence appears in its own lesson', () {
      final gaps = <String>[];

      for (final course in assets) {
        final labelById = course.labelById;
        for (final unit in course.course.units) {
          for (final lesson in unit.lessons) {
            // Everything the lesson says elsewhere: prompts, options,
            // audio and review words are all covered by the coverage
            // test — here we only care that the token appears
            // *somewhere* other than the sentence itself.
            final elsewhere = <String>{};
            void add(String? text) {
              if (text != null) elsewhere.addAll(text.toLowerCase().split(' '));
            }

            for (final e in lesson.exercises) {
              switch (e.payload) {
                case MultipleChoicePayload p:
                  p.options.forEach(add);
                case ListeningPayload p:
                  add(p.audioText);
                case WordMatchingPayload p:
                  for (final pair in p.pairs) {
                    add(pair.left);
                  }
                case TranslationPayload p:
                  add(p.sourceText);
                case ImageRecognitionPayload p:
                  add(p.targetWord);
                default:
                  break;
              }
            }
            for (final id in lesson.reviewVocabIds) {
              add(labelById[id]);
            }

            for (final e in lesson.exercises) {
              if (e.payload case SentenceArrangementPayload p) {
                for (final chip in p.correctSentence) {
                  final word = chip.toLowerCase().replaceAll(
                        RegExp(r'[.,!?¡¿،؛؟。、]'),
                        '',
                      );
                  if (word.isEmpty) continue;
                  if (glue.contains(word)) continue;
                  if (properNouns.contains(word)) continue;
                  if (elsewhere.contains(word)) continue;
                  // An inflection of something taught counts —
                  // "hermano" covers "hermanos", "muchas" covers "mucha".
                  if (elsewhere.any((w) =>
                      w.length >= 5 &&
                      word.length >= 5 &&
                      w.substring(0, 5) == word.substring(0, 5))) {
                    continue;
                  }
                  gaps.add('${lesson.id}: "$chip"');
                }
              }
            }
          }
        }
      }

      expect(gaps, isEmpty,
          reason: 'these are ordered before anything teaches them');
    });

    test('the whole sentence is still stated in English', () {
      for (final course in courses) {
        for (final e in _allExercises(course)) {
          if (e.payload case SentenceArrangementPayload p) {
            expect(p.translation, isNotNull, reason: e.id);
          }
        }
      }
    });

    // A sentence with a hole in it is unanswerable if you can't read the
    // rest of it.
    test('fill-in-the-blank sentences carry their English', () {
      for (final course in courses) {
        for (final e in _allExercises(course)) {
          if (e.payload case FillInTheBlankPayload p) {
            expect(p.translation, isNotNull, reason: e.id);
          }
        }
      }
    });
  });

  // Ordering words you have not met yet is a puzzle, not a language
  // exercise. The single-word questions earlier in a round are what
  // teaches them.
  group('sentence building never opens a round', () {
    test('it is held back behind the word-level questions', () {
      for (final course in courses) {
        for (final unit in course.units) {
          for (final lesson in unit.lessons) {
            if (!lesson.exercises
                .any((e) => e.type == ExerciseType.sentenceArrangement)) {
              continue;
            }
            for (var seed = 0; seed < 20; seed++) {
              final ordered = LessonVariantGenerator.shuffleOrder(
                lesson.exercises,
                Random(seed),
              );
              expect(
                ordered.first.type,
                isNot(ExerciseType.sentenceArrangement),
                reason: '${lesson.id} seed $seed opened with a sentence',
              );
              expect(ordered.first.type, isNot(ExerciseType.fillInTheBlank),
                  reason: '${lesson.id} seed $seed');
            }
          }
        }
      }
    });

    test('even when the mistake bank wants to lead with one', () {
      final lesson = spanish.units[2].lessons[0];
      final sentence = lesson.exercises
          .firstWhere((e) => e.type == ExerciseType.sentenceArrangement);

      for (var seed = 0; seed < 20; seed++) {
        final ordered = LessonVariantGenerator.shuffleOrder(
          lesson.exercises,
          Random(seed),
          // Previously-missed exercises normally lead the round.
          prioritizeIds: {sentence.id},
        );
        expect(ordered.first.id, isNot(sentence.id), reason: 'seed $seed');
      }
    });

    test('every exercise still appears exactly once', () {
      final lesson = spanish.units[2].lessons[0];
      final ordered =
          LessonVariantGenerator.shuffleOrder(lesson.exercises, Random(7));

      expect(ordered, hasLength(lesson.exercises.length));
      expect(
        ordered.map((e) => e.id).toSet(),
        lesson.exercises.map((e) => e.id).toSet(),
      );
    });
  });
}

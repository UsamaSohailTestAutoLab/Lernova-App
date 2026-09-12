import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/data/models/exercise.dart';

import '../support/course_assets.dart';

/// Grammatical glue — articles, pronouns, prepositions, copulas and
/// quantifiers. These are picked up from context and are not vocabulary
/// cards anywhere, so a lesson isn't expected to teach them before using
/// them in a sentence.
///
/// Spanish is the only course that needs this list: it is hand-authored.
/// The generated courses satisfy the rule outright — `tool/build_courses.mjs`
/// refuses to emit a lesson containing a word the lesson has not taught,
/// so the exemption is never reached for them.
const _functionWords = {
  'a', 'al', 'con', 'de', 'del', 'el', 'en', 'es', 'esta', 'este', 'la',
  'las', 'lo', 'los', 'me', 'mi', 'mucha', 'mucho', 'muchas', 'muchos',
  'para', 'por', 'que', 'se', 'su', 'te', 'tu', 'un', 'una', 'y', 'yo',
};

/// Names, which carry no meaning to learn — the same two people in
/// every course, written in each script.
const _properNouns = {'ana', 'anna', 'rosa', 'آنا', 'روزا', 'アンナ', 'ローザ', '安娜', '罗莎'};

Set<String> _tokens(String text) => text
    .toLowerCase()
    .split(RegExp(r'[\s.,¿?¡!،؛؟。、]+'))
    .map((t) => t.replaceAll('_', ''))
    .where((t) => t.isNotEmpty)
    .toSet();

void main() {
  final courses = loadAllCourseAssets();

  test('every language ships a course and a vocabulary pool', () {
    expect(courses, isNotEmpty);
    for (final assets in courses) {
      expect(assets.vocab, isNotEmpty, reason: assets.languageId);
      expect(assets.phrases, isNotEmpty, reason: assets.languageId);
    }
  });

  for (final assets in courses) {
    group('${assets.course.title} lesson content', () {
      final course = assets.course;
      final labelById = assets.labelById;

      // Every vocabId that resolves to nothing silently disappears from
      // Review Words — the lesson still asks about the word, it just
      // never teaches it.
      test('every vocabId a lesson references resolves to real vocabulary', () {
        final unresolved = <String>[];
        for (final unit in course.units) {
          for (final lesson in unit.lessons) {
            for (final e in lesson.exercises) {
              // Word-matching sets are keyed to a synthetic id by design;
              // their review cards come from the pairs themselves.
              if (e.type == ExerciseType.wordMatching) continue;
              if (!labelById.containsKey(e.vocabId)) {
                unresolved.add('${e.id} -> ${e.vocabId}');
              }
            }
            for (final id in lesson.reviewVocabIds) {
              if (!labelById.containsKey(id)) {
                unresolved.add('${lesson.id} review -> $id');
              }
            }
          }
        }
        expect(unresolved, isEmpty);
      });

      // The complaint that added this: a lesson's questions used words
      // the Review Words step never showed, so a graded question was the
      // learner's first sighting of the word.
      test('every word a lesson puts on screen is taught by its review set', () {
        final gaps = <String>[];

        for (final unit in course.units) {
          for (final lesson in unit.lessons) {
            final taught = <String>{};
            void teach(String? label) {
              if (label != null) taught.addAll(_tokens(label));
            }

            for (final id in lesson.reviewVocabIds) {
              teach(labelById[id]);
            }
            for (final e in lesson.exercises) {
              final p = e.payload;
              if (p is WordMatchingPayload) {
                for (final pair in p.pairs) {
                  teach(pair.left);
                }
              } else {
                teach(labelById[e.vocabId]);
              }
            }

            final onScreen = <String>{};
            for (final e in lesson.exercises) {
              final p = e.payload;
              switch (p) {
                case SentenceArrangementPayload p:
                  onScreen.addAll(_tokens(p.correctSentence.join(' ')));
                case FillInTheBlankPayload p:
                  onScreen.addAll(_tokens(p.sentenceTemplate));
                  onScreen.addAll(_tokens(p.correctAnswer));
                case SpeakingPayload p:
                  onScreen.addAll(_tokens(p.targetPhrase));
                case ListeningPayload p:
                  onScreen.addAll(_tokens(p.audioText));
                case TranslationPayload p:
                  onScreen.addAll(_tokens(p.sourceText));
                default:
                  break;
              }
            }

            for (final word in onScreen) {
              if (taught.contains(word)) continue;
              if (_functionWords.contains(word)) continue;
              if (_properNouns.contains(word)) continue;
              // An inflection of something taught ("hermano" ->
              // "hermanos", "delicioso" -> "deliciosa") counts as covered.
              if (taught.any((t) => _sharesStem(t, word))) continue;
              gaps.add('${lesson.id}: "$word"');
            }
          }
        }

        expect(gaps, isEmpty,
            reason: 'these reach the learner first as a graded question');
      });

      // A thin review step is the other half of the same complaint.
      test('no lesson teaches fewer than five words', () {
        for (final unit in course.units) {
          for (final lesson in unit.lessons) {
            final ids = {
              ...lesson.reviewVocabIds,
              for (final e in lesson.exercises)
                if (e.payload is! WordMatchingPayload) e.vocabId,
            };
            final pairWords = <String>{
              for (final e in lesson.exercises)
                if (e.payload case WordMatchingPayload p)
                  for (final pair in p.pairs) pair.left.toLowerCase(),
            };
            final cards = <String>{
              ...ids.map((id) => labelById[id]?.toLowerCase()).whereType<String>(),
              ...pairWords,
            };
            expect(cards.length, greaterThanOrEqualTo(5), reason: lesson.id);
          }
        }
      });
    });
  }
}

/// Crude inflection check: same first five letters. Enough to treat
/// plurals and gendered endings as the word they came from without
/// pulling in a stemmer. Deliberately inert for the CJK courses, whose
/// words are shorter than the stem length.
bool _sharesStem(String a, String b) {
  const minStem = 5;
  if (a.length < minStem || b.length < minStem) return false;
  return a.substring(0, minStem) == b.substring(0, minStem);
}

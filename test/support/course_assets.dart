import 'dart:convert';
import 'dart:io';

import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/fun/phrase.dart';
import 'package:lingoquest/data/models/fun/vocab_word.dart';

/// One language's shipped content, loaded straight off disk.
class CourseAssets {
  final String languageId;
  final Course course;
  final List<VocabWord> vocab;
  final List<Phrase> phrases;

  const CourseAssets({
    required this.languageId,
    required this.course,
    required this.vocab,
    required this.phrases,
  });

  /// Everything a lesson can name by id — Fun vocabulary and phrases
  /// share one id space, which is what makes `vocabId` resolvable.
  Map<String, String> get labelById => {
        for (final w in vocab) w.id: w.word,
        for (final p in phrases) p.id: p.phrase,
      };
}

List<T> _load<T>(String path, T Function(Map<String, dynamic>) fromJson) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  return (jsonDecode(file.readAsStringSync()) as List)
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Every course the app ships, discovered from the assets directory
/// rather than listed by hand — a new language is a new file, and the
/// content tests must not need editing for it to be checked.
List<CourseAssets> loadAllCourseAssets() {
  final files = Directory('assets/data')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.replaceAll(r'\', '/').contains('/course_'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (final file in files)
      () {
        final course = Course.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );
        return CourseAssets(
          languageId: course.languageId,
          course: course,
          vocab: _load(
            'assets/data/fun/vocab_${course.languageId}.json',
            VocabWord.fromJson,
          ),
          phrases: _load(
            'assets/data/fun/phrases_${course.languageId}.json',
            Phrase.fromJson,
          ),
        );
      }(),
  ];
}

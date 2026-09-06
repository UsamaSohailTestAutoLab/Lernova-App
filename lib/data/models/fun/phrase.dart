/// A short everyday phrase used by phrase/meaning Fun questions. [id]
/// carries a `_phrase_` marker segment (e.g. `es_phrase_como_estas`) so
/// achievement logic can cheaply tell "phrases mastered" apart from
/// "words mastered" while both still live in the one shared
/// `UserProgress.vocabStrength` map.
class Phrase {
  /// Every phrase id contains this segment (e.g. `es_phrase_como_estas`)
  /// so a plain string check can separate "phrases" from "words" inside
  /// the one shared `vocabStrength` map.
  static const idMarker = '_phrase_';

  final String id;
  final String phrase;
  final String meaning;
  final String languageId;
  final String category;

  const Phrase({
    required this.id,
    required this.phrase,
    required this.meaning,
    required this.languageId,
    required this.category,
  });

  factory Phrase.fromJson(Map<String, dynamic> json) {
    return Phrase(
      id: json['id'] as String,
      phrase: json['phrase'] as String,
      meaning: json['meaning'] as String,
      languageId: json['languageId'] as String,
      category: json['category'] as String,
    );
  }
}

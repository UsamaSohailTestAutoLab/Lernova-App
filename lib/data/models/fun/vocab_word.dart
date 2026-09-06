/// A single Fun-game vocabulary entry. Where a word already exists in a
/// course lesson, [id] intentionally reuses that lesson's `vocabId` so
/// mastery tracked here and mastery tracked in lessons are the same
/// number, not two parallel trackers.
class VocabWord {
  final String id;
  final String word;
  final String translation;
  final String languageId;
  final String category;
  final String? emoji;
  final List<String> synonyms;
  final List<String> antonyms;

  const VocabWord({
    required this.id,
    required this.word,
    required this.translation,
    required this.languageId,
    required this.category,
    this.emoji,
    this.synonyms = const [],
    this.antonyms = const [],
  });

  factory VocabWord.fromJson(Map<String, dynamic> json) {
    return VocabWord(
      id: json['id'] as String,
      word: json['word'] as String,
      translation: json['translation'] as String,
      languageId: json['languageId'] as String,
      category: json['category'] as String,
      emoji: json['emoji'] as String?,
      synonyms: (json['synonyms'] as List? ?? []).cast<String>(),
      antonyms: (json['antonyms'] as List? ?? []).cast<String>(),
    );
  }
}

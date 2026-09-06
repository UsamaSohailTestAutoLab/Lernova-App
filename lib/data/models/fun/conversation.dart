/// One line from the other speaker plus the response options the player
/// can pick for it. [id] feeds the same shared `vocabStrength` map every
/// other Fun mode writes to.
///
/// Every line and every option carries its English meaning alongside the
/// learning-language text. A learner should understand the exchange
/// before being asked to hold up their end of it — picking Spanish
/// replies without knowing what any of them say isn't a conversation,
/// it's pattern matching.
class ConversationTurn {
  final String id;
  final String line;
  final List<String> options;
  final int correctIndex;

  /// English translation of [line]. Null only for older content that
  /// predates the bilingual format; the UI hides the translation row
  /// rather than showing an empty one.
  final String? lineEnglish;

  /// English translations of [options], index-for-index. Empty for
  /// older content.
  final List<String> optionsEnglish;

  const ConversationTurn({
    required this.id,
    required this.line,
    required this.options,
    required this.correctIndex,
    this.lineEnglish,
    this.optionsEnglish = const [],
  });

  String get correctResponse => options[correctIndex];

  /// English for the expected reply, when this turn carries translations.
  String? get correctResponseEnglish => englishFor(correctIndex);

  String? englishFor(int optionIndex) {
    if (optionIndex < 0 || optionIndex >= optionsEnglish.length) return null;
    return optionsEnglish[optionIndex];
  }

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    return ConversationTurn(
      id: json['id'] as String,
      line: json['line'] as String,
      lineEnglish: json['lineEnglish'] as String?,
      options: (json['options'] as List).cast<String>(),
      optionsEnglish: (json['optionsEnglish'] as List?)?.cast<String>() ?? const [],
      correctIndex: json['correctIndex'] as int,
    );
  }
}

class Conversation {
  final String id;
  final String title;
  final String scenario;
  final String languageId;
  final List<ConversationTurn> turns;

  const Conversation({
    required this.id,
    required this.title,
    required this.scenario,
    required this.languageId,
    required this.turns,
  });

  /// True when every turn carries its English translation, i.e. the
  /// bilingual "learn it first" walkthrough can be shown.
  bool get hasTranslations =>
      turns.isNotEmpty && turns.every((t) => t.lineEnglish != null);

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      scenario: json['scenario'] as String,
      languageId: json['languageId'] as String,
      turns: (json['turns'] as List)
          .map((e) => ConversationTurn.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

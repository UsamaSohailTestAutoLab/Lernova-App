class Language {
  final String id;
  final String name;
  final String nativeName;
  final String flagEmoji;

  const Language({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.flagEmoji,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'] as String,
      name: json['name'] as String,
      nativeName: json['nativeName'] as String,
      flagEmoji: json['flagEmoji'] as String,
    );
  }
}

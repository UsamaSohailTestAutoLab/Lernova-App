/// Maps a course/language id onto the TTS locale its words should be
/// spoken in. Kept in one place so every "🔊 Listen" affordance — review
/// cards, exercises, generated Fun questions — pronounces a word in the
/// language the learner actually chose, rather than defaulting to Spanish
/// wherever a locale wasn't threaded through.
class TtsLocales {
  TtsLocales._();

  static const String fallback = 'es-ES';

  static const Map<String, String> _byLanguageId = {
    'es': 'es-ES',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'it': 'it-IT',
    'pt': 'pt-PT',
    'ru': 'ru-RU',
    'ar': 'ar-SA',
    'ja': 'ja-JP',
    'tr': 'tr-TR',
    'en': 'en-US',
  };

  /// Accepts a bare language id ('es'), a full locale ('es-ES', which is
  /// returned unchanged), or null.
  static String forLanguageId(String? languageId) {
    if (languageId == null || languageId.isEmpty) return fallback;
    if (languageId.contains('-')) return languageId;
    return _byLanguageId[languageId.toLowerCase()] ?? fallback;
  }
}

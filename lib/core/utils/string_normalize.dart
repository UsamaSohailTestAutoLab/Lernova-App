/// Fuzzy-enough string matching for free-text answers: trims, lowercases,
/// strips common punctuation/quotes, and collapses whitespace, so "Hola!"
/// and " hola " compare equal. Shared by Path's translation/image-recall
/// validation, Fun's active-recall interstitial, and speech-recognition
/// scoring — one normalization rule everywhere a typed or spoken answer
/// is compared against a target string.
String normalizeForMatch(String s) {
  return s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.,!?¡¿]'), '')
      .replaceAll("'", '')
      .replaceAll('"', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

import 'similarity.dart';

/// Every apostrophe a keyboard might produce.
///
/// Phone keyboards substitute a curly `’` (U+2019) for the straight `'`
/// as you type, while authored content uses the straight one — so
/// "You're welcome" typed on a phone was graded against "You're welcome"
/// from the JSON and came out *wrong*, purely over which glyph the
/// keyboard chose. Stripping the whole family makes the two identical.
final _apostrophes = RegExp(r"['‘’ʼʹ′`´]");

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
      .replaceAll(_apostrophes, '')
      .replaceAll(RegExp(r'["“”]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Below this length a single wrong character is usually a different
/// word, not a typo — "cat"/"car", "yes"/"yet", "six"/"sit" — so short
/// answers are graded exactly.
const _minLengthForTypoTolerance = 8;

/// How close a longer answer has to be. At 0.9, a 13-character phrase
/// may be one character out; a 10-character one must be exact.
const _typoTolerance = 0.9;

/// Whether a typed answer counts as [expected].
///
/// Exact after normalization, or — for answers long enough that one
/// character can't change which word was meant — near enough to be a
/// slip of the finger. "your welcome" for "you're welcome" is someone
/// who knows what *de nada* means and mistyped English; failing them
/// grades English orthography in an app for learning Spanish.
///
/// Deliberately strict for short answers, where a one-character
/// difference is usually a genuinely different answer.
bool matchesTypedAnswer(String typed, String expected) {
  final a = normalizeForMatch(typed);
  final b = normalizeForMatch(expected);
  if (a.isEmpty) return false;
  if (a == b) return true;
  if (b.length < _minLengthForTypoTolerance) return false;
  return levenshteinSimilarity(a, b) >= _typoTolerance;
}

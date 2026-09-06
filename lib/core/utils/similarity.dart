/// How close two already-normalized strings are, as a 0.0-1.0 ratio
/// (1.0 = identical). Used to grade speech-recognition output against a
/// target phrase — spoken text is noisier than typed text (recognizer
/// quirks, missed accents, dropped words), so exact-equality-after-
/// normalize (as [normalizeForMatch] alone gives Translation exercises)
/// is too strict here.
double levenshteinSimilarity(String a, String b) {
  if (a == b) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;

  final distance = _levenshteinDistance(a, b);
  final maxLength = a.length > b.length ? a.length : b.length;
  return 1.0 - (distance / maxLength);
}

int _levenshteinDistance(String a, String b) {
  final rows = a.length + 1;
  final cols = b.length + 1;
  var previous = List<int>.generate(cols, (j) => j);
  var current = List<int>.filled(cols, 0);

  for (var i = 1; i < rows; i++) {
    current[0] = i;
    for (var j = 1; j < cols; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        current[j - 1] + 1, // insertion
        previous[j] + 1, // deletion
        previous[j - 1] + cost, // substitution
      ].reduce((x, y) => x < y ? x : y);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }

  return previous[cols - 1];
}

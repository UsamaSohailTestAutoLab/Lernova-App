import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/utils/similarity.dart';
import 'package:lingoquest/core/utils/string_normalize.dart';

void main() {
  group('levenshteinSimilarity', () {
    test('identical strings score 1.0', () {
      expect(levenshteinSimilarity('hola', 'hola'), 1.0);
    });

    test('an empty string against a non-empty one scores 0.0', () {
      expect(levenshteinSimilarity('', 'hola'), 0.0);
      expect(levenshteinSimilarity('hola', ''), 0.0);
    });

    test('two empty strings score 1.0 (equal, trivially)', () {
      expect(levenshteinSimilarity('', ''), 1.0);
    });

    test('a one-word substitution scores high but not perfect', () {
      final score = levenshteinSimilarity('quiero cafe por favor', 'quiero agua por favor');
      expect(score, greaterThan(0.7));
      expect(score, lessThan(1.0));
    });

    test('a completely different phrase scores low', () {
      final score = levenshteinSimilarity('buenas noches', 'quiero un vaso de agua');
      expect(score, lessThan(0.4));
    });

    test('accent-stripped recognizer output still scores above the speaking threshold', () {
      // Mirrors what real STT often produces: correct words, dropped
      // diacritics — normalizeForMatch alone won't fix this (it only
      // strips punctuation/whitespace/case), so the fuzzy match has to.
      final target = normalizeForMatch('Hola, ¿cómo estás?');
      final spoken = normalizeForMatch('hola como estas');
      expect(levenshteinSimilarity(spoken, target), greaterThanOrEqualTo(0.75));
    });
  });
}

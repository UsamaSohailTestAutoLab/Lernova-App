import 'package:flutter_test/flutter_test.dart';
import 'package:lingoquest/core/utils/string_normalize.dart';

void main() {
  group('normalizeForMatch', () {
    // The reported bug: typing the answer *correctly* was graded wrong.
    // Phone keyboards substitute a curly ’ for the straight ' as you
    // type; authored content uses the straight one, so the two strings
    // differed by one invisible glyph.
    test('every apostrophe a keyboard might produce is equivalent', () {
      const expected = "You're welcome";
      for (final typed in [
        "You're welcome", // straight
        'You’re welcome', // curly — what Gboard actually inserts
        'You‘re welcome', // left single quote
        'Youʼre welcome', // modifier letter apostrophe
        'You`re welcome', // backtick
        'You´re welcome', // acute accent
        'youre welcome', // none at all
        'YOURE WELCOME',
      ]) {
        expect(
          normalizeForMatch(typed),
          normalizeForMatch(expected),
          reason: '"$typed" should grade the same as "$expected"',
        );
      }
    });

    test('curly double quotes are stripped too', () {
      expect(normalizeForMatch('“hola”'), 'hola');
      expect(normalizeForMatch('"hola"'), 'hola');
    });

    test('the existing rules still hold', () {
      expect(normalizeForMatch('  Hola!  '), 'hola');
      expect(normalizeForMatch('¿Cómo   estás?'), 'cómo estás');
    });
  });

  group('matchesTypedAnswer', () {
    test('the reported answer is accepted however it was typed', () {
      for (final typed in [
        "You're welcome",
        'You’re welcome',
        'youre welcome',
        'your welcome', // the common English slip
        '  Your Welcome ',
      ]) {
        expect(
          matchesTypedAnswer(typed, "You're welcome"),
          isTrue,
          reason: '"$typed" means the learner knew what "de nada" means',
        );
      }
    });

    test('a long answer may be one character out', () {
      expect(matchesTypedAnswer('i have a reservaton', 'I have a reservation'), isTrue);
      expect(matchesTypedAnswer('the airport is nearby', 'The airport is nearby'), isTrue);
    });

    // Tolerance is length-gated on purpose: in a short answer a single
    // character is usually a different word, not a typo.
    test('short answers are still graded exactly', () {
      expect(matchesTypedAnswer('car', 'cat'), isFalse);
      expect(matchesTypedAnswer('yet', 'yes'), isFalse);
      expect(matchesTypedAnswer('sit', 'six'), isFalse);
      expect(matchesTypedAnswer('so', 'no'), isFalse);
      expect(matchesTypedAnswer('bread', 'break'), isFalse);
    });

    test('a genuinely wrong answer is still wrong', () {
      expect(matchesTypedAnswer('good morning', "You're welcome"), isFalse);
      expect(matchesTypedAnswer('i have a dog', 'I have a reservation'), isFalse);
      expect(matchesTypedAnswer('', "You're welcome"), isFalse);
      expect(matchesTypedAnswer('   ', "You're welcome"), isFalse);
    });
  });
}

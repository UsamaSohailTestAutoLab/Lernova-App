import 'package:flutter_test/flutter_test.dart';

import 'package:lernova/data/models/user_progress.dart';
import 'package:lernova/features/home/application/motivation_messages.dart';

UserProgress _progress({
  int dailyXp = 0,
  int dailyGoalXp = 20,
  int streakCount = 0,
  Map<String, int> vocabStrength = const {},
}) {
  final today = DateTime.now();
  return UserProgress(
    dailyGoalDate: DateTime(today.year, today.month, today.day),
    lessonsCompletedTodayDate: DateTime(today.year, today.month, today.day),
    weekId: '2026-W36',
    dailyXp: dailyXp,
    dailyGoalXp: dailyGoalXp,
    streakCount: streakCount,
    vocabStrength: vocabStrength,
  );
}

void main() {
  group('what it says reflects where the learner actually is', () {
    test('a met goal is acknowledged, not nagged at', () {
      final lines = MotivationMessages.forProgress(
        _progress(dailyXp: 25),
        courseTitle: 'Spanish',
      );

      expect(lines.first, contains("Today's goal is done"));
      expect(
        lines.any((l) => l.contains('XP to go')),
        isFalse,
        reason: 'a finished goal should never be counted down',
      );
    });

    test('a part-finished goal names what is left', () {
      final lines = MotivationMessages.forProgress(
        _progress(dailyXp: 12, dailyGoalXp: 20),
        courseTitle: 'Spanish',
      );

      expect(lines.any((l) => l.contains('8 XP to go')), isTrue);
    });

    test('an untouched day invites a small start', () {
      final lines = MotivationMessages.forProgress(
        _progress(),
        courseTitle: 'Spanish',
      );

      expect(lines.first, contains('One short lesson'));
    });

    test('a real streak is named; a non-existent one is not', () {
      final withStreak = MotivationMessages.forProgress(
        _progress(streakCount: 9),
        courseTitle: 'Spanish',
      );
      expect(withStreak.any((l) => l.contains('9 days running')), isTrue);

      final withoutStreak = MotivationMessages.forProgress(
        _progress(),
        courseTitle: 'Spanish',
      );
      expect(
        withoutStreak.any((l) => l.contains('in a row') || l.contains('days running')),
        isFalse,
        reason: 'a learner with no streak should not be told about one',
      );
    });

    test('outstanding mistakes are surfaced, with correct pluralisation', () {
      final one = MotivationMessages.forProgress(
        _progress(),
        courseTitle: 'Spanish',
        mistakeCount: 1,
      );
      expect(one.any((l) => l.contains('1 word still shaky')), isTrue);

      final many = MotivationMessages.forProgress(
        _progress(),
        courseTitle: 'Spanish',
        mistakeCount: 4,
      );
      expect(many.any((l) => l.contains('4 words still shaky')), isTrue);
    });

    test('mastered words are only mentioned once there are some', () {
      final few = MotivationMessages.forProgress(
        _progress(vocabStrength: {'a': 5, 'b': 4}),
        courseTitle: 'Spanish',
      );
      expect(few.any((l) => l.contains('mastered')), isFalse);

      final many = MotivationMessages.forProgress(
        _progress(vocabStrength: {for (var i = 0; i < 12; i++) 'w$i': 5}),
        courseTitle: 'Spanish',
      );
      expect(many.any((l) => l.contains('12 words mastered')), isTrue);
    });

    test('the course is named, so the encouragement is not generic', () {
      final lines = MotivationMessages.forProgress(
        _progress(),
        courseTitle: 'French',
      );
      expect(lines.any((l) => l.contains('French')), isTrue);
    });

    // There is always something to say, whatever state the app is in.
    test('never runs out of lines', () {
      for (final progress in [
        _progress(),
        _progress(dailyXp: 100),
        _progress(streakCount: 40, dailyXp: 5),
      ]) {
        final lines = MotivationMessages.forProgress(
          progress,
          courseTitle: 'Spanish',
        );
        expect(lines, isNotEmpty);
        expect(lines.every((l) => l.trim().isNotEmpty), isTrue);
      }
    });
  });

  group('rotation', () {
    final lines = ['a', 'b', 'c'];

    test('cycles in order so the same tick always shows the same line', () {
      expect(MotivationMessages.at(lines, 0), 'a');
      expect(MotivationMessages.at(lines, 1), 'b');
      expect(MotivationMessages.at(lines, 2), 'c');
      expect(MotivationMessages.at(lines, 3), 'a');
      // Deterministic: a rebuild must not flicker between two messages.
      expect(MotivationMessages.at(lines, 7), MotivationMessages.at(lines, 7));
    });

    test('handles a negative tick and an empty pool without throwing', () {
      expect(MotivationMessages.at(lines, -1), 'b');
      expect(MotivationMessages.at(const [], 3), '');
    });
  });
}

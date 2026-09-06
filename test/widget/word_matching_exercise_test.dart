import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/features/exercises/application/lesson_session_controller.dart';
import 'package:lernova/features/exercises/presentation/word_matching_exercise.dart';

const _payload = WordMatchingPayload(
  prompt: 'Match each word to its meaning',
  pairs: [
    WordPair(left: 'Hola', right: 'Hello'),
    WordPair(left: 'Gracias', right: 'Thank you'),
  ],
);

Widget _harness({required ValueChanged<Map<int, int>> onComplete}) {
  return MaterialApp(
    home: Scaffold(
      body: WordMatchingExercise(
        payload: _payload,
        feedback: ExerciseFeedback.none,
        onComplete: onComplete,
      ),
    ),
  );
}

void main() {
  testWidgets('a correct pair turns green and does not complete until every pair is matched',
      (tester) async {
    Map<int, int>? completed;
    await tester.pumpWidget(_harness(onComplete: (m) => completed = m));

    await tester.tap(find.text('Hola'));
    await tester.pump();
    await tester.tap(find.text('Hello'));
    await tester.pump();

    expect(completed, isNull); // only 1 of 2 pairs matched so far

    await tester.tap(find.text('Gracias'));
    await tester.pump();
    await tester.tap(find.text('Thank you'));
    await tester.pump();

    expect(completed, {0: 0, 1: 1});
  });

  testWidgets('a wrong pair is not marked complete and can be retried', (tester) async {
    Map<int, int>? completed;
    await tester.pumpWidget(_harness(onComplete: (m) => completed = m));

    await tester.tap(find.text('Hola'));
    await tester.pump();
    await tester.tap(find.text('Thank you')); // wrong — belongs to Gracias
    await tester.pump();

    // Let the transient wrong-flash revert.
    await tester.pump(const Duration(milliseconds: 600));

    expect(completed, isNull);

    // Retry the correct pair now that it's been released.
    await tester.tap(find.text('Hola'));
    await tester.pump();
    await tester.tap(find.text('Hello'));
    await tester.pump();
    await tester.tap(find.text('Gracias'));
    await tester.pump();
    await tester.tap(find.text('Thank you'));
    await tester.pump();

    expect(completed, {0: 0, 1: 1});
  });
}

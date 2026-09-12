import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/features/exercises/application/exercise_labels.dart';
import 'package:lingoquest/features/exercises/application/lesson_session_controller.dart';
import 'package:lingoquest/features/exercises/presentation/widgets/answer_feedback_bar.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ExerciseFeedback feedback,
  String? label,
  AnswerMeaning? meaning,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AnswerFeedbackBar(
          feedback: feedback,
          correctAnswerLabel: label,
          correctAnswerMeaning: meaning,
          onContinue: () {},
        ),
      ),
    ),
  );
}

void main() {
  // The reported case: "Correct answer: El aeropuerto está cerca" told the
  // learner the word order and nothing about what they had just built.
  testWidgets('a wrong answer in the learning language is shown with its meaning',
      (tester) async {
    await _pump(
      tester,
      feedback: ExerciseFeedback.incorrect,
      label: 'El aeropuerto está cerca',
      meaning: const AnswerMeaning(label: 'Means', text: 'The airport is nearby'),
    );

    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('Correct answer: El aeropuerto está cerca'), findsOneWidget);
    expect(find.text('Means: The airport is nearby'), findsOneWidget);
  });

  // A one-word answer glossed with a whole sentence needs different
  // wording — "abuela" does not *mean* "My grandmother is called Rosa".
  testWidgets('a fragment answer labels its gloss as the full sentence', (tester) async {
    await _pump(
      tester,
      feedback: ExerciseFeedback.incorrect,
      label: 'abuela',
      meaning: const AnswerMeaning(
        label: 'Full sentence',
        text: 'My grandmother is called Rosa',
      ),
    );

    expect(find.text('Correct answer: abuela'), findsOneWidget);
    expect(find.text('Full sentence: My grandmother is called Rosa'), findsOneWidget);
    expect(find.textContaining('Means:'), findsNothing);
  });

  testWidgets('no meaning line where the answer needs no gloss', (tester) async {
    await _pump(
      tester,
      feedback: ExerciseFeedback.incorrect,
      label: 'Hola',
    );

    expect(find.text('Correct answer: Hola'), findsOneWidget);
    expect(find.textContaining('Means:'), findsNothing);
  });

  testWidgets('a correct answer shows neither line', (tester) async {
    await _pump(
      tester,
      feedback: ExerciseFeedback.correct,
      label: 'El aeropuerto está cerca',
      meaning: const AnswerMeaning(label: 'Means', text: 'The airport is nearby'),
    );

    expect(find.text('Nice!'), findsOneWidget);
    expect(find.textContaining('Correct answer:'), findsNothing);
    expect(find.textContaining('Means:'), findsNothing);
  });
}

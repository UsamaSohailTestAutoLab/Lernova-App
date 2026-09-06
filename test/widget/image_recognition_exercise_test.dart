import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/features/exercises/application/lesson_session_controller.dart';
import 'package:lernova/features/exercises/presentation/image_recognition_exercise.dart';

/// Legacy content: no English meanings, so the exercise falls back to
/// asking the learner to pick the target-language word.
const _payload = ImageRecognitionPayload(
  prompt: 'What does this mean?',
  emoji: '👋',
  targetWord: 'Hola',
  distractorWords: ['Gracias', 'Adiós', 'Por favor'],
);

/// Current content: the word is shown with its image and the learner
/// picks the English meaning.
const _meaningPayload = ImageRecognitionPayload(
  prompt: 'What does this word mean?',
  emoji: '👋',
  targetWord: 'Hola',
  meaning: 'Hello',
  distractorMeanings: ['Goodbye', 'Thank you', 'Please'],
  distractorWords: ['Gracias', 'Adiós', 'Por favor'],
);

Future<void> _pump(
  WidgetTester tester, {
  ValueChanged<String>? onSubmit,
  ImageRecognitionPayload payload = _payload,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ImageRecognitionExercise(
            payload: payload,
            feedback: ExerciseFeedback.none,
            onSubmit: onSubmit ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a wrong pick names the correct answer instead of silently resetting',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Gracias'));
    await tester.pumpAndSettle();

    expect(find.text('Not quite'), findsOneWidget);
    expect(find.textContaining('Hola'), findsWidgets, reason: 'must reveal the answer');
    // Still answerable — a miss teaches, it doesn't lock the exercise.
    expect(find.text('Hola'), findsWidgets);
  });

  testWidgets('a correct pick shows the word with the image and waits for Continue',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Hola'));
    await tester.pumpAndSettle();

    // The pairing is taught before it is tested.
    expect(find.text('👋'), findsOneWidget);
    expect(find.textContaining('“Hola” it is'), findsOneWidget);
    // It does not skip ahead on its own.
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Type the word for this'), findsNothing);
  });

  testWidgets('Continue advances to typing the word', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Hola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Type the word for this'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('the typed answer is handed back to the lesson', (tester) async {
    String? submitted;
    await _pump(tester, onSubmit: (value) => submitted = value);

    await tester.tap(find.text('Hola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hola');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(submitted, 'Hola');
  });

  group('meaning-first content', () {
    testWidgets('shows the word together with its image, never the image alone',
        (tester) async {
      await _pump(tester, payload: _meaningPayload);

      // Both visible on the very first frame — the icon supports the
      // word rather than being a puzzle the learner has to decode.
      expect(find.text('👋'), findsOneWidget);
      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('What does this word mean?'), findsOneWidget);
    });

    testWidgets('offers English meanings as the options', (tester) async {
      await _pump(tester, payload: _meaningPayload);

      for (final meaning in ['Hello', 'Goodbye', 'Thank you', 'Please']) {
        expect(find.text(meaning), findsOneWidget, reason: '$meaning should be an option');
      }
      // The Spanish distractors are not the choices any more.
      expect(find.text('Gracias'), findsNothing);
    });

    testWidgets('a wrong meaning names the right one and stays answerable', (tester) async {
      await _pump(tester, payload: _meaningPayload);

      await tester.tap(find.text('Goodbye'));
      await tester.pumpAndSettle();

      expect(find.text('Not quite'), findsOneWidget);
      expect(find.textContaining('means “Hello”'), findsOneWidget);
      expect(find.text('Hello'), findsWidgets);
    });

    // The word is on screen from the first frame in meaning-first
    // content, so asking the learner to type it back would be copying —
    // and the app would then announce that the correct answer was the
    // word it had been showing them all along. What is actually recalled
    // here is the meaning, and the instruction says so.
    testWidgets('the recall step asks for the English meaning, not the word', (tester) async {
      String? submitted;
      await _pump(
        tester,
        payload: _meaningPayload,
        onSubmit: (value) => submitted = value,
      );

      await tester.tap(find.text('Hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Type the English meaning of this word'), findsOneWidget);
      expect(find.text('Type the word for this'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(submitted, 'Hello');
    });
  });
}

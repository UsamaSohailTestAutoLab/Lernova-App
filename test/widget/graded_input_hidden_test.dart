import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/core/widgets/type_answer_field.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/features/exercises/application/lesson_session_controller.dart';
import 'package:lingoquest/features/exercises/presentation/image_recognition_exercise.dart';
import 'package:lingoquest/features/exercises/presentation/translation_exercise.dart';

const _translation = TranslationPayload(
  prompt: 'Type the English meaning of this word',
  sourceText: 'Cinco',
  acceptableAnswers: ['five'],
);

const _image = ImageRecognitionPayload(
  prompt: 'What does this word mean?',
  emoji: '✅',
  targetWord: 'Sí',
  meaning: 'Yes',
  distractorMeanings: ['No'],
  distractorWords: ['No'],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Reported: after a wrong answer the input stayed on screen as a pale
  // slab — untypable, its text unreadable against the fill, and holding
  // a copy of an answer the feedback bar below already states.
  group('a graded typing question drops its input', () {
    testWidgets('translation: field is there to answer, gone once graded',
        (tester) async {
      await _pump(
        tester,
        const TranslationExercise(
          payload: _translation,
          feedback: ExerciseFeedback.none,
          onSubmit: _noop,
        ),
      );
      expect(find.byType(TypeAnswerField), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);

      await _pump(
        tester,
        const TranslationExercise(
          payload: _translation,
          feedback: ExerciseFeedback.incorrect,
          onSubmit: _noop,
        ),
      );
      expect(find.byType(TypeAnswerField), findsNothing);
      expect(find.byType(TextField), findsNothing);
      // The question itself stays — the feedback is read against it.
      expect(find.text('Cinco'), findsOneWidget);
    });

    testWidgets('and on a correct answer too', (tester) async {
      await _pump(
        tester,
        const TranslationExercise(
          payload: _translation,
          feedback: ExerciseFeedback.correct,
          onSubmit: _noop,
        ),
      );
      expect(find.byType(TypeAnswerField), findsNothing);
    });

    testWidgets('image recall: same rule', (tester) async {
      await _pump(
        tester,
        const ImageRecognitionExercise(
          payload: _image,
          feedback: ExerciseFeedback.incorrect,
          onSubmit: _noop,
        ),
      );
      // The recall stage is only reached after the recognize stage, but
      // whichever stage is showing, no dead input is left behind.
      expect(find.byType(TextField), findsNothing);
    });
  });
}

void _noop(String _) {}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/features/exercises/application/lesson_session_controller.dart';
import 'package:lingoquest/features/exercises/presentation/exercise_type_switcher.dart';
import 'package:lingoquest/features/exercises/presentation/widgets/answer_feedback_bar.dart';

Course _testCourse() {
  final exercises = [
    Exercise(
      id: 'e0',
      type: ExerciseType.multipleChoice,
      vocabId: 'v0',
      payload: const MultipleChoicePayload(
        prompt: 'Which word means Hello?',
        options: ['Hola', 'Adiós'],
        correctIndex: 0,
      ),
    ),
  ];
  final lesson = Lesson(id: 'l0', title: 'Lesson', subtitle: '', exercises: exercises);
  return Course(
    id: 'c0',
    languageId: 'es',
    title: 'Course',
    description: '',
    placementQuestions: const [],
    units: [CourseUnit(id: 'u0', title: 'Unit', description: '', lessons: [lesson])],
  );
}

class _Harness extends ConsumerStatefulWidget {
  const _Harness();
  @override
  ConsumerState<_Harness> createState() => _HarnessState();
}

class _HarnessState extends ConsumerState<_Harness> {
  @override
  void initState() {
    super.initState();
    final course = _testCourse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lessonSessionProvider.notifier).start(
            course: course,
            unitIndex: 0,
            lesson: course.units[0].lessons[0],
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lessonSessionProvider);
    if (session == null) return const SizedBox.shrink();
    return Scaffold(
      body: Column(
        children: [
          ExerciseTypeSwitcher(
            exercise: session.currentExercise,
            feedback: session.feedback,
            onAnswer: (a) => ref.read(lessonSessionProvider.notifier).submitAnswer(a),
          ),
          AnswerFeedbackBar(
            feedback: session.feedback,
            onContinue: () => ref.read(lessonSessionProvider.notifier).continueToNext(),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('selecting the correct multiple-choice option shows correct feedback', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: const MaterialApp(home: _Harness()),
      ),
    );
    await tester.pump();

    expect(find.text('Which word means Hello?'), findsOneWidget);
    expect(find.text('Nice!'), findsNothing);

    await tester.tap(find.text('Hola'));
    await tester.pump();

    expect(find.text('Nice!'), findsOneWidget);
  });

  testWidgets('selecting the wrong option shows incorrect feedback with the right answer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: const MaterialApp(home: _Harness()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Adiós'));
    await tester.pump();

    expect(find.text('Not quite'), findsOneWidget);
  });
}

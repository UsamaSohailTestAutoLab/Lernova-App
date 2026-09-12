import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/data/models/last_activity.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/data/models/user_progress.dart';
import 'package:lingoquest/features/exercises/application/lesson_session_controller.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';

Exercise _mc(String id) => Exercise(
      id: id,
      type: ExerciseType.multipleChoice,
      vocabId: 'v_$id',
      payload: const MultipleChoicePayload(
        prompt: 'p',
        options: ['a', 'b'],
        correctIndex: 0,
      ),
    );

final _course = Course(
  id: 'course_es',
  languageId: 'es',
  title: 'Spanish',
  description: '',
  placementQuestions: const [],
  units: [
    CourseUnit(
      id: 'u0',
      title: 'Greetings & Basics',
      description: '',
      lessons: [
        Lesson(id: 'l0', title: 'Say Hello', subtitle: '', exercises: [_mc('e0')]),
        Lesson(id: 'l1', title: 'Yes, No, Sorry', subtitle: '', exercises: [_mc('e1')]),
      ],
    ),
  ],
);

void main() {
  group('serialization', () {
    test('a Path activity survives a round trip', () {
      final activity = LastActivity.pathLesson(
        at: DateTime(2026, 9, 6, 10, 30),
        courseId: 'course_es',
        lessonId: 'es_u1_l1',
        unitIndex: 0,
        lessonIndex: 0,
        title: 'Say Hello',
        subtitle: 'Greetings & Basics',
      );

      final restored = LastActivity.fromJson(activity.toJson())!;

      expect(restored.kind, LastActivityKind.pathLesson);
      expect(restored.lessonId, 'es_u1_l1');
      expect(restored.unitIndex, 0);
      expect(restored.title, 'Say Hello');
      expect(restored.at, activity.at);
    });

    test('a Fun activity survives a round trip', () {
      final activity = LastActivity.funGame(
        at: DateTime(2026, 9, 6, 11),
        funModeName: 'fallingWords',
        funLevel: 3,
        title: 'Word Bubble',
        subtitle: 'Level 3',
      );

      final restored = LastActivity.fromJson(activity.toJson())!;

      expect(restored.kind, LastActivityKind.funGame);
      expect(restored.funModeName, 'fallingWords');
      expect(restored.funLevel, 3);
    });

    // A broken resume pointer must never be the thing that stops Home
    // from loading.
    test('malformed or missing data reads back as null, not a crash', () {
      expect(LastActivity.fromJson(null), isNull);
      expect(LastActivity.fromJson({}), isNull);
      expect(LastActivity.fromJson({'kind': 'pathLesson'}), isNull);
      expect(LastActivity.fromJson({'kind': 'notAKind', 'at': '2026-09-06'}), isNull);
      expect(LastActivity.fromJson({'kind': 'funGame', 'at': 'not-a-date'}), isNull);
    });

    test('it rides along with the rest of UserProgress', () {
      final progress = UserProgress.initial(weekId: '2026-W36').copyWith(
        lastActivity: LastActivity.funGame(
          at: DateTime(2026, 9, 6),
          funModeName: 'wordRush',
          funLevel: 2,
          title: 'Word Rush',
          subtitle: 'Level 2',
        ),
      );

      final restored = UserProgress.fromJson(progress.toJson());

      expect(restored.lastActivity?.funModeName, 'wordRush');
      expect(restored.lastActivity?.kind, LastActivityKind.funGame);
    });

    test('progress saved before this feature existed still loads', () {
      final json = UserProgress.initial(weekId: '2026-W36').toJson()
        ..remove('lastActivity');
      expect(UserProgress.fromJson(json).lastActivity, isNull);
    });
  });

  group('recording', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
    });

    // Recorded on start, not on completion: the session worth resuming is
    // precisely the one that was abandoned.
    test('starting a lesson records it immediately', () {
      container.read(lessonSessionProvider.notifier).start(
            course: _course,
            unitIndex: 0,
            lesson: _course.units[0].lessons[1],
          );

      final activity = container.read(progressProvider).lastActivity!;
      expect(activity.kind, LastActivityKind.pathLesson);
      expect(activity.lessonId, 'l1');
      expect(activity.unitIndex, 0);
      expect(activity.lessonIndex, 1);
      expect(activity.title, 'Yes, No, Sorry');
      expect(activity.subtitle, 'Greetings & Basics');
    });

    test('a review session is not what "continue learning" resumes', () {
      container.read(progressProvider.notifier).noteActivityStarted(
            LastActivity.funGame(
              at: DateTime.now(),
              funModeName: 'fallingWords',
              funLevel: 1,
              title: 'Word Bubble',
              subtitle: 'Level 1',
            ),
          );

      container.read(lessonSessionProvider.notifier).start(
            course: _course,
            unitIndex: -1,
            lesson: _course.units[0].lessons[0],
            isReviewSession: true,
          );

      // Practice detours leave the resume pointer alone.
      expect(
        container.read(progressProvider).lastActivity?.kind,
        LastActivityKind.funGame,
      );
    });

    test('the most recent activity wins, whichever side it was on', () {
      container.read(lessonSessionProvider.notifier).start(
            course: _course,
            unitIndex: 0,
            lesson: _course.units[0].lessons[0],
          );
      expect(
        container.read(progressProvider).lastActivity?.kind,
        LastActivityKind.pathLesson,
      );

      container.read(progressProvider.notifier).noteActivityStarted(
            LastActivity.funGame(
              at: DateTime.now(),
              funModeName: 'memoryMatch',
              funLevel: 4,
              title: 'Memory Match',
              subtitle: 'Level 4',
            ),
          );
      expect(
        container.read(progressProvider).lastActivity?.kind,
        LastActivityKind.funGame,
      );

      container.read(lessonSessionProvider.notifier).start(
            course: _course,
            unitIndex: 0,
            lesson: _course.units[0].lessons[1],
          );
      expect(
        container.read(progressProvider).lastActivity?.kind,
        LastActivityKind.pathLesson,
      );
    });

    test('it survives an app restart', () async {
      container.read(progressProvider.notifier).noteActivityStarted(
            LastActivity.funGame(
              at: DateTime.now(),
              funModeName: 'fallingWords',
              funLevel: 2,
              title: 'Word Bubble',
              subtitle: 'Level 2',
            ),
          );

      // A fresh container over the same storage is the closest thing to
      // relaunching the app.
      final storage = await LocalStorageService.create();
      final reopened = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(reopened.dispose);

      final activity = reopened.read(progressProvider).lastActivity;
      expect(activity?.kind, LastActivityKind.funGame);
      expect(activity?.funModeName, 'fallingWords');
      expect(activity?.funLevel, 2);
    });
  });
}

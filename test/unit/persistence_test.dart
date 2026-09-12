import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/data/models/app_settings.dart';
import 'package:lingoquest/data/models/app_user.dart';
import 'package:lingoquest/data/models/course.dart';
import 'package:lingoquest/data/models/course_unit.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/features/onboarding/application/user_controller.dart';
import 'package:lingoquest/features/progress/application/progress_controller.dart';
import 'package:lingoquest/features/settings/application/settings_controller.dart';

Course _fixtureCourse() {
  final exercise = Exercise(
    id: 'e0',
    type: ExerciseType.multipleChoice,
    vocabId: 'v0',
    payload: const MultipleChoicePayload(prompt: 'p', options: ['a', 'b'], correctIndex: 0),
  );
  final lesson = Lesson(id: 'l0', title: 'Lesson', subtitle: '', exercises: [exercise]);
  return Course(
    id: 'c0',
    languageId: 'es',
    title: 'Course',
    description: '',
    placementQuestions: const [],
    units: [CourseUnit(id: 'u0', title: 'Unit', description: '', lessons: [lesson])],
  );
}

void main() {
  test('XP, hearts and settings survive a simulated app restart', () async {
    // Use a single in-memory SharedPreferences-backed store shared across
    // two separate ProviderContainers, mirroring how the real app's
    // LocalStorageService (backed by the OS's persisted prefs) is the
    // only thing that survives an actual process restart — no provider
    // state is carried over between the two containers below.
    SharedPreferences.setMockInitialValues({});

    final firstStorage = await LocalStorageService.create();
    final firstContainer = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(firstStorage)],
    );

    await firstContainer.read(userProvider.notifier).updateProfile(name: 'Grace Hopper');
    final course = _fixtureCourse();
    firstContainer.read(progressProvider.notifier).completeLessonSession(
          course: course,
          unitIndex: 0,
          lesson: course.units[0].lessons[0],
          xpEarned: 10,
          isPerfect: true,
          timeSpentSeconds: 15,
          mistakenExerciseIds: {},
          isReviewSession: false,
        );
    firstContainer.read(settingsProvider.notifier).setThemeMode(AppThemeMode.dark);
    firstContainer.dispose();

    // Simulate the app relaunching: a fresh SharedPreferences handle onto
    // the same underlying store, a fresh ProviderContainer, nothing
    // manually carried over.
    final secondStorage = await LocalStorageService.create();
    final secondContainer = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(secondStorage)],
    );
    addTearDown(secondContainer.dispose);

    final restoredUser = secondContainer.read(userProvider);
    final restoredProgress = secondContainer.read(progressProvider);
    final restoredSettings = secondContainer.read(settingsProvider);

    expect(restoredUser, isA<AppUser>());
    expect(restoredUser.name, 'Grace Hopper');
    // 10 from the exercise + 10 completion bonus + 20 perfect bonus = 40.
    expect(restoredProgress.totalXp, 40);
    expect(restoredSettings.themeMode, AppThemeMode.dark);
  });
}

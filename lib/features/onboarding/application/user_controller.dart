import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/services/service_providers.dart';
import '../../../data/models/app_user.dart';

/// The single local learner profile. There are no accounts and no
/// sign-in: the app opens straight into learning, and this holds the
/// preferences the rest of the app reads — chosen language, current
/// course, learning goal, display name.
///
/// [build] never returns null. Every screen that reads the profile
/// (Home, Path, Fun) assumes one exists, so a fresh install gets a
/// default profile rather than a null the UI would have to guard.
class UserController extends Notifier<AppUser> {
  @override
  AppUser build() {
    final stored = ref.read(localStorageServiceProvider).loadUser();
    return stored ?? _defaultProfile();
  }

  static AppUser _defaultProfile() => AppUser(
        id: 'local',
        name: 'Learner',
        email: '',
        avatarSeed: 'Learner',
        joinedAt: DateTime.now(),
      );

  Future<void> selectLanguage(String languageId) => _update(
        (u) => u.copyWith(selectedLanguageId: languageId),
      );

  Future<void> setLearningGoal(LearningGoal goal) => _update(
        (u) => u.copyWith(learningGoal: goal),
      );

  Future<void> setCurrentCourse(String courseId) => _update(
        (u) => u.copyWith(currentCourseId: courseId),
      );

  Future<void> updateProfile({String? name, String? email}) =>
      _update((u) => u.copyWith(name: name, email: email));

  Future<void> _update(AppUser Function(AppUser) updater) async {
    final next = updater(state);
    state = next;
    await ref.read(localStorageServiceProvider).saveUser(next);
  }
}

final userProvider = NotifierProvider<UserController, AppUser>(UserController.new);

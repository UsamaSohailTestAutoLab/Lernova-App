import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/services/service_providers.dart';
import '../../../data/repositories/content_providers.dart';
import '../../progress/application/progress_controller.dart';
import 'user_controller.dart';

class OnboardingSelections {
  final String? languageId;
  final LearningGoal learningGoal;
  final DailyGoalXp dailyGoal;
  final int? placementUnlockedUnitIndex;
  final bool placementCompleted;

  const OnboardingSelections({
    this.languageId,
    this.learningGoal = LearningGoal.regular,
    this.dailyGoal = DailyGoalXp.twenty,
    this.placementUnlockedUnitIndex,
    this.placementCompleted = false,
  });

  OnboardingSelections copyWith({
    String? languageId,
    LearningGoal? learningGoal,
    DailyGoalXp? dailyGoal,
    int? placementUnlockedUnitIndex,
    bool? placementCompleted,
  }) {
    return OnboardingSelections(
      languageId: languageId ?? this.languageId,
      learningGoal: learningGoal ?? this.learningGoal,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      placementUnlockedUnitIndex:
          placementUnlockedUnitIndex ?? this.placementUnlockedUnitIndex,
      placementCompleted: placementCompleted ?? this.placementCompleted,
    );
  }
}

/// Transient in-memory state for the onboarding wizard — nothing here
/// is persisted until [finish] provisions the real user/course/progress
/// records, so backing out of onboarding never leaves half-saved state.
class OnboardingController extends Notifier<OnboardingSelections> {
  @override
  OnboardingSelections build() => const OnboardingSelections();

  void setLanguage(String languageId) {
    state = state.copyWith(languageId: languageId);
  }

  void setLearningGoal(LearningGoal goal) {
    state = state.copyWith(learningGoal: goal);
  }

  void setDailyGoal(DailyGoalXp goal) {
    state = state.copyWith(dailyGoal: goal);
  }

  void setPlacementResult(int unlockedUnitIndex) {
    state = state.copyWith(
      placementUnlockedUnitIndex: unlockedUnitIndex,
      placementCompleted: true,
    );
  }

  void skipPlacement() {
    state = state.copyWith(placementUnlockedUnitIndex: 0, placementCompleted: true);
  }

  Future<void> finish() async {
    final languageId = state.languageId;
    if (languageId == null) {
      throw StateError('Cannot finish onboarding without a selected language');
    }

    final course = await ref.read(courseByLanguageProvider(languageId).future);
    if (course == null) {
      throw StateError('No course found for language $languageId');
    }

    final userController = ref.read(userProvider.notifier);
    await userController.selectLanguage(languageId);
    await userController.setLearningGoal(state.learningGoal);
    await userController.setCurrentCourse(course.id);

    ref.read(progressProvider.notifier).initializeForOnboarding(
          dailyGoalXp: state.dailyGoal.xp,
          unlockedUnitIndex: state.placementUnlockedUnitIndex ?? 0,
        );

    await ref.read(localStorageServiceProvider).setOnboardingComplete(true);
    ref.invalidate(isOnboardingCompleteProvider);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingSelections>(
  OnboardingController.new,
);

final isOnboardingCompleteProvider = Provider<bool>((ref) {
  return ref.watch(localStorageServiceProvider).isOnboardingComplete();
});

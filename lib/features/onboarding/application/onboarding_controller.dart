import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/analytics/analytics_providers.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/services/service_providers.dart';
import '../../../data/repositories/content_providers.dart';
import '../../progress/application/progress_controller.dart';
import 'user_controller.dart';

class OnboardingSelections {
  /// Collected in the first step and written to the profile by [finish].
  final String? fullName;

  final String? languageId;
  final LearningGoal learningGoal;
  final DailyGoalXp dailyGoal;
  final int? placementUnlockedUnitIndex;
  final bool placementCompleted;

  const OnboardingSelections({
    this.fullName,
    this.languageId,
    this.learningGoal = LearningGoal.regular,
    this.dailyGoal = DailyGoalXp.twenty,
    this.placementUnlockedUnitIndex,
    this.placementCompleted = false,
  });

  OnboardingSelections copyWith({
    String? fullName,
    String? languageId,
    LearningGoal? learningGoal,
    DailyGoalXp? dailyGoal,
    int? placementUnlockedUnitIndex,
    bool? placementCompleted,
  }) {
    return OnboardingSelections(
      fullName: fullName ?? this.fullName,
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

  /// Fires once, on the first thing the learner does in first-run.
  ///
  /// Guarded rather than emitted from the welcome screen's `build`,
  /// which runs again on every rebuild and would report a dozen starts
  /// for one install.
  void _noteStarted() {
    if (_startedNoted) return;
    _startedNoted = true;
    ref.read(analyticsProvider).onboardingStarted();
  }

  bool _startedNoted = false;

  void setFullName(String name) {
    _noteStarted();
    ref.read(analyticsProvider).onboardingStep('name');
    state = state.copyWith(fullName: name.trim());
  }

  void setLanguage(String languageId) {
    _noteStarted();
    final analytics = ref.read(analyticsProvider);
    analytics.onboardingStep('language');
    analytics.languageSelected(languageId, source: 'onboarding');
    // Set immediately rather than at the end of the flow: somebody who
    // abandons onboarding halfway still had a language in mind, and
    // that is exactly the cohort worth being able to see.
    analytics.setLanguage(languageId);
    state = state.copyWith(languageId: languageId);
  }

  void setLearningGoal(LearningGoal goal) {
    ref.read(analyticsProvider).onboardingStep('goal');
    state = state.copyWith(learningGoal: goal);
  }

  void setDailyGoal(DailyGoalXp goal) {
    ref.read(analyticsProvider).onboardingStep('daily_goal');
    state = state.copyWith(dailyGoal: goal);
  }

  void setPlacementResult(int unlockedUnitIndex) {
    ref.read(analyticsProvider).onboardingStep('placement_taken');
    state = state.copyWith(
      placementUnlockedUnitIndex: unlockedUnitIndex,
      placementCompleted: true,
    );
  }

  void skipPlacement() {
    ref.read(analyticsProvider).onboardingStep('placement_skipped');
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
    // The name is written before anything else so every screen that
    // greets the learner has it from the first frame after onboarding.
    // Falls back to the default profile name rather than writing an
    // empty string if this somehow ran without the name step.
    final name = state.fullName?.trim();
    if (name != null && name.isNotEmpty) {
      await userController.setFullName(name);
    }
    await userController.selectLanguage(languageId);
    await userController.setLearningGoal(state.learningGoal);
    await userController.setCurrentCourse(course.id);

    ref.read(progressProvider.notifier).initializeForOnboarding(
          dailyGoalXp: state.dailyGoal.xp,
          unlockedUnitIndex: state.placementUnlockedUnitIndex ?? 0,
          languageId: languageId,
        );

    await ref.read(localStorageServiceProvider).setOnboardingComplete(true);
    final analytics = ref.read(analyticsProvider);
    analytics.onboardingCompleted(language: state.languageId ?? 'unknown');
    analytics.setOnboardingComplete(true);
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

import '../constants/app_enums.dart';
import '../../data/models/pro_entitlement.dart';
import 'analytics_events.dart';
import 'analytics_service.dart';

/// The app's analytics vocabulary, as methods rather than strings.
///
/// Every feature calls one of these; nothing outside this folder names
/// an event or a parameter. That is what keeps the set of things being
/// measured reviewable — it is this file, and `docs/ANALYTICS.md`
/// describes exactly it.
///
/// **Nothing here sends personal data.** No name, no email, no answer
/// text, no lesson content, no store receipt. Ids are the app's own
/// content ids (`es_u1_l1`), which identify a lesson, not a person.
extension Analytics on AnalyticsService {
  // ---- onboarding ------------------------------------------------------

  Future<void> onboardingStarted() =>
      logEvent(AnalyticsEvent.onboardingStarted);

  /// One step of the first-run flow finished. [step] is the screen it
  /// was on, so the funnel can be read without a separate event per
  /// step.
  Future<void> onboardingStep(String step) =>
      logEvent(AnalyticsEvent.onboardingStepCompleted, {
        AnalyticsParam.step: step,
      });

  Future<void> onboardingCompleted({required String language}) =>
      logEvent(AnalyticsEvent.onboardingCompleted, {
        AnalyticsParam.language: language,
      });

  Future<void> languageSelected(String language, {String? source}) =>
      logEvent(AnalyticsEvent.languageSelected, {
        AnalyticsParam.language: language,
        AnalyticsParam.sourceScreen: source,
      });

  Future<void> languageSwitched({required String from, required String to}) =>
      logEvent(AnalyticsEvent.languageSwitched, {
        AnalyticsParam.fromLanguage: from,
        AnalyticsParam.toLanguage: to,
      });

  // ---- the learning path -----------------------------------------------

  Future<void> lessonStarted({
    required String language,
    required String lessonId,
    required int unitIndex,
    required int lessonIndex,
    required int exerciseCount,
    bool isReview = false,
  }) =>
      logEvent(AnalyticsEvent.lessonStarted, {
        AnalyticsParam.language: language,
        AnalyticsParam.lessonId: lessonId,
        AnalyticsParam.unitIndex: unitIndex,
        AnalyticsParam.lessonIndex: lessonIndex,
        AnalyticsParam.exerciseCount: exerciseCount,
        AnalyticsParam.isReview: isReview,
      });

  Future<void> lessonCompleted({
    required String language,
    required String lessonId,
    required int correctAnswers,
    required int totalQuestions,
    required int xpEarned,
    required bool isPerfect,
    required Duration duration,
    bool isReview = false,
  }) =>
      logEvent(AnalyticsEvent.lessonCompleted, {
        AnalyticsParam.language: language,
        AnalyticsParam.lessonId: lessonId,
        AnalyticsParam.correctAnswers: correctAnswers,
        AnalyticsParam.totalQuestions: totalQuestions,
        AnalyticsParam.completionPercent: percent(correctAnswers, totalQuestions),
        AnalyticsParam.xpEarned: xpEarned,
        AnalyticsParam.isPerfect: isPerfect,
        AnalyticsParam.durationSeconds: duration.inSeconds,
        AnalyticsParam.isReview: isReview,
      });

  /// Left without finishing.
  ///
  /// [lastExerciseIndex] and [lastExerciseType] are the point of this
  /// event: "60% of people who quit this lesson quit on the speaking
  /// exercise" is actionable, "some people quit" is not.
  Future<void> lessonAbandoned({
    required String language,
    required String lessonId,
    required int lastExerciseIndex,
    required int totalQuestions,
    ExerciseType? lastExerciseType,
    required Duration duration,
  }) =>
      logEvent(AnalyticsEvent.lessonAbandoned, {
        AnalyticsParam.language: language,
        AnalyticsParam.lessonId: lessonId,
        AnalyticsParam.lastExerciseIndex: lastExerciseIndex,
        AnalyticsParam.lastExerciseType: lastExerciseType?.name,
        AnalyticsParam.totalQuestions: totalQuestions,
        AnalyticsParam.completionPercent:
            percent(lastExerciseIndex, totalQuestions),
        AnalyticsParam.durationSeconds: duration.inSeconds,
      });

  /// Ran out of hearts. Distinct from walking away: one is difficulty,
  /// the other is interest, and they need different fixes.
  Future<void> lessonFailed({
    required String language,
    required String lessonId,
    required int lastExerciseIndex,
    required int totalQuestions,
  }) =>
      logEvent(AnalyticsEvent.lessonFailed, {
        AnalyticsParam.language: language,
        AnalyticsParam.lessonId: lessonId,
        AnalyticsParam.lastExerciseIndex: lastExerciseIndex,
        AnalyticsParam.totalQuestions: totalQuestions,
      });

  // ---- the Fun Zone ----------------------------------------------------

  Future<void> gameRoundStarted({
    required String language,
    required FunGameMode mode,
    required int level,
  }) =>
      logEvent(AnalyticsEvent.gameRoundStarted, {
        AnalyticsParam.language: language,
        AnalyticsParam.gameMode: mode.name,
        AnalyticsParam.gameLevel: level,
      });

  /// A round finished.
  ///
  /// Takes accuracy as a fraction rather than a correct/total pair,
  /// because that is what the app actually knows here: every mode
  /// funnels its result through one method, and what reaches that is
  /// the accuracy the round was scored on. Asking callers for a count
  /// they do not hold would mean each game inventing one.
  Future<void> gameRoundCompleted({
    required String language,
    required FunGameMode mode,
    required int level,
    required double accuracy,
    required int score,
    Duration? duration,
  }) =>
      logEvent(AnalyticsEvent.gameRoundCompleted, {
        AnalyticsParam.language: language,
        AnalyticsParam.gameMode: mode.name,
        AnalyticsParam.gameLevel: level,
        AnalyticsParam.completionPercent:
            (accuracy * 100).round().clamp(0, 100),
        AnalyticsParam.score: score,
        AnalyticsParam.durationSeconds: duration?.inSeconds,
      });

  Future<void> gameRoundFailed({
    required String language,
    required FunGameMode mode,
    required int level,
    required int correctAnswers,
    required int totalQuestions,
  }) =>
      logEvent(AnalyticsEvent.gameRoundFailed, {
        AnalyticsParam.language: language,
        AnalyticsParam.gameMode: mode.name,
        AnalyticsParam.gameLevel: level,
        AnalyticsParam.correctAnswers: correctAnswers,
        AnalyticsParam.totalQuestions: totalQuestions,
      });

  // ---- money -----------------------------------------------------------

  /// The Pro screen was opened. [source] is where from, which is the
  /// whole point: a paywall opened from a locked lesson converts very
  /// differently from one opened out of Settings.
  Future<void> paywallViewed({required String source}) =>
      logEvent(AnalyticsEvent.paywallViewed, {
        AnalyticsParam.sourceScreen: source,
      });

  Future<void> planSelected({
    required String plan,
    String? billingPeriod,
    bool hasFreeTrial = false,
  }) =>
      logEvent(AnalyticsEvent.planSelected, {
        AnalyticsParam.plan: plan,
        AnalyticsParam.billingPeriod: billingPeriod,
        AnalyticsParam.hasFreeTrial: hasFreeTrial,
      });

  Future<void> purchaseStarted({
    required String plan,
    bool hasFreeTrial = false,
  }) =>
      logEvent(AnalyticsEvent.purchaseStarted, {
        AnalyticsParam.plan: plan,
        AnalyticsParam.hasFreeTrial: hasFreeTrial,
      });

  /// A purchase cleared.
  ///
  /// Deliberately not Firebase's `purchase` event, and deliberately
  /// without a price or currency. That event feeds the console's revenue
  /// reports, which expect a verified value — and this app has no
  /// receipt verification, so any figure it reported would be a number
  /// the store never confirmed. Revenue belongs to App Store Connect and
  /// the Play Console, which know it for certain; this records that a
  /// conversion happened.
  Future<void> purchaseSuccess({required String plan, bool restored = false}) =>
      logEvent(
        restored ? AnalyticsEvent.restoreSuccess : AnalyticsEvent.purchaseSuccess,
        {AnalyticsParam.plan: plan},
      );

  /// [reason] must be one of a small set — `network`, `already_owned`,
  /// `store` — not the store's own message, which is unbounded text
  /// written for developers and would make the metric uncountable.
  Future<void> purchaseFailed({String? plan, required String reason}) =>
      logEvent(AnalyticsEvent.purchaseFailed, {
        AnalyticsParam.plan: plan,
        AnalyticsParam.reason: reason,
      });

  Future<void> purchaseCanceled({String? plan}) =>
      logEvent(AnalyticsEvent.purchaseCanceled, {AnalyticsParam.plan: plan});

  Future<void> restoreStarted() => logEvent(AnalyticsEvent.restoreStarted);

  Future<void> restoreFailed({required String reason}) =>
      logEvent(AnalyticsEvent.restoreFailed, {AnalyticsParam.reason: reason});

  Future<void> manageSubscriptionOpened() =>
      logEvent(AnalyticsEvent.manageSubscriptionOpened);

  // ---- engagement ------------------------------------------------------

  /// A deliberate product action — not a tap.
  ///
  /// Reserved for things somebody chose to do that say something about
  /// how the app is used: playing a word aloud, opening the store
  /// listing to rate it. Wiring this to every button would produce a
  /// large, expensive, unreadable stream.
  Future<void> featureUsed(String feature, {String? source}) =>
      logEvent(AnalyticsEvent.featureUsed, {
        AnalyticsParam.featureName: feature,
        AnalyticsParam.sourceScreen: source,
      });

  // ---- user properties -------------------------------------------------

  Future<void> setLanguage(String? language) =>
      setUserProperty(AnalyticsUserProperty.selectedLanguage, language);

  Future<void> setSubscriptionStatus(EntitlementStatus status) =>
      setUserProperty(
        AnalyticsUserProperty.subscriptionStatus,
        switch (status) {
          EntitlementStatus.notSubscribed => 'free',
          EntitlementStatus.trialActive => 'trial',
          EntitlementStatus.subscribedActive => 'subscribed',
          EntitlementStatus.expired => 'expired',
        },
      );

  Future<void> setOnboardingComplete(bool complete) => setUserProperty(
        AnalyticsUserProperty.onboardingComplete,
        complete ? 'true' : 'false',
      );

  /// Bucketed rather than exact — see
  /// [AnalyticsUserProperty.lessonsCompletedBucket].
  Future<void> setLessonsCompleted(int count) => setUserProperty(
        AnalyticsUserProperty.lessonsCompletedBucket,
        lessonBucket(count),
      );
}

/// Completion as a whole percent, clamped, with no division by zero.
int percent(int done, int total) {
  if (total <= 0) return 0;
  return ((done / total) * 100).round().clamp(0, 100);
}

/// The bucket a lesson count falls in.
String lessonBucket(int count) {
  if (count <= 0) return '0';
  if (count <= 5) return '1-5';
  if (count <= 20) return '6-20';
  if (count <= 50) return '21-50';
  return '50+';
}

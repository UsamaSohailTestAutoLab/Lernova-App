/// Every event and parameter name the app records, in one place.
///
/// Names are constants rather than string literals at the call site for
/// a boring but important reason: an analytics event that is misspelled
/// once is not an error, it is a second metric that quietly splits the
/// data, and nobody notices until a dashboard is a month old. The
/// compiler cannot check a string; it can check a constant.
///
/// **Firebase's limits, which these all respect:**
///
/// * Event and parameter names: ≤ 40 characters, letters, digits and
///   underscores, starting with a letter. The prefixes `firebase_`,
///   `google_` and `ga_` are reserved.
/// * String parameter values: ≤ 100 characters. Nothing here sends free
///   text, so none come close.
/// * 25 user properties per project, 25 parameters per event.
///
/// **What is deliberately absent**, because the app has no such thing
/// and an event that never fires is worse than no event — it is a
/// dashboard line that reads as zero usage rather than as absent:
///
/// * `login` / `sign_up` — LingoQuest has no accounts. The profile is
///   local, and Firebase's own installation id is the only identifier
///   used.
/// * `ai_feature_used` — there is no AI feature in the app.
/// * `reading_*` / `writing_*` — not exercise types. The eight real ones
///   are listed in [ExerciseType]; listening and speaking are among
///   them, and are covered by the exercise parameters on a lesson.
library;

/// Event names.
class AnalyticsEvent {
  AnalyticsEvent._();

  // ---- lifecycle -------------------------------------------------------
  //
  // `app_open`, `session_start`, `first_open`, `screen_view` and
  // `user_engagement` are collected by Firebase automatically. None are
  // re-sent here: a duplicate would double every session count in the
  // console.

  // ---- onboarding ------------------------------------------------------
  static const onboardingStarted = 'onboarding_started';
  static const onboardingStepCompleted = 'onboarding_step_completed';
  static const onboardingCompleted = 'onboarding_completed';
  static const languageSelected = 'language_selected';

  // ---- the learning path -----------------------------------------------
  static const lessonStarted = 'lesson_started';
  static const lessonCompleted = 'lesson_completed';

  /// Left before finishing. The other half of the completion rate, and
  /// the only way to see where a lesson loses people.
  static const lessonAbandoned = 'lesson_abandoned';

  /// Ran out of hearts. A distinct outcome from walking away.
  static const lessonFailed = 'lesson_failed';

  static const lessonReviewViewed = 'lesson_review_viewed';

  // ---- the Fun Zone ----------------------------------------------------
  //
  // Named for what the app has. There is no "quiz" in LingoQuest; the
  // nearest thing is a timed round of one of the ten games, and these
  // carry the parameters a quiz report would want — score, questions,
  // correct answers, duration.
  static const gameRoundStarted = 'game_round_started';
  static const gameRoundCompleted = 'game_round_completed';
  static const gameRoundFailed = 'game_round_failed';

  // ---- money -----------------------------------------------------------
  static const paywallViewed = 'paywall_viewed';
  static const planSelected = 'subscription_plan_selected';
  static const purchaseStarted = 'purchase_started';
  static const purchaseSuccess = 'purchase_success';
  static const purchaseFailed = 'purchase_failed';
  static const purchaseCanceled = 'purchase_canceled';
  static const restoreStarted = 'restore_started';
  static const restoreSuccess = 'restore_success';
  static const restoreFailed = 'restore_failed';
  static const manageSubscriptionOpened = 'manage_subscription_opened';

  // ---- engagement ------------------------------------------------------
  static const featureUsed = 'feature_used';
  static const languageSwitched = 'language_switched';

  /// How long a screen was on top. Sent once, when it is left.
  static const screenTime = 'screen_time';
}

/// Parameter names.
class AnalyticsParam {
  AnalyticsParam._();

  static const screenName = 'screen_name';
  static const screenClass = 'screen_class';
  static const durationSeconds = 'duration_seconds';

  /// The language being learned, as its course code — `es`, `de`. A code
  /// rather than "Spanish" so the value does not change with the
  /// device's locale and split the metric in two.
  static const language = 'language';

  static const lessonId = 'lesson_id';
  static const lessonTitle = 'lesson_title';
  static const unitIndex = 'unit_index';
  static const lessonIndex = 'lesson_index';
  static const exerciseCount = 'exercise_count';
  static const isReview = 'is_review';

  static const correctAnswers = 'correct_answers';
  static const totalQuestions = 'total_questions';
  static const completionPercent = 'completion_percent';
  static const xpEarned = 'xp_earned';
  static const isPerfect = 'is_perfect';

  /// Which exercise the learner was on when they left. The single most
  /// useful field for "where does this lesson lose people".
  static const lastExerciseIndex = 'last_exercise_index';
  static const lastExerciseType = 'last_exercise_type';

  static const gameMode = 'game_mode';
  static const gameLevel = 'game_level';
  static const score = 'score';

  static const plan = 'plan';
  static const billingPeriod = 'billing_period';
  static const hasFreeTrial = 'has_free_trial';
  static const sourceScreen = 'source_screen';

  /// A short, enumerable reason — `network`, `already_owned`, `store`.
  /// Never the store's raw message, which is unbounded text written for
  /// developers.
  static const reason = 'reason';

  static const featureName = 'feature_name';
  static const step = 'step';
  static const fromLanguage = 'from_language';
  static const toLanguage = 'to_language';
}

/// User properties.
///
/// Kept to four. Firebase allows 25, but each one is a dimension every
/// report can be sliced by, and a long list of rarely-used dimensions
/// makes the console harder to read rather than richer.
class AnalyticsUserProperty {
  AnalyticsUserProperty._();

  /// Course code of the language being learned.
  static const selectedLanguage = 'selected_language';

  /// `free`, `trial`, `subscribed` or `expired` — the four states of
  /// [EntitlementStatus]. This is what makes every other metric
  /// splittable by free versus paying.
  static const subscriptionStatus = 'subscription_status';

  /// `true` once onboarding is finished, so incomplete first runs can be
  /// separated from returning learners.
  static const onboardingComplete = 'onboarding_complete';

  /// Bucketed, not exact: `0`, `1-5`, `6-20`, `21-50`, `50+`. A raw
  /// count would be a high-cardinality property, which Firebase handles
  /// badly and which is not more useful for cohorting.
  static const lessonsCompletedBucket = 'lessons_bucket';
}

/// Canonical screen names.
///
/// One constant per screen, so `screen_view` and `screen_time` always
/// agree and a rename cannot leave the two reporting different names for
/// the same screen.
class AnalyticsScreen {
  AnalyticsScreen._();

  static const splash = 'splash';
  static const welcome = 'welcome';
  static const onboardingExplainer = 'onboarding_explainer';
  static const nameEntry = 'onboarding_name';
  static const languageSelection = 'language_selection';
  static const goalSelection = 'onboarding_goal';
  static const dailyGoalSelection = 'onboarding_daily_goal';
  static const placement = 'placement_test';

  static const home = 'home';
  static const path = 'path';
  static const fun = 'fun_zone';

  static const vocabPreview = 'vocab_preview';
  static const funGameIntro = 'game_intro';
  static const funSurvivalIntro = 'game_intro_survival';
  static const funGamePlay = 'game_play';
  static const funRoundResults = 'game_results';
  static const funWordMatchPlay = 'game_play_word_match';
  static const funWordMatchResults = 'game_results_word_match';
  static const funSentenceBuilderPlay = 'game_play_sentence_builder';
  static const funSentenceBuilderResults = 'game_results_sentence_builder';
  static const funMemoryMatchPlay = 'game_play_memory_match';
  static const funMemoryMatchResults = 'game_results_memory_match';
  static const funConversationPlay = 'game_play_conversation';
  static const funConversationResults = 'game_results_conversation';

  static const lessonIntro = 'lesson_intro';
  static const lessonPlayer = 'lesson_player';
  static const lessonComplete = 'lesson_complete';
  static const lessonReview = 'lesson_review';
  static const xpReward = 'reward_xp';
  static const streakResult = 'reward_streak';
  static const dailyGoalResult = 'reward_daily_goal';
  static const achievementUnlock = 'reward_achievement';

  static const achievements = 'achievements';
  static const statistics = 'statistics';
  static const languages = 'language_switch';

  static const settings = 'settings';
  static const notificationSettings = 'settings_notifications';
  static const accountSettings = 'settings_account';
  static const premium = 'paywall';
}

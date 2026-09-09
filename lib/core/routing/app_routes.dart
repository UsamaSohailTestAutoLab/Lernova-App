/// Central registry of every route path in the app. One constant per
/// screen keeps `context.go`/`context.push` calls typo-proof.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const welcome = '/welcome';
  static const onboardingExplainer = '/welcome/explainer';

  static const nameEntry = '/onboarding/name';
  static const languageSelection = '/onboarding/language';
  static const goalSelection = '/onboarding/goal';
  static const dailyGoalSelection = '/onboarding/daily-goal';
  static const placement = '/onboarding/placement';

  static const home = '/home';
  static const path = '/path';
  static const fun = '/fun';

  static const vocabPreview = '/preview/vocab';

  static const funGameIntro = '/fun/intro';
  static const funSurvivalIntro = '/fun/survival-intro';
  static const funGamePlay = '/fun/play';
  static const funRoundResults = '/fun/results';

  static const funWordMatchPlay = '/fun/word-match/play';
  static const funWordMatchResults = '/fun/word-match/results';
  static const funSentenceBuilderPlay = '/fun/sentence-builder/play';
  static const funSentenceBuilderResults = '/fun/sentence-builder/results';
  static const funMemoryMatchPlay = '/fun/memory-match/play';
  static const funMemoryMatchResults = '/fun/memory-match/results';
  static const funConversationPlay = '/fun/conversation/play';
  static const funConversationResults = '/fun/conversation/results';

  static const lessonIntro = '/lesson/intro';
  static const lessonPlayer = '/lesson/play';
  static const lessonComplete = '/lesson/complete';
  static const lessonReview = '/lesson/review';
  static const xpReward = '/lesson/xp-reward';
  static const streakResult = '/lesson/streak';
  static const dailyGoalResult = '/lesson/daily-goal';
  static const achievementUnlock = '/lesson/achievement-unlock';

  static const achievements = '/achievements';
  static const statistics = '/statistics';
  static const shop = '/shop';

  static const languages = '/languages';

  static const settings = '/settings';
  static const notificationSettings = '/settings/notifications';
  static const accountSettings = '/settings/account';
  static const premium = '/premium';
}

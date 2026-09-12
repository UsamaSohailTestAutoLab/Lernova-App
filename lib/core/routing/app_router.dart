import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/vocab_preview_nav_args.dart';
import '../../features/achievements/presentation/achievements_screen.dart';
import '../../features/course/presentation/course_path_screen.dart';
import '../../features/fun/application/fun_game_nav_args.dart';
import '../../features/fun/presentation/falling_word_game_screen.dart';
import '../../features/fun/presentation/fun_game_intro_screen.dart';
import '../../features/fun/presentation/fun_hub_screen.dart';
import '../../features/fun/presentation/fun_conversation_results_screen.dart';
import '../../features/fun/presentation/fun_conversation_screen.dart';
import '../../features/fun/presentation/fun_memory_match_results_screen.dart';
import '../../features/fun/presentation/fun_memory_match_screen.dart';
import '../../features/fun/presentation/fun_round_results_screen.dart';
import '../../features/fun/presentation/fun_sentence_builder_results_screen.dart';
import '../../features/fun/presentation/fun_sentence_builder_screen.dart';
import '../../features/fun/presentation/fun_word_match_results_screen.dart';
import '../../features/fun/presentation/fun_word_match_screen.dart';
import '../../features/fun/presentation/water_survival_intro_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lessons/presentation/achievement_unlock_screen.dart';
import '../../features/lessons/presentation/daily_goal_result_screen.dart';
import '../../features/lessons/presentation/lesson_complete_screen.dart';
import '../../features/lessons/presentation/lesson_review_screen.dart';
import '../../features/lessons/presentation/lesson_intro_screen.dart';
import '../../features/lessons/presentation/lesson_player_screen.dart';
import '../../features/lessons/presentation/streak_result_screen.dart';
import '../../features/lessons/presentation/xp_reward_screen.dart';
import '../../features/onboarding/presentation/daily_goal_selection_screen.dart';
import '../../features/onboarding/presentation/goal_selection_screen.dart';
import '../../features/onboarding/presentation/language_selection_screen.dart';
import '../../features/onboarding/presentation/onboarding_explainer_screen.dart';
import '../../features/languages/presentation/language_switch_screen.dart';
import '../../features/onboarding/presentation/placement_test_screen.dart';
import '../../features/onboarding/presentation/name_entry_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/preview/presentation/vocab_preview_screen.dart';
import '../../features/progress/presentation/statistics_screen.dart';
import '../../features/settings/presentation/account_settings_screen.dart';
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/settings/presentation/premium_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(
        path: AppRoutes.onboardingExplainer,
        builder: (context, state) => OnboardingExplainerScreen(isReplay: state.extra == true),
      ),
      GoRoute(
        path: AppRoutes.nameEntry,
        builder: (context, state) => NameEntryScreen(standalone: state.extra == true),
      ),
      GoRoute(
        path: AppRoutes.languageSelection,
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.goalSelection,
        builder: (context, state) => const GoalSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.dailyGoalSelection,
        builder: (context, state) => const DailyGoalSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.placement,
        builder: (context, state) => const PlacementTestScreen(),
      ),

      GoRoute(
        path: AppRoutes.lessonIntro,
        builder: (context, state) => LessonIntroScreen(extra: state.extra),
      ),
      GoRoute(
        path: AppRoutes.lessonPlayer,
        builder: (context, state) => const LessonPlayerScreen(),
      ),
      GoRoute(
        path: AppRoutes.lessonComplete,
        builder: (context, state) => const LessonCompleteScreen(),
      ),
      GoRoute(
        path: AppRoutes.lessonReview,
        builder: (context, state) => LessonReviewScreen(extra: state.extra),
      ),
      GoRoute(path: AppRoutes.xpReward, builder: (context, state) => const XpRewardScreen()),
      GoRoute(
        path: AppRoutes.streakResult,
        builder: (context, state) => const StreakResultScreen(),
      ),
      GoRoute(
        path: AppRoutes.dailyGoalResult,
        builder: (context, state) => const DailyGoalResultScreen(),
      ),
      GoRoute(
        path: AppRoutes.achievementUnlock,
        builder: (context, state) => const AchievementUnlockScreen(),
      ),

      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(path: AppRoutes.statistics, builder: (context, state) => const StatisticsScreen()),
      GoRoute(path: AppRoutes.premium, builder: (context, state) => const PremiumScreen()),
      GoRoute(
        path: AppRoutes.languages,
        builder: (context, state) => const LanguageSwitchScreen(),
      ),
      // Settings is a bottom-nav tab now — registered as a shell branch
      // below, not as a top-level route.
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountSettings,
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vocabPreview,
        builder: (context, state) =>
            VocabPreviewScreen(args: state.extra as VocabPreviewNavArgs),
      ),
      GoRoute(
        path: AppRoutes.funGameIntro,
        builder: (context, state) =>
            FunGameIntroScreen(args: state.extra as FunGameNavArgs),
      ),
      GoRoute(
        path: AppRoutes.funSurvivalIntro,
        builder: (context, state) => const WaterSurvivalIntroScreen(),
      ),
      GoRoute(
        path: AppRoutes.funGamePlay,
        builder: (context, state) => const FallingWordGameScreen(),
      ),
      GoRoute(
        path: AppRoutes.funRoundResults,
        builder: (context, state) => const FunRoundResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.funWordMatchPlay,
        builder: (context, state) => const FunWordMatchScreen(),
      ),
      GoRoute(
        path: AppRoutes.funWordMatchResults,
        builder: (context, state) => const FunWordMatchResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.funSentenceBuilderPlay,
        builder: (context, state) => const FunSentenceBuilderScreen(),
      ),
      GoRoute(
        path: AppRoutes.funSentenceBuilderResults,
        builder: (context, state) => const FunSentenceBuilderResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.funMemoryMatchPlay,
        builder: (context, state) => const FunMemoryMatchScreen(),
      ),
      GoRoute(
        path: AppRoutes.funMemoryMatchResults,
        builder: (context, state) => const FunMemoryMatchResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.funConversationPlay,
        builder: (context, state) => const FunConversationScreen(),
      ),
      GoRoute(
        path: AppRoutes.funConversationResults,
        builder: (context, state) => const FunConversationResultsScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoutes.path, builder: (context, state) => const CoursePathScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoutes.fun, builder: (context, state) => const FunHubScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

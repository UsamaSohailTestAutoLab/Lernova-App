# Architecture

## Layering

```
lib/
  core/
    theme/       AppColors, AppSpacing/AppRadius, AppTypography, AppTheme (light+dark), AppShadows
    routing/     AppRoutes (path constants), AppRouter (go_router config), AppShell (bottom-nav shell)
    constants/   app-wide enums (ExerciseType, FunGameMode, AchievementId, ...), GameConstants (formula numbers)
    utils/       pure functions — XpUtils, HeartsLogic, StreakLogic, DailyGoalLogic, LeagueLogic,
                 AchievementLogic, CourseProgress, FunDailyChallengeLogic, date helpers, icon mapping
    services/    LocalStorageService (SharedPreferences wrapper), TtsService, service_providers.dart
    widgets/     shared design-system components (buttons, cards, dialogs, skeleton/empty/error states,
                 gamification chips, the SparkMascot brand character)
  data/
    models/      plain Dart data classes with fromJson/toJson (courses, lessons, exercises, user progress,
                  Fun-game content, achievements, settings...)
    repositories/  abstract interfaces (CourseRepository, FunContentRepository, LeaderboardRepository)
    local/       the current (only) implementations of those interfaces, reading bundled JSON / prefs
  features/
    <feature>/
      application/   Riverpod Notifiers + providers — all business logic, fully unit-testable
      presentation/  screens + feature-local widgets — thin, read state, call controller methods
```

Every feature follows the same shape: `application/` owns state and rules, `presentation/` only renders it and forwards user intent back to a controller method. No screen computes gamification math itself.

## State management

`flutter_riverpod`, no code generation. Every piece of mutable state is a `Notifier<T>` (or `AsyncNotifier` where content loads from an asset) exposed through a top-level `final xProvider = NotifierProvider(...)`. This was a deliberate choice over `riverpod_generator`: it keeps the toolchain to plain `flutter pub get` with no `build_runner` step, which matters on Windows where codegen watch loops are more fragile.

Because every controller is a `Notifier`, tests instantiate a `ProviderContainer` with `localStorageServiceProvider` overridden to a `LocalStorageService` backed by `SharedPreferences.setMockInitialValues({})`, then call controller methods directly — no widget pump required for pure-logic tests. See `docs/TESTING.md`.

## The gamification core

`ProgressController` (`lib/features/progress/application/progress_controller.dart`) is the single owner of `UserProgress` — XP, level, hearts, streak, daily goal, gems, unlocked achievements, `vocabStrength` (per-word mastery), `mistakeBank`, league standing. Two entry points feed it:

- `completeLessonSession(...)` — called once when a Path lesson (or a mistake-review session) finishes.
- `awardFunSession(...)` — called once when a Fun round finishes.

Both end in a shared private helper, `_finalizeAward(...)`, which applies streak crediting, daily-goal-reached detection, and achievement evaluation identically for both paths, then returns one `LessonCompletionResult` type that every result screen (lesson or Fun) reads. This is why playing a Fun round moves the *same* XP total, streak, and vocabulary mastery numbers shown on Home and in Statistics — there is exactly one gamification ledger, not two.

`vocabStrength` is keyed by the same `vocabId` string wherever a word appears in both a course lesson and the Fun vocabulary bank (e.g. `es_hola`), so practicing a word in one place measurably improves its mastery in the other.

## Persistence

`LocalStorageService` (`lib/core/services/local_storage_service.dart`) is the only code that touches `SharedPreferences`. Each top-level piece of state is one JSON-encoded string under a namespaced key (`lernova.user`, `lernova.progress`, `lernova.fun_progress`, `lernova.settings`, `lernova.onboarding_complete`). Every model has `toJson`/`fromJson`; nothing is serialized ad hoc. Because access is centralized here, a future backend-backed store only needs to implement the same read/write shape — no UI code would change.

On every app boot, `ProgressController.build()` loads the saved `UserProgress` (or creates a fresh one) and runs it through a reconcile pipeline (`HeartsLogic.regenerate` → `StreakLogic.reconcileOnResume` → `DailyGoalLogic.reconcileOnResume` → week-rollover league resolution) before the UI ever sees it, so hearts have regenerated, a missed day has broken the streak (or been protected by a freeze), and daily counters have reset — all *before* the first frame, not as a background surprise.

## Content: JSON in, typed models out

Course and Fun-game content are bundled JSON under `assets/data/` (`course_es.json`, `course_fr.json`, `fun/vocab_es.json`, `fun/phrases_es.json`). `LocalCourseRepository` / `LocalFunContentRepository` load and parse them via `rootBundle.loadString` + the models' `fromJson` constructors, cached in memory after first load. Repositories are behind interfaces (`CourseRepository`, `FunContentRepository`) specifically so a `RemoteCourseRepository` could implement the same contract later against a real API — the override would happen in `core/services/service_providers.dart` and nothing above the repository layer would need to change.

## Routing

`go_router`, configured in `lib/core/routing/app_router.dart`. The four/five primary destinations (Home, Path, Fun, Leaderboard, Profile) are a `StatefulShellRoute.indexedStack` wrapped by `AppShell`, so each tab keeps its own navigation stack when you switch away and back. Everything else (onboarding, lesson flow, Fun game flow, settings sub-pages) is plain top-level `GoRoute`s pushed on top of the shell. Screens that need typed data from the caller (a lesson, a Fun game mode) receive it via `extra` on the route, wrapped in a small dedicated args class (`LessonNavArgs`, `FunGameNavArgs`) rather than passing loose maps.

## Design system

`core/theme/` defines the whole visual language as tokens (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppShadows`) consumed by one `AppTheme.light()`/`AppTheme.dark()`. Screens never hardcode a color or font size — they pull from `Theme.of(context)` or the tokens directly, which is why dark mode works uniformly across the whole app with no per-screen overrides. `core/widgets/` holds the reusable component library (buttons, cards, chips, dialogs, empty/error/skeleton states) that every feature composes rather than reimplementing.

# Lernova

A fully functional, original language-learning app built in Flutter — inspired by the *UX patterns* of apps like Duolingo (short lessons, streaks, XP, hearts, gamified progress), but with its own identity: original branding, color system, mascot, copy, and content. No third-party assets or copyrighted material are used anywhere in the app.

Two learning experiences live side by side:

- **Path** — a structured course (units → lessons → exercises) with 7 exercise types, spaced-repetition-style mistake review, and a full gamification core.
- **Fun** — a casual game hub built on top of the *same* progress system, with two fully playable flagship games (Falling Words, Word Rush) and a themed "water survival" reimagining of Falling Words' first level.

Everything is local-first: no backend, no login server, no Firebase. All content ships as bundled JSON assets and all user state persists on-device via `shared_preferences`.

## Quick start

```bash
flutter pub get
flutter run                 # picks a connected device/emulator/Chrome
flutter test                 # full test suite
flutter analyze              # static analysis (should report 0 issues)
```

Tested against Flutter 3.47 / Dart 3.13. `flutter devices` will list whatever's available (Android device, Chrome, Windows desktop) — pass `-d <id>` to target a specific one.

## What's actually implemented

Every screen is real and wired end to end — no placeholder buttons, no hardcoded progress numbers.

- **Onboarding**: splash → welcome → sign up / log in (local account, on this device) → language → learning-goal → daily-XP-goal → placement test (or skip) → provisions a real course and lands on Home.
- **Home dashboard**: current course/level, streak, hearts, daily-goal ring, "continue learning" into the exact next lesson, recent achievements, review-mistakes shortcut, vocabulary mastery snapshot.
- **Course path**: a winding node map per unit; lessons are locked/current/completed/perfect based on real persisted progress, not a static image.
- **Lesson engine**: 7 exercise types (multiple choice, translation, listening via on-device TTS, speaking with a disclosed self-assessment step, word matching, sentence arrangement, fill-in-the-blank), a retry queue for missed exercises within a lesson, live hearts/XP consequences, and a results chain (completion → XP → streak → daily goal → achievement unlock) that only shows the beats that actually happened.
- **Fun tab**: a game hub showing all 10 planned game modes (2 implemented — Falling Words and Word Rush — the rest shown as real, level-gated "coming soon" cards, not dead buttons), a shared adaptive question-generation engine covering 9 question-combination shapes, indefinitely-scaling difficulty, a daily word challenge, and Fun-specific achievements. See `docs/FUN_TAB.md`.
- **Gamification**: XP and leveling, hearts with real-time regeneration, streaks with freeze protection, a weekly league with bot cohort + promotion/demotion, a shop (gems → heart refills / streak freeze / cosmetics), achievements, leaderboard. See `docs/GAMIFICATION.md`.
- **Profile / Settings / Premium**: real stats aggregation, working theme/notification/account settings, a local (non-billing) premium entitlement toggle with real gameplay effects.
- **Persistence**: everything above survives an app restart — confirmed by an explicit test (`test/unit/persistence_test.dart`) that mutates state, tears down the provider container, and rebuilds it against the same store.

## Project structure

```
lib/
  core/          # theme, routing, shared widgets, cross-cutting utils/services
  data/          # models, repository interfaces, local (JSON/SharedPreferences) implementations
  features/      # one folder per feature; each has presentation/ (screens) + application/ (Riverpod controllers)
assets/data/     # bundled course + Fun-game content (JSON)
test/
  unit/          # pure logic — formulas, controllers, generators
  widget/        # real navigation/interaction through the actual widget tree
docs/            # deeper documentation (see below)
```

Business logic never lives in a widget's `build()` — every controller is a Riverpod `Notifier` that's independently unit-testable via `ProviderContainer`, with no codegen (no `build_runner`).

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — layering, state management pattern, persistence model, how content flows from JSON asset to screen.
- [`docs/GAMIFICATION.md`](docs/GAMIFICATION.md) — every XP/hearts/streak/league/achievement formula, in one place.
- [`docs/FUN_TAB.md`](docs/FUN_TAB.md) — the Fun tab: game modes, the question-generation engine, difficulty scaling, and the Level 1 "water survival" rework.
- [`docs/TESTING.md`](docs/TESTING.md) — what's covered, test conventions, how to run subsets.

## Known, deliberate tradeoffs

- **Speaking exercise** grades via an honest self-assessment step, not on-device speech recognition — `speech_to_text` has no reliable mic/web support in this project's dev environment, and a fake "always correct" recognizer would be worse than being upfront about it.
- **Notifications**: settings persist and could drive an in-app reminder, but there's no OS push infrastructure (would need a backend).
- **Premium**: a real local entitlement with real gameplay effects (unlimited hearts, ad-simulation removal) — no real billing integration.
- **No backend/Firebase**: everything is on-device. Repository interfaces (`CourseRepository`, `FunContentRepository`, etc.) are already shaped so a remote implementation can be dropped in later without touching the UI layer.

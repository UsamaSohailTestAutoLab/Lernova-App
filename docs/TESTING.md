# Testing

```bash
flutter test                          # everything
flutter test test/unit/               # pure-logic tests only (fast)
flutter test test/widget/             # real widget-tree interaction tests
flutter test test/unit/xp_utils_test.dart   # a single file
```

428 tests across 54 files, all currently green. `flutter analyze` reports 0 issues — that bar is maintained continuously, not checked once at the end.

## Unit tests (`test/unit/`)

Pure logic and controllers, no widget pumping. Controller tests use a real `ProviderContainer` with `localStorageServiceProvider` overridden to a `LocalStorageService` backed by `SharedPreferences.setMockInitialValues({})` — this exercises the actual persistence read/write path, not a mock of it.

| File | Covers |
|---|---|
| `xp_utils_test.dart` | XP-per-answer, lesson bonus, level formula, level progress |
| `hearts_logic_test.dart` | Heart regeneration timing (a safety net only — hearts refill each attempt), `nextHeartAt` |
| `streak_logic_test.dart` | Streak credit/break/freeze across day boundaries |
| `daily_goal_logic_test.dart` | Daily counter rollover, goal-met/progress ratio |
| `league_logic_test.dart` | Promotion/demotion thresholds, tier clamping |
| `achievement_logic_test.dart` | Every achievement rule, including the 4 Fun-specific ones and the word/phrase id-marker split |
| `exercise_validator_test.dart` | Answer validation for all 7 lesson exercise types |
| `course_progress_test.dart` | Lesson/unit lock states, unlock propagation, course completion |
| `lesson_session_controller_test.dart` | The lesson retry-queue engine: correct/wrong/retry XP, completion |
| `progress_controller_test.dart` | `completeLessonSession` and `awardFunSession` end to end, including the shared `_finalizeAward` tail |
| `persistence_test.dart` | State survives a **simulated app restart** — two separate `ProviderContainer`s against the same mock store, nothing carried over manually |
| `fun_level_catalog_test.dart` | The difficulty-scaling formula: word/choice counts, fall-duration floor, cumulative type unlocks, combo threshold, Word Rush overrides |
| `fun_question_generator_test.dart` | Round size, type gating, no-duplicate-correct-answer, synonym/antonym eligibility skipping, adaptive weighting (statistical, 300-trial check), phrase-slot mixing, the practice-round builder |
| `falling_word_session_controller_test.dart` | Combo build/reset, life loss on wrong/timeout, round completion vs. failure, `finishAndApply` idempotency, vocab-strength deltas |
| `fun_progress_controller_test.dart` | Per-mode level-up threshold, best-combo-only-increases, daily-challenge completion firing exactly once |

## Widget tests (`test/widget/`)

Drive the *real* app (`LernovaApp`) through Flutter's own testing framework — real navigation via `go_router`, real form validation, real taps through the actual render tree. These catch things unit tests structurally can't, and have: see "Bugs these tests actually caught" below.

| File | Covers |
|---|---|
| `widget_test.dart` | App boots to the splash screen with no exceptions |
| `onboarding_flow_test.dart` | Sign-up form validation → language selection populated from real bundled course JSON → Continue button gating |
| `exercise_answer_flow_test.dart` | A multiple-choice exercise shows correct/incorrect feedback for the right/wrong tap |
| `fun_flow_test.dart` | Bottom-nav → Fun Hub (shows both implemented modes and a locked one correctly) → game intro → a real generated round renders with playable bubbles |

### A gotcha worth knowing: `pumpAndSettle()` and real timers

Two screens in this app have real, running timers (the splash screen's navigation delay, the Falling Words fall/timeout animation). `pumpAndSettle()` simulates elapsed time until no more frames are scheduled — which means it will happily run a 5-second fall animation to completion and beyond, timing out every question in a round and navigating to the results screen before your test's next assertion runs. The fix used throughout this suite: a bounded `await tester.pump(Duration(...))` immediately after an action that starts a timer, instead of `pumpAndSettle()`, and *then* a final `pumpAndSettle()` at the very end of the test purely to drain any still-pending timer so the test doesn't fail on Flutter's "timer still pending after dispose" invariant check.

## Bugs these tests actually caught

Worth keeping in mind as evidence the suite earns its keep, not just coverage theater:

- **`PrimaryButton` silently ate every tap.** It wrapped `ElevatedButton` in an outer `GestureDetector` for a press-scale animation, with the real `onPressed` logic on the *outer* detector and a no-op `() {}` on the inner button. `ElevatedButton`'s own tap recognizer won the gesture arena, so the real callback never fired — not just in tests, in the running app too. Fixed by moving the animation trigger to a `Listener` (raw pointer events, doesn't compete in the gesture arena) and putting the real logic on `ElevatedButton.onPressed` where it belongs.
- **The lesson-completion XP bonus was computed, unit-tested, and never actually applied.** `XpUtils.lessonBonusXp` existed and had passing tests for its own math, but nothing in `ProgressController` ever called it — every lesson under-awarded XP by the completion/perfect bonus. Caught while writing a persistence test with a hand-computed expected total that didn't match reality.
- **`UserProgress.copyWith` couldn't actually clear `lastStreakDate` to null** — `copyWith(lastStreakDate: null)` fell back to `?? this.lastStreakDate` and silently kept the old value, so a broken streak never actually reset. Same class of bug already avoided for `lastHeartLostAt` via an explicit `clearX` boolean flag; `streak_logic_test.dart` caught the one place that pattern wasn't applied, and the fix mirrors the existing convention.

## What isn't automated here

A full interactive click-through of every screen isn't scripted — Flutter web's canvas rendering doesn't expose reliable DOM hooks for generic browser automation (Playwright/`chromium-cli`), and that's the only headless option available in this environment. Real interaction coverage instead comes from the widget tests above, which drive actual taps through the actual widget tree via Flutter's own testing APIs — a stronger guarantee for the paths they cover than a fragile screenshot-driven script would be, just narrower in surface area. Manual verification on a physical Android device (Pixel 5a) supplemented this during development.

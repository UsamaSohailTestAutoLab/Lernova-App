# The rating prompt

## Why it may not appear

"Nothing happened" is what every refusal looks like, and there are
nine of them across three layers. Work down in order.

### 1. Is the build installed by Play?

```
adb shell "pm dump com.lernova.lernova | grep installerPackageName"
```

`installerPackageName=null` means sideloaded, and Google's In-App
Review API returns a **no-op flow** for any app Play did not install.
Play accepts the call, logs success, and draws nothing. No code change
affects this.

Fix: Play Console → **Internal app sharing**, upload, install from the
link it gives you. Then the value is `com.android.vending`. This is
much faster than a full testing track.

### 2. What did the controller decide?

Build with the diagnostics on — they are compiled out otherwise, which
is a problem precisely because a Play install is a release build:

```bash
flutter build appbundle --dart-define=REVIEW_DEBUG=true
```

That turns on two things:

- A log line for every decision: `adb logcat | grep "\[review\]"`,
  e.g. `[review] notEnoughLessons — 2 of 3 lessons done`.
- **Settings → Debug: request the rating prompt**, which fires the ask
  immediately, skipping every rule. It deliberately does not spend the
  budget, so testing cannot be the reason a real learner is never
  asked.

Never ship a store build with this flag.

### 3. The rules

In `ReviewPromptController`:

| Rule | Value | Why |
|---|---|---|
| `minLessonsCompleted` | 3 | Someone two lessons in has no view worth asking for. Counts **replays** — see below. |
| `minDaysSinceFirstEligible` | 0 | No soak. The lesson bar already tests engagement. |
| `minDaysBetweenAsks` | 120 | Three asks at this spacing cannot exceed iOS's yearly allowance. |
| `maxAsksEver` | 3 | Matches the platform ceiling. |
| once per session | — | Two prompts in one sitting is the worst reading of the rules. |
| never after `outOfHearts` | — | The worst possible moment. |

Two entry points, **one budget**: `maybeAskAfterLesson` at the end of
the post-lesson reward chain, and `maybeAskAfterDailyGoal` when the
daily goal is crossed on Home.

### 4. The counter, and the free tier

Both entry points pass `UserProgress.totalLessonsCompleted`, which
counts **every** completion including replays.

This matters more than it looks. The free tier unlocks exactly one Path
lesson, so `completedLessonIds.length` — *distinct* lessons finished —
is pinned at 1 for every free learner, forever. The daily-goal path
used that field and could therefore never ask anybody. Using
`totalLessonsCompleted` means three replays of the free lesson clear
the bar.

If three still feels like too many for a one-lesson free tier, that is
a product decision, and `minLessonsCompleted` is the one number to
change.

## What "asked" does not mean

[ReviewPromptOutcome.asked] means the request reached the store.
Neither store reports whether a sheet was drawn, both rate-limit
independently of anything here, and nothing in the app may depend on
the prompt having been seen.

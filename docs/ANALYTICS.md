# Analytics

LingoQuest records how it is used through Firebase Analytics. This
describes every event it sends, what it does not send, how to switch it
on, and how to verify it before a release.

## The shape of it

| File | What it is |
| --- | --- |
| `lib/core/analytics/analytics_events.dart` | Every event, parameter, property and screen name, as constants |
| `lib/core/analytics/analytics_service.dart` | The `AnalyticsService` interface, the Firebase one, the no-op, and a recording one for tests |
| `lib/core/analytics/analytics.dart` | The typed API the app calls — `lessonCompleted(...)`, not `logEvent('lesson_completed', {...})` |
| `lib/core/analytics/screen_tracker.dart` | A `NavigatorObserver` that reports screen views and durations |
| `lib/core/analytics/analytics_providers.dart` | Riverpod wiring |

Nothing outside that folder names an event or a parameter. A misspelled
event name is not an error — it is a second metric that quietly splits
the data, and nobody notices until a dashboard is a month old. The
compiler cannot check a string; it can check a constant.

## It is off until you configure Firebase

**There is no Firebase project wired to this repository.** No
`google-services.json`, no `GoogleService-Info.plist` — those are
generated per project and are environment configuration, not source.

The app is built to run without them. `initAnalytics()` catches the
failure and returns `NoopAnalytics`, so a build with no Firebase project
behaves exactly like one with analytics disabled rather than one that
crashes on launch. Verified on a Pixel 5a: the app starts, logs
`Firebase is not configured, so analytics are off. The app runs
normally.`, and every screen works.

### Switching it on — Android

1. Create a Firebase project in the [console](https://console.firebase.google.com).
2. **Add app → Android.** The package name must be exactly
   `com.lernova.lernova` — the `applicationId` in
   `android/app/build.gradle.kts`. A mismatch is silent: events are sent
   and dropped.
3. Download `google-services.json` into `android/app/`.
4. Add the Google services Gradle plugin:

   In `android/settings.gradle.kts`, in the `plugins` block:

   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```

   In `android/app/build.gradle.kts`, in its `plugins` block:

   ```kotlin
   id("com.google.gms.google-services")
   ```

5. `flutter clean && flutter run`. The log line above should be gone.

### Switching it on — iOS

1. **Add app → iOS**, bundle id from `ios/Runner.xcodeproj`.
2. Drag `GoogleService-Info.plist` into `ios/Runner/` **through Xcode**,
   with "Copy items if needed" ticked, so it joins the target rather
   than only sitting on disk.
3. `cd ios && pod install`.

Both files carry project identifiers rather than secrets, but they are
per-environment, so keep them out of the repository and in whatever the
team uses for build configuration.

## Events

Firebase already collects `first_open`, `session_start`, `app_open`,
`screen_view` and `user_engagement` by itself. None of those are re-sent
here — a duplicate would double every session count in the console.

### Onboarding

| Event | Fires when | Parameters |
| --- | --- | --- |
| `onboarding_started` | The first-run flow begins | — |
| `onboarding_step_completed` | One step of it is finished | `step` — `name`, `language`, `goal`, `daily_goal`, `placement_taken`, `placement_skipped` |
| `onboarding_completed` | The learner reaches Home for the first time | `language` |
| `language_selected` | A course is chosen | `language`, `source_screen` |

Recorded from `OnboardingController`, one call per setter, so the
funnel falls out of the flow itself rather than needing an event
planted on each screen — and a screen reordered later keeps reporting
the step it actually is.

`onboarding_started` is guarded to fire once. Emitting it from the
welcome screen's `build` would report a dozen starts for one install.

`selected_language` is set the moment a course is picked, not when the
flow finishes: somebody who abandons onboarding halfway still had a
language in mind, and that is exactly the cohort worth being able to
see.

### The learning path

| Event | Fires when | Parameters |
| --- | --- | --- |
| `lesson_started` | `LessonSessionController.start` — the one way into a lesson | `language`, `lesson_id`, `unit_index`, `lesson_index`, `exercise_count`, `is_review` |
| `lesson_completed` | The session finishes with every exercise answered | `language`, `lesson_id`, `correct_answers`, `total_questions`, `completion_percent`, `xp_earned`, `is_perfect`, `duration_seconds`, `is_review` |
| `lesson_failed` | Hearts run out mid-lesson | `language`, `lesson_id`, `last_exercise_index`, `total_questions` |
| `lesson_abandoned` | The session is discarded unfinished | `language`, `lesson_id`, `last_exercise_index`, `last_exercise_type`, `total_questions`, `completion_percent`, `duration_seconds` |

`lesson_failed` and `lesson_abandoned` are separate on purpose. One is
about difficulty, the other about interest, and they need different
fixes. `last_exercise_type` is the field that earns the abandonment
event its place: *"60% of the people who quit this lesson quit on the
speaking exercise"* is actionable; *"some people quit"* is not.

Example:

```
lesson_completed
  language = "es"
  lesson_id = "es_u1_l1"
  correct_answers = 8
  total_questions = 10
  completion_percent = 80
  xp_earned = 40
  is_perfect = "false"
  duration_seconds = 95
```

### The Fun Zone

| Event | Fires when | Parameters |
| --- | --- | --- |
| `game_round_started` | A round begins | `language`, `game_mode`, `game_level` |
| `game_round_completed` | A round is finished | `language`, `game_mode`, `game_level`, `completion_percent`, `score` |
| `game_round_failed` | Lives run out | `language`, `game_mode`, `game_level`, `correct_answers`, `total_questions` |

Named for what the app has. There is no "quiz" in LingoQuest; the
nearest thing is a timed round of one of the ten games.

Recorded in `FunProgressController.recordRoundResult`, which every one
of the ten modes funnels through — so a new game gets its analytics
without a call being added to its own controller.

`completion_percent` comes from the accuracy the round was scored on,
rather than a correct/total pair, because accuracy is what actually
reaches that method. Asking for a count it does not hold would mean
each game inventing one.

`game_level` is the level the round was **played** at, captured before
the promotion a high-accuracy round triggers. Reporting the new level
would make every game look as though it were being won a level early —
pinned by a test in `fun_progress_controller_test.dart`.

### Subscription

| Event | Fires when | Parameters |
| --- | --- | --- |
| `paywall_viewed` | The Pro screen opens | `source_screen` |
| `subscription_plan_selected` | A plan card is tapped | `plan`, `billing_period`, `has_free_trial` |
| `purchase_started` | The store sheet is opened | `plan`, `has_free_trial` |
| `purchase_success` | The store confirms | `plan` |
| `purchase_canceled` | The learner backs out | `plan` |
| `purchase_failed` | The store rejects it | `plan`, `reason` |
| `restore_started` / `restore_success` / `restore_failed` | Restore Purchases | `plan`, `reason` |
| `manage_subscription_opened` | The store's management page is opened | — |

`source_screen` on `paywall_viewed` is the reason that event is worth
having. A paywall reached from a locked lesson converts very differently
from one opened out of Settings, and without the source the conversion
rate is one number nobody can act on. It is emitted from the navigation
observer rather than from the Pro screen or its eight callers: the
screen is a `ConsumerWidget`, so anything in its `build` would fire on
every rebuild, and a ninth entry point added later would silently go
uncounted.

`reason` is one of `network`, `already_owned`, `store`, `unknown` —
never the store's own message, which is unbounded developer text that
differs by device, locale and SDK version and would make the metric
uncountable, one bucket per phrasing.

**There is no `purchase` event and no revenue value.** Firebase's
`purchase` event feeds the console's revenue reports, which expect a
verified figure — and this app has no receipt verification, so any
number it reported would be one the store never confirmed. Revenue
belongs to App Store Connect and the Play Console, which know it for
certain.

### Screens

| Event | Fires when | Parameters |
| --- | --- | --- |
| `screen_view` | A route reaches the top | `screen_name`, `screen_class` |
| `screen_time` | That route is left | `screen_name`, `duration_seconds` |

Both come from route changes, not widget builds — a Riverpod screen
rebuilds many times a second while nothing about which screen is open
has changed.

`screen_time` is sent **once per visit**, never per tick. Backgrounding
pauses the clock and banks the time so far; without that, a phone left
face-down overnight on Home reports a fourteen-hour visit, and one of
those drags an average far enough to make the metric meaningless.
Visits under 900ms are dropped: passing through the splash on the way to
Home is not a visit, and a pile of one-second readings pulls every
average down.

Only routes named in `screenNameForPath` count. Dialogs and unnamed
helper routes push and pop constantly, and counting them would bury the
screens that matter.

### Engagement

| Event | Fires when | Parameters |
| --- | --- | --- |
| `feature_used` | A deliberate product action | `feature_name`, `source_screen` |
| `language_switched` | The course is changed | `from_language`, `to_language` |

`feature_used` is for things somebody *chose* to do that say something
about how the app is used. Wiring it to every button would produce a
large, expensive, unreadable stream.

## User properties

Four. Firebase allows 25, but each is a dimension every report can be
sliced by, and a long list of rarely-used ones makes the console harder
to read rather than richer.

| Property | Values | Why |
| --- | --- | --- |
| `selected_language` | `es`, `de`, … | Which course. A code, not "Spanish", so the value does not change with the device locale and split the metric |
| `subscription_status` | `free`, `trial`, `subscribed`, `expired` | Makes every other metric splittable by free versus paying |
| `onboarding_complete` | `true` / `false` | Separates incomplete first runs from returning learners |
| `lessons_bucket` | `0`, `1-5`, `6-20`, `21-50`, `50+` | Cohorting by how far in somebody is. Bucketed because a raw count is high-cardinality, which Firebase handles badly and which is no more useful |

## What is never sent

No name, no email, no phone number, no answer text, no lesson content,
no store receipt, no payment details. Ids in events are the app's own
content ids (`es_u1_l1`) — they identify a lesson, not a person.

**No user ID is set.** LingoQuest has no accounts; the profile is local.
Firebase's own installation identifier is the only one used, which is
what it is designed for. Inventing a personal identifier to fill that
field would be creating personal data the app does not otherwise hold.

Analytics collection is **off in debug builds**
(`setAnalyticsCollectionEnabled(!kDebugMode)`), so a developer tapping
around does not land in the same numbers as real usage. DebugView is a
separate switch and still receives everything — see below.

## Not implemented, and why

Some events in the original brief have nothing in this app to fire them.
An event that never fires is worse than no event: it is a dashboard line
that reads as zero usage rather than as absent.

| Asked for | Why not |
| --- | --- |
| `login`, `sign_up` | No accounts. The profile is local |
| `ai_feature_used` | No AI feature exists in LingoQuest |
| `reading_*`, `writing_*` | Not exercise types. The eight real ones are in `ExerciseType`; `listening` and `speaking` are among them and are covered by a lesson's parameters |
| `quiz_*` | No quiz. `game_round_*` is the same measurement under the name the app uses |
| `practice_*` | Practice is a review lesson — `lesson_started` with `is_review = true` |
| `profile_viewed` | No profile screen. Settings and Statistics are covered by `screen_view` |

## Testing with DebugView

DebugView shows events within seconds, individually, before they are
aggregated. It is the only practical way to verify this before release.

```bash
# Turn it on for LingoQuest (survives reinstalls, not a factory reset)
adb shell setprop debug.firebase.analytics.app com.lernova.lernova

# Turn it off again
adb shell setprop debug.firebase.analytics.app .none.
```

Then **Firebase Console → Analytics → DebugView** and pick the device.

Debug builds have collection disabled, so test a **profile or release**
build:

```bash
flutter run --profile
```

### What to exercise, and what should appear

| Do this | Expect |
| --- | --- |
| Launch the app | `session_start`, `screen_view` (`splash` → `home`) |
| Leave Home for the Path | `screen_time` on `home`, `screen_view` on `path` |
| Open a lesson and answer one question | `lesson_started` |
| Back out mid-lesson | `lesson_abandoned` with `last_exercise_index` |
| Finish a lesson | `lesson_completed` with `completion_percent` |
| Tap a locked lesson | `paywall_viewed` with `source_screen = path` |
| Tap a plan, then cancel the sheet | `subscription_plan_selected`, `purchase_started`, `purchase_canceled` |
| Background the app for a minute, return | No `screen_time` inflation |

User properties appear under **DebugView → the device card → User
properties**, and take a few minutes to settle.

## Where the numbers live afterwards

DebugView is for verification. Aggregated reporting is 24 hours behind.

| Question | Where |
| --- | --- |
| Daily / monthly active users | Reports → Realtime, and Engagement → Overview |
| Sessions, average engagement time | Engagement → Overview |
| Most visited screens, time per screen | Engagement → Pages and screens |
| Retention cohorts | Retention |
| Lesson completion, abandonment | Engagement → Events → `lesson_completed` / `lesson_abandoned` |
| Language popularity | Any report → compare by `selected_language` |
| Free versus paying behaviour | Any report → compare by `subscription_status` |
| Paywall and purchase conversion | Explore → Funnel exploration |

### Building the funnels

The two worth creating by hand, in **Explore → Funnel exploration**:

**Onboarding.** Steps: `first_open` → `onboarding_started` →
`language_selected` → `onboarding_completed` → `lesson_started`. Shows
where first-run loses people.

**Purchase.** Steps: `paywall_viewed` → `subscription_plan_selected` →
`purchase_started` → `purchase_success`. Break down by `source_screen`
to see which entry point converts.

For lesson drop-off, **Explore → Free form**: rows `lesson_id`, values
`lesson_started` and `lesson_completed`, and the ratio is the completion
rate per lesson. Add `last_exercise_type` as a second dimension on
`lesson_abandoned` to see which exercise loses people.

Mark `purchase_success` and `lesson_completed` as **conversions**
(Admin → Events) so they appear in the conversion reports.

## Verification checklist before a Play release

- [ ] `google-services.json` is in `android/app/` and its
      `package_name` is `com.lernova.lernova`
- [ ] The Google services Gradle plugin is applied in both
      `settings.gradle.kts` and `app/build.gradle.kts`
- [ ] `flutter run --profile` on a device, with
      `debug.firebase.analytics.app` set
- [ ] DebugView shows `screen_view` changing as you move between tabs
- [ ] `lesson_started` and `lesson_completed` both appear for one lesson
- [ ] `lesson_abandoned` appears when backing out mid-lesson
- [ ] `screen_time` appears once per screen, with a plausible duration
- [ ] `paywall_viewed` carries the right `source_screen`
- [ ] The four user properties are set on the device card
- [ ] No parameter anywhere contains a name, an email or answer text
- [ ] The app still launches with `google-services.json` **removed**
      (the no-op path — this is what stops a config mistake becoming a
      crash for every user)
- [ ] `flutter analyze` is clean and `flutter test` passes

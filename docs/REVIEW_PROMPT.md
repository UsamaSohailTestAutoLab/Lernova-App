# Asking for a store review

LingoQuest asks for a rating through the platform's own prompt, once the
learner has actually used the app, at the moment a lesson's rewards
finish and they are handed back to Home.

```
review_service.dart          The only caller of the platform API.
review_prompt_state.dart     What we remember: asks made, when, since when.
review_prompt_controller.dart  The policy — when we may ask.
lesson_flow_nav.dart         The single hook: finishLessonFlow().
settings_screen.dart         "Rate LingoQuest" → the write-review page.
```

## The rules Apple enforces, and where they live

| Rule | Where it is honoured |
| --- | --- |
| Ratings must use the provided API, never a custom dialog | `ReviewService` is the only thing that touches `in_app_review`; nothing in the app draws a rate-us sheet |
| No pre-question that routes only happy users to the prompt | There is no pre-question. Eligibility is decided from behaviour that already happened, then the system prompt is requested directly |
| No incentive for reviewing | Nothing is granted. No XP, no hearts, no Pro time |
| Don't interrupt a task | The only automatic ask is in `finishLessonFlow`, after `context.go(home)` |
| Don't ask on first launch or during onboarding | Three completed lessons *and* three days of gap are required first |
| The system decides whether anything appears | `requestReview()` returns no result, and nothing in the app branches on whether a prompt was seen |

**iOS shows the prompt at most three times per 365 days per user, and
silently drops the rest.** That quota is the platform's, not ours — we
cannot read it, raise it, or find out whether a given request was
honoured. Our own thresholds exist so those scarce chances land on
someone with an opinion worth giving.

## When LingoQuest asks

All of these must be true:

- the lesson **did not** end out of hearts
- at least **3 lessons** completed
- at least **3 days** since the first time both of the above were true
- fewer than **3 asks** made on this install, ever
- at least **120 days** since the last ask
- no ask yet in this run of the app
- the platform reports the prompt is available

The clock starts at first eligibility rather than at install, so time
counts from real engagement and not from a download someone never opened
again. `ReviewPromptOutcome` names the reason for every refusal, which is
what the tests assert against.

An unavailable store is checked **last**, so a simulator or an offline
device cannot spend one of the three slots.

## The Settings row

`Settings → About → Rate LingoQuest` calls `openStoreListing()`, **not**
`requestReview()`. Someone who taps a button asking for the review page
must get the review page; a request that the system may silently ignore
would read as a broken button.

## Before release

`kAppStoreId` in `review_service.dart` is `null`. Apple assigns that
number when the app is created in App Store Connect, and it cannot be
guessed — with it unset, the Settings row tells the learner the listing
is not live yet instead of opening the wrong app. **Set it before
shipping**, or that row never works.

Android needs nothing: Play In-App Review resolves the listing from the
package name.

## Testing it

`test/unit/review_prompt_test.dart` covers the policy against a fake
store — the thresholds, every refusal reason, the budget, persistence
across a restart, and a corrupt blob.

On a real device the prompt is hard to observe:

- **iOS** never shows it in a debug build launched from Xcode. Use a
  TestFlight build; even then it is rate-limited, and a learner who has
  turned ratings off in Settings will never see it.
- **Android** shows a fake-but-real flow for an internal-testing build
  installed from Play. Sideloaded debug APKs get nothing.

Because neither platform reports the outcome, "did the prompt appear?" is
not a question the app can answer, and no feature may be built on the
assumption that it did.

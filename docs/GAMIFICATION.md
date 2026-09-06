# Gamification formulas

Every number below lives in code (mostly `lib/core/constants/game_constants.dart` plus the pure logic files in `lib/core/utils/`), not scattered inline — this doc mirrors those constants so there's one place to check "why did I get exactly this much XP."

## XP

| Event | XP |
|---|---|
| Correct answer, first try (lesson exercise or Fun question) | 10 |
| Correct answer, after a retry within the same session | 5 |
| Lesson completion bonus | +10 |
| Perfect lesson bonus (100% first-try accuracy) | +20 more |

A lesson's total XP = sum of per-exercise XP + the completion bonus (+ the perfect bonus if applicable). Fun rounds work the same way at the per-question level (`FallingWordSessionController`), plus a combo multiplier — see `docs/FUN_TAB.md`.

Review sessions (replaying just the words in your mistake bank) award per-answer XP but **not** the lesson completion/perfect bonus — they're practice, not a "lesson."

## Levels

```
level = (totalXp ÷ 500) + 1
```

500 XP per level, flat. Crossing a boundary mid-result triggers the level-up celebration beat. `XpUtils.levelProgress(totalXp)` returns how far through the current level you are (0–1), used to drive the level progress ring on Home/Profile/Fun result screens.

## Hearts

- Max hearts: **5** (unlimited for Premium users).
- Losing a heart: −1 per wrong answer in a lesson.
- Regeneration: **+1 heart every 4 hours** of real elapsed time, computed from `lastHeartLostAt` — recalculated on every app resume via `HeartsLogic.regenerate`, so hearts are already correct the instant the app opens, not just when a lesson is attempted.
- At 0 hearts (non-Premium): new lesson exercises are blocked; the Hearts screen offers a free ad-mock refill (+1), a gem-purchase full refill (350 gems), or Premium.

**Fun-tab lives are a separate, session-local pool (3 per round)** — not the same resource as lesson hearts. This is deliberate: Fun is meant to be a low-friction "quick game" loop, and tying it to the same scarce global resource as core lessons would let a bad Fun round block your ability to do lessons (or vice versa). See `docs/FUN_TAB.md` for how those lives work.

## Streaks

- `streakCount` increments **once per calendar day**, the first time that day's XP crosses the daily goal.
- On app resume, `StreakLogic.reconcileOnResume` checks the gap since `lastStreakDate`:
  - Same day or yesterday → untouched (still within grace).
  - More than one day missed, **with** a streak freeze available → the freeze is consumed and the streak survives.
  - More than one day missed, **no** freeze → streak resets to 0.
- A streak freeze is purchased from the Shop for 200 gems and is consumed automatically the next time it's needed — there's no manual "activate" step.

## Daily goal

- User picks a target during onboarding (10 / 20 / 30 / 50 XP), editable later in Settings.
- `dailyXp` resets to 0 the first time the app is opened on a new calendar day (`DailyGoalLogic.reconcileOnResume`).
- The Home ring and the post-lesson "Daily Goal" result beat both read `DailyGoalLogic.isGoalMet`/`progressRatio` — no separate copy of this logic anywhere.

## Gems (soft currency)

Earned from: perfect lessons (+10), unlocking an achievement (+50 each), and Fun-round rewards (small per-correct-answer amounts, see `docs/FUN_TAB.md`). Spent in the Shop:

| Item | Cost |
|---|---|
| Heart refill | 350 gems |
| Streak freeze | 200 gems |
| Mascot outfit (cosmetic only) | 500 gems |

"Coins" shown in the Fun tab are the same `gems` field — Fun just uses a friendlier label for it rather than running a second currency.

## Course/lesson unlocking

- Lesson *N+1* unlocks once lesson *N* is completed (any accuracy — completion isn't gated on a score).
- Unit *N+1* unlocks once every lesson in unit *N* is completed.
- The placement test can jump `unlockedUnitIndex` straight to a later unit for a user who tests out of the basics — implemented as one pure function, `CourseProgress.resolveUnlockedUnitIndexAfterCompletion`, unit-tested directly against a fixture course.

## Weekly league / leaderboard

- A deterministic bot cohort (~9 entries) is generated from the current ISO week id (`LocalLeaderboardRepository.generateCohort`) — same week always produces the same cohort, so it doesn't feel random session to session, and only changes when a new week starts.
- The real user's entry is merged in, sorted by `weeklyXp`.
- On week rollover, `LeagueLogic.resolveNextTier` ranks the user against the *previous* week's cohort: top ~30% promotes a tier, bottom ~30% demotes, the middle holds. Tiers: Bronze → Silver → Gold → Sapphire → Emerald → Diamond (can't promote past Diamond or demote past Bronze).

## Achievements

Rule-based, evaluated in one place (`AchievementLogic.evaluateNewlyUnlocked`) against the current `UserProgress` snapshot plus a few event flags from whatever just happened (perfect lesson, unit/course completed, perfect Fun round, a "speed learner" round). Each unlock pays `gemsPerAchievement` (50) once. Full catalog lives in `lib/data/models/achievement.dart`:

first lesson · 3/7/30-day streak · 100/500/1000 total XP · a perfect lesson · 5 lessons in one day · unit complete · course complete · **100 words mastered** · **50 phrases mastered** · **a "speed learner" Fun round** · **a perfect Fun round** (the last four are Fun-specific — see `docs/FUN_TAB.md`).

"Words" vs. "phrases" mastered are both counted from the same shared `vocabStrength` map, distinguished by an id convention: phrase ids contain a `_phrase_` marker segment (e.g. `es_phrase_como_estas`), so there's no second tracking map — just a filter on the one map everything already writes to.

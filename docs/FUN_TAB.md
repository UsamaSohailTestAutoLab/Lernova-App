# The Fun tab

A casual-game hub layered on top of the same course content and the same gamification ledger as the main learning Path — playing Fun moves the same XP, streak, and vocabulary-mastery numbers shown everywhere else in the app (see `docs/ARCHITECTURE.md` → "The gamification core").

## Scope

The original spec called for 10 game modes. Building all 10 to a genuine "polished mobile game" bar in one pass would have diluted quality across the board, so the shipped scope is:

- The **full shared engine** — content models, all 9 question-combination types, adaptive difficulty, indefinitely-scaling levels, rewards, a daily challenge, and dedicated achievements.
- **A shared core loop** behind the catching games: Falling Words, Word Rush and Word Survival are one controller with different tuning and presentation.
- A **Fun Hub** that shows every mode as a real, level-gated card (`GameModeCard`), in `FunGameMode.values` order.

## Game modes

Every mode listed here is built. The order below is the order of
`FunGameMode.values`, which is the order the hub's grid renders.

| Mode | Unlocks at | Notes |
|---|---|---|
| Word Bubble (Falling Words) | 1 | The flagship — rising bubble field |
| Word Rush | 1 | Same engine, faster/always-combo tuning |
| Word Match | 3 | |
| Memory Match | 4 | |
| Phrase Builder | 6 | Phrase-only question types |
| Listen & Catch | 7 | Audio-only question types |
| Conversation Challenge | 9 | |
| Sentence Builder | 5 | |
| Meaning Shooter | 8 | |
| Word Survival | 10 | The rising-water game — see below |

Unlock levels are the *overall* Fun level (the max across implemented modes), defined per mode in `FunGameModeX.unlockLevel` (`lib/core/constants/app_enums.dart`).

## The question-generation engine

`FunQuestionGenerator.generateRound(...)` (`lib/features/fun/application/fun_question_generator.dart`) builds a round from a word/phrase pool plus a `FunLevelConfig`. It covers all 10 combinations from the original spec via **9 question types** (`FunQuestionType`) — the "meaning → word" combo collapses two spec examples into one mechanical shape:

`wordToMeaning` · `meaningToWord` · `imageToWord` · `wordToImage` · `audioToMeaning` (real synthesized speech via the same `TtsService` the Listening exercise uses) · `wordToSynonym` · `wordToOpposite` · `phraseToMeaning` · `meaningToPhrase`

**Adaptive difficulty**: word selection is weighted by the *same* `vocabStrength` map lessons write to — a word with low or negative strength is picked far more often than a mastered one (`weight = (6 - strength).clamp(1, 8)`, sampled without replacement). This is spaced-repetition-lite riding on real mastery data instead of a second tracker.

**Distractor safety**: options are deduplicated against the correct answer before shuffling, so a round can never present two visually-identical "correct" bubbles.

**Graceful degradation**: a word without synonym/antonym data simply isn't eligible for those question types that round; a word without an `emoji` isn't eligible for image types. Nothing crashes on missing content — it just picks a different combination.

## Difficulty scaling

`FunLevelCatalog.configFor(level, {isRush})` (`lib/features/fun/application/fun_level_catalog.dart`) is a **formula**, not a lookup table, because difficulty has to keep scaling past level 10 indefinitely:

- Word count and choice count grow with level (capped).
- Fall duration shrinks toward a floor as level rises.
- Question types unlock cumulatively: word/meaning from level 1 → +image at 3 → +phrase at 4 → +audio at 5 → +synonym/antonym at 7.
- Combo scoring turns on at level 6 for Falling Words; Word Rush has it on from level 1 (`isRush: true` overrides the curve for a faster, combo-first feel throughout).

## Playing a round (Falling Words / Word Rush)

`FallingWordSessionController` (`lib/features/fun/application/falling_word_session_controller.dart`) drives both modes — Word Rush is the same controller with a different `FunLevelConfig` preset, not a separate implementation.

- **3 session-local lives** per round (see `docs/GAMIFICATION.md` for why these are separate from lesson hearts).
- Each question resolves immediately on tap (or on a fall-timer timeout) — no blocking "continue" screen, since a falling-word game lives or dies on feeling instant.
- **Combo**: correct answers chain a combo counter; the XP multiplier steps at 5/10/20/30 combo (🔥 escalation in the HUD), matching the spec's combo framing.
- A round ends either by finishing every question (success) or hitting 0 lives (failure) — both routes to `FunRoundResultsScreen`, which frames the same underlying data as either "Level Complete! 🎉" (with a "Next Level"/"Play Again" choice) or "Almost there! 💪" (with a "Practice Mistakes" option that regenerates a focused round from just the missed words via `FunQuestionGenerator.generatePracticeRound`).
- `finishAndApply()` is the single point where the round's tally is committed: `ProgressController.awardFunSession(...)` (XP/coins/vocab mastery) and `FunProgressController.recordRoundResult`/`recordWordsLearnedToday` (per-mode level-up on ≥70% accuracy, daily-challenge word tracking) — called exactly once per round, verified by a test that calls it twice and asserts the second call is a no-op.

## Daily challenge

"Learn 10 words today" — `FunDailyChallengeLogic` tracks a `Set<String>` of distinct vocab ids answered correctly that day, reconciled (reset) on a date rollover the same way the core daily-XP-goal is. Crossing the 10-word threshold pays +50 XP / +20 gems once and flips `dailyChallengeCompletedToday`; the Fun Hub shows live progress via `DailyChallengeCard`.

## Word Survival

Its own mode, last in the list and last to unlock. It was originally bolted onto Word Bubble as *level 1 only*, which made the very first round anyone played a different game from the nine that followed it, and left the survival idea with nowhere to grow — it could never be harder than level 1, because it *was* level 1.

Every Word Survival level is a themed presentation over the *identical* underlying session logic — same lives, same XP, same win/fail rules, same difficulty curve from `FunLevelCatalog`. Only how the question and its answers are drawn changes:

- An original, custom-painted **cartoon human character** (`CartoonCharacter`, `lib/features/fun/presentation/widgets/cartoon_character.dart`) stands at a fixed spot near the bottom of the screen — a distinct character from the app's abstract "Spark" mascot used everywhere else, drawn entirely with `CustomPainter` (no image assets).
- An animated **rising water** (`RealisticWater`, two phase-shifted sine-wave layers over a gradient) sits *in front of* the character in paint order, so as it rises it visually covers more of the character rather than the character floating on top of it.
- **Drowning is proportional to hearts lost**: water height is interpolated from a shallow "ankle-deep" level at full health up to a height guaranteed to fully cover the character once every life is gone — `lostFraction = (maxLives - lives) / maxLives` drives the interpolation directly, so losing hearts gradually and visibly submerges the character instead of jumping straight to fully drowned.
- The character's **mood** reflects both its persistent state (happy at full health → worried on the last life → "drowning" expression once the round has failed) and a brief transient reaction on each answer (a celebrate flash on correct, a worried flash on wrong), implemented in `_FallingWordGameScreenState._baseMoodForLives`/`_flashMood`.
- Answer options render as **larger, static, glossier bubbles** in a `Wrap` instead of the rising `BubbleField` every other mode uses — reusing `WaterBubble` with bigger size overrides rather than a second widget.

The branch point is one boolean in `FallingWordGameScreen`: `isWaterSurvivalLevel = session.mode == FunGameMode.wordSurvival`. Every other mode renders through the original falling-bubbles path, completely untouched.

The stake is explained once before the first round (`WaterSurvivalIntroScreen`, gated on `waterSurvivalTutorialId` in `UserProgress.seenTutorialIds`) — meeting it cold means finding out what the water does by drowning in it.

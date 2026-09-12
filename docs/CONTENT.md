# Course content

LingoQuest ships ten languages. Spanish is hand-authored; the other nine
are generated from compact specs.

## Layout

| File | Owner |
|---|---|
| `assets/data/languages.json` | hand-edited — the list of languages the app offers |
| `assets/data/course_es.json` | **hand-authored.** Never generated. |
| `assets/data/fun/*_es.json` | **hand-authored.** Never generated. |
| `assets/data/course_<id>.json` | generated |
| `assets/data/fun/{vocab,phrases,conversations}_<id>.json` | generated |
| `tool/content/<id>.json` | the source of truth for a generated language |

**Do not hand-edit a generated file.** The next build overwrites it.
Edit `tool/content/<id>.json` and rebuild.

## Rebuilding

```bash
node tool/build_courses.mjs        # every language
node tool/build_courses.mjs de fr  # just these
```

Output is deterministic — the same spec produces a byte-identical file,
so a rebuild with no spec change is an empty diff.

## Why a generator

Every course has to satisfy the rules the content tests enforce:

- a lesson may only use a word it has already taught (`lesson_review_coverage_test`)
- every target-language answer ships an English meaning, and that
  meaning is never just the answer repeated (`course_content_gloss_test`)
- sentence building never opens a round (`sentence_building_test`)
- no lesson teaches fewer than five words

Getting that right nine times, in nine languages, is not something to
trust to review. `tool/build_courses.mjs` checks each rule as it builds
and **refuses to emit a language that breaks one**, naming the lesson
and the offending word. A failed build is the intended way to find out.

The generator is stricter than the tests on purpose: it requires *every*
token of every sentence, spoken phrase and fill-in-the-blank to be a
word the lesson teaches. The tests allow a short list of grammatical
glue ("de", "la", "por") as an exemption, which exists for Spanish —
generated content never needs it.

## Adding a language

1. Add it to `assets/data/languages.json`.
2. Add its TTS locale to `TtsLocales` (`lib/core/utils/tts_locales.dart`).
3. Write `tool/content/<id>.json` and add the locale to `TTS_LOCALES` in
   the generator.
4. Run the generator until it stops complaining.
5. Run the suite — the content tests discover courses from the assets
   directory, so a new language is checked without editing any test.

No Dart changes are needed: the course repository finds each course by
convention (`course_<id>.json`), and a language listed without a course
file is shown as "Coming soon" rather than crashing.

## Spec shape

Each of the three units holds three lessons, and each lesson declares:

- `words` — five content words (`w`, `en`, `emoji`, `cat`)
- `support` — the grammar words the lesson's sentences need ("I have",
  "is", "on the"). The first one becomes its own multiple-choice
  question *before* the sentence steps, which is the whole point: a
  sentence assembled from words nobody taught is a puzzle, not a
  language exercise.
- `review` — ids of words taught in earlier lessons to show again
- `speak`, `sentence`, `fill` — the phrase, the chip sentence, and the
  gapped sentence, each with its English

From those the generator emits nine exercises per lesson covering all
eight exercise types, plus the Fun vocabulary pool, the phrase list
(drawn from the sentences the course already teaches, so Phrase Builder
can never surface something the Path has not covered) and the
conversations.

## Known gaps

- **Japanese and Chinese sentences are written with spaces between
  words.** Natural text has none; the spacing is what lets a learner
  see the units a sentence is built from, and what makes the chip
  exercise possible at all.
- **No romanization field.** Japanese and Chinese words are shown in
  their own script with an English meaning and TTS. Furigana/pinyin
  would need a schema change on `VocabWord` and every exercise payload.
- **Fun content is thinner than Spanish's.** Each generated language has
  three conversations to Spanish's four, and ~90 vocabulary words to
  Spanish's 104.

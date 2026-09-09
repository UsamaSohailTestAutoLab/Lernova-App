#!/usr/bin/env node
// Builds `assets/data/course_<id>.json` and the three
// `assets/data/fun/*_<id>.json` files from the compact language specs in
// `tool/content/`.
//
// Why a generator rather than hand-authored JSON: every course has to
// obey the same rules the content tests enforce — a lesson may only use
// words it has already taught, every target-language answer ships an
// English meaning, no lesson teaches fewer than five words. Getting
// that right nine times by hand, in nine languages, is not something to
// trust to review. Here the rules are checked at build time and a spec
// that breaks one fails loudly instead of shipping.
//
// Spanish is deliberately NOT generated. Its content is hand-tuned and
// stays that way; this pipeline exists so every *other* language reaches
// the same standard.
//
// Usage: node tool/build_courses.mjs [languageId ...]

import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const contentDir = join(root, 'tool', 'content');

const TTS_LOCALES = {
  fr: 'fr-FR', de: 'de-DE', it: 'it-IT', pt: 'pt-PT', nl: 'nl-NL',
  tr: 'tr-TR', ar: 'ar-SA', ja: 'ja-JP', zh: 'zh-CN',
};

const UNIT_ACCENTS = ['green', 'amber', 'teal'];

/** Punctuation stripped before comparing words across scripts. */
const PUNCT = /[\s.,!?¡¿'"“”‘’()،؛؟。、？！：；]+/u;

const tokens = (text) =>
  String(text)
    .toLowerCase()
    .split(PUNCT)
    .map((t) => t.replace(/_/g, ''))
    .filter(Boolean);

/** Deterministic shuffle so a rebuild produces a byte-identical file. */
function seededShuffle(items, seed) {
  const out = [...items];
  let s = seed >>> 0;
  for (let i = out.length - 1; i > 0; i--) {
    s = (s * 1664525 + 1013904223) >>> 0;
    const j = s % (i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

class SpecError extends Error {}

function buildLanguage(spec) {
  const lang = spec.id;
  const locale = TTS_LOCALES[lang];
  if (!locale) throw new SpecError(`No TTS locale registered for "${lang}"`);

  const problems = [];
  const vocabById = new Map();
  const properNouns = new Set(
    (spec.properNouns ?? []).map((n) => n.toLowerCase()),
  );

  const registerWord = (w, where) => {
    const id = `${lang}_${w.id}`;
    const existing = vocabById.get(id);
    if (existing && existing.word !== w.w) {
      problems.push(`${where}: "${w.id}" is "${existing.word}" elsewhere, "${w.w}" here`);
    }
    if (!existing) {
      vocabById.set(id, {
        id,
        word: w.w,
        translation: w.en,
        languageId: lang,
        category: w.cat,
        emoji: w.emoji,
      });
    }
    return id;
  };

  // Words are registered before any lesson is built so a lesson may
  // review something a later lesson teaches — the review step is only
  // ever additional exposure, never the first sighting of an answer.
  for (const unit of spec.units) {
    for (const lesson of unit.lessons) {
      for (const w of lesson.words) registerWord(w, `${unit.title}/${lesson.title}`);
      for (const w of lesson.support ?? []) registerWord(w, `${unit.title}/${lesson.title}`);
    }
  }
  for (const w of spec.extraVocab ?? []) registerWord(w, 'extraVocab');

  const units = spec.units.map((unit, unitIndex) => {
    const lessons = unit.lessons.map((lesson, lessonIndex) => {
      const key = `${lang}_u${unitIndex + 1}_l${lessonIndex + 1}`;
      const words = lesson.words;
      const support = lesson.support ?? [];
      if (words.length < 5) {
        problems.push(`${key}: only ${words.length} words; five is the minimum a lesson may teach`);
      }

      const reviewVocabIds = [
        ...support.map((w) => `${lang}_${w.id}`),
        ...(lesson.review ?? []).map((id) => `${lang}_${id}`),
      ];
      for (const id of reviewVocabIds) {
        if (!vocabById.has(id)) problems.push(`${key}: review id "${id}" is not vocabulary`);
      }

      // Everything this lesson puts in front of the learner before it
      // grades them on it.
      const taught = new Set();
      for (const w of [...words, ...support]) tokens(w.w).forEach((t) => taught.add(t));
      for (const id of lesson.review ?? []) {
        const entry = vocabById.get(`${lang}_${id}`);
        if (entry) tokens(entry.word).forEach((t) => taught.add(t));
      }

      const requireTaught = (text, where) => {
        for (const t of tokens(text)) {
          if (taught.has(t) || properNouns.has(t)) continue;
          problems.push(`${key}/${where}: "${t}" is used before anything teaches it`);
        }
      };

      const meanings = words.map((w) => w.en);
      const forms = words.map((w) => w.w);
      const optionsFrom = (correct, pool, seed) => {
        const others = pool.filter((o) => o !== correct).slice(0, 3);
        const options = seededShuffle([correct, ...others], seed);
        return { options, correctIndex: options.indexOf(correct) };
      };

      const exercises = [];
      const push = (type, vocabId, payload) =>
        exercises.push({ id: `${key}_e${exercises.length + 1}`, type, vocabId, payload });

      // 1 — recognise the word beside its picture, answer in English.
      push('imageRecognition', `${lang}_${words[0].id}`, {
        prompt: 'What does this word mean?',
        emoji: words[0].emoji,
        targetWord: words[0].w,
        meaning: words[0].en,
        distractorMeanings: meanings.slice(1, 4),
        distractorWords: forms.slice(1, 4),
      });

      // 2 — pick the form for a meaning.
      const mc2 = optionsFrom(words[1].w, forms, 11 + unitIndex * 3 + lessonIndex);
      push('multipleChoice', `${lang}_${words[1].id}`, {
        prompt: `Which word means '${words[1].en}'?`,
        options: mc2.options,
        correctIndex: mc2.correctIndex,
      });

      // 3 — hear it.
      const listen = optionsFrom(words[2].w, forms, 23 + unitIndex * 3 + lessonIndex);
      push('listening', `${lang}_${words[2].id}`, {
        prompt: 'Listen and select what you hear',
        audioText: words[2].w,
        ttsLocale: locale,
        options: listen.options,
        correctIndex: listen.correctIndex,
        translation: words[2].en,
      });
      requireTaught(words[2].w, 'listening');

      // 4 — the grammar word the sentence steps will lean on. Taught as
      // its own question *before* the sentence, which is the whole
      // reason `support` exists: "I have" is nobody's vocabulary card,
      // and a sentence built from words nobody taught is a puzzle.
      const supportWord = support[0] ?? words[4];
      const mc4 = optionsFrom(
        supportWord.w,
        [supportWord.w, ...forms.filter((f) => f !== supportWord.w)],
        37 + unitIndex * 3 + lessonIndex,
      );
      push('multipleChoice', `${lang}_${supportWord.id}`, {
        prompt: `Which word means '${supportWord.en}'?`,
        options: mc4.options,
        correctIndex: mc4.correctIndex,
      });

      // 5 — produce the English.
      push('translation', `${lang}_${words[3].id}`, {
        prompt: 'Type the English meaning',
        sourceText: words[3].w,
        acceptableAnswers: [words[3].en.toLowerCase(), words[3].en],
      });
      requireTaught(words[3].w, 'translation');

      // 6 — say it.
      push('speaking', `${lang}_${words[0].id}`, {
        prompt: 'Say this phrase out loud',
        targetPhrase: lesson.speak.phrase,
        translation: lesson.speak.en,
        ttsLocale: locale,
      });
      requireTaught(lesson.speak.phrase, 'speaking');

      // 7 — the summary matching set.
      const pairs = words.slice(0, 4).map((w) => ({ left: w.w, right: w.en }));
      push('wordMatching', `${key}_set`, {
        prompt: 'Match each word to its meaning',
        pairs,
      });

      // 8 — build the sentence, only now that every word in it is known.
      push('sentenceArrangement', `${lang}_${words[0].id}`, {
        prompt: 'Build the sentence',
        shuffledChips: seededShuffle(lesson.sentence.chips, 53 + unitIndex * 3 + lessonIndex),
        correctSentence: lesson.sentence.chips,
        translation: lesson.sentence.en,
      });
      requireTaught(lesson.sentence.chips.join(' '), 'sentence');

      // 9 — the same sentence shape with a hole in it.
      const fill = lesson.fill;
      push('fillInTheBlank', `${lang}_${fill.vocab}`, {
        prompt: 'Complete the sentence',
        sentenceTemplate: fill.template,
        options: seededShuffle(
          [fill.answer, ...fill.distractors],
          67 + unitIndex * 3 + lessonIndex,
        ),
        correctAnswer: fill.answer,
        translation: fill.en,
      });
      requireTaught(fill.template.replace(/_+/g, ' '), 'fill template');
      requireTaught(fill.answer, 'fill answer');
      if (!vocabById.has(`${lang}_${fill.vocab}`)) {
        problems.push(`${key}: fill vocab "${fill.vocab}" is not vocabulary`);
      }

      // Review Words is built from the ids a lesson names: its
      // exercises' `vocabId`s plus `reviewVocabIds`. A lesson word that
      // happens not to be any exercise's subject — the fifth one,
      // whenever a support word takes the slot — would otherwise be
      // used in the sentence step having never been shown as a card.
      const referenced = new Set(
        exercises
          .filter((e) => e.type !== 'wordMatching')
          .map((e) => e.vocabId),
      );
      for (const w of [...words, ...support]) {
        const id = `${lang}_${w.id}`;
        if (!referenced.has(id) && !reviewVocabIds.includes(id)) {
          reviewVocabIds.push(id);
        }
      }

      // The coverage test counts distinct review cards, and a lesson
      // that teaches four is the thin review step learners complained
      // about.
      const cards = new Set([
        ...words.map((w) => w.w.toLowerCase()),
        ...support.map((w) => w.w.toLowerCase()),
        ...(lesson.review ?? []).map(
          (id) => vocabById.get(`${lang}_${id}`)?.word.toLowerCase(),
        ),
      ]);
      cards.delete(undefined);
      if (cards.size < 5) problems.push(`${key}: only ${cards.size} review cards`);

      return {
        id: key,
        title: lesson.title,
        subtitle: lesson.subtitle ?? words.map((w) => w.w).join(', '),
        icon: lesson.icon,
        reviewVocabIds,
        exercises,
      };
    });

    return {
      id: `${lang}_u${unitIndex + 1}`,
      title: unit.title,
      description: unit.description,
      icon: unit.icon,
      accent: UNIT_ACCENTS[unitIndex] ?? 'green',
      lessons,
    };
  });

  // Placement: three questions from each of the first two units and two
  // from the last, so answering the early ones right is what unlocks a
  // later start.
  const placementQuestions = [];
  const perUnit = [3, 3, 2];
  spec.units.forEach((unit, unitIndex) => {
    const pool = unit.lessons.flatMap((l) => l.words);
    for (let i = 0; i < perUnit[unitIndex]; i++) {
      const word = pool[i * 2] ?? pool[i];
      const distractors = pool
        .filter((w) => w.en !== word.en)
        .slice(i * 3, i * 3 + 3)
        .map((w) => w.en);
      while (distractors.length < 3) distractors.push(`Word ${distractors.length + 1}`);
      const options = seededShuffle([word.en, ...distractors], 91 + unitIndex * 5 + i);
      placementQuestions.push({
        id: `p${placementQuestions.length + 1}`,
        prompt: `What does '${word.w}' mean?`,
        options,
        correctIndex: options.indexOf(word.en),
        unlocksUnitIndex: unitIndex,
      });
    }
  });

  const course = {
    id: `course_${lang}`,
    languageId: lang,
    title: spec.name,
    description: spec.description,
    units,
    placementQuestions,
  };

  // Fun phrases come from the sentences the course already teaches, so
  // Phrase Builder can never surface a phrase the Path has not covered.
  const phrases = [];
  spec.units.forEach((unit, unitIndex) => {
    unit.lessons.forEach((lesson, lessonIndex) => {
      phrases.push({
        id: `${lang}_phrase_u${unitIndex + 1}_l${lessonIndex + 1}_a`,
        phrase: lesson.speak.phrase,
        meaning: lesson.speak.en,
        languageId: lang,
        category: unit.phraseCategory ?? 'greetings',
      });
      phrases.push({
        id: `${lang}_phrase_u${unitIndex + 1}_l${lessonIndex + 1}_b`,
        phrase: lesson.sentence.chips.join(' '),
        meaning: lesson.sentence.en,
        languageId: lang,
        category: unit.phraseCategory ?? 'greetings',
      });
    });
  });

  const conversations = (spec.conversations ?? []).map((c, i) => ({
    id: `${lang}_conv_${c.id}`,
    title: c.title,
    scenario: c.scenario,
    languageId: lang,
    turns: c.turns.map((t, j) => ({
      id: `${lang}_conv_${c.id}_t${j + 1}`,
      line: t.line,
      lineEnglish: t.lineEn,
      options: t.options,
      optionsEnglish: t.optionsEn,
      correctIndex: t.correctIndex ?? 0,
    })),
  }));
  void conversations.length;

  if (problems.length) {
    throw new SpecError(`${lang}:\n  - ${problems.join('\n  - ')}`);
  }

  return {
    course,
    vocab: [...vocabById.values()],
    phrases,
    conversations,
  };
}

const write = (path, data) =>
  writeFileSync(join(root, path), `${JSON.stringify(data, null, 2)}\n`, 'utf8');

const only = process.argv.slice(2);
const specFiles = readdirSync(contentDir)
  .filter((f) => f.endsWith('.json'))
  .filter((f) => only.length === 0 || only.includes(f.replace('.json', '')));

let failed = false;
for (const file of specFiles.sort()) {
  const spec = JSON.parse(readFileSync(join(contentDir, file), 'utf8'));
  try {
    const built = buildLanguage(spec);
    write(`assets/data/course_${spec.id}.json`, built.course);
    write(`assets/data/fun/vocab_${spec.id}.json`, built.vocab);
    write(`assets/data/fun/phrases_${spec.id}.json`, built.phrases);
    write(`assets/data/fun/conversations_${spec.id}.json`, built.conversations);
    const lessons = built.course.units.reduce((n, u) => n + u.lessons.length, 0);
    console.log(
      `built ${spec.id}: ${lessons} lessons, ${built.vocab.length} words, ` +
        `${built.phrases.length} phrases, ${built.conversations.length} conversations`,
    );
  } catch (e) {
    failed = true;
    console.error(e instanceof SpecError ? `FAILED ${e.message}` : e);
  }
}
process.exit(failed ? 1 : 0);

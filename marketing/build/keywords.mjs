// Builds the keyword research dataset for the ASO document.
//
// No search-volume figures anywhere: this environment has no access to
// Apple Search Ads or Play Console data, and inventing numbers would be
// worse than useless. Competition and opportunity are labelled
// ESTIMATE and derive from observable facts — how many established apps
// already rank on the head term, and how closely the term matches what
// LingoQuest actually does.
//
// "Serviceable" is the column that matters most here. LingoQuest's UI
// and every gloss are English-only (verified: no lib/l10n, no
// supportedLocales, and every course JSON teaches its language *from*
// English). A term a non-English speaker would search is therefore not
// serviceable today, however attractive it looks.
import { writeFileSync } from 'node:fs';

const rows = [];
const add = (kw, o) => rows.push(Object.assign({
  kw, intent: 'discovery', lang: 'English', rel: 'High', comp: 'High',
  opp: 'B', use: 'Description', apple: 'Med', gplay: 'Med', svc: 'Yes',
}, o));

// ---------------------------------------------------- head & category terms
const head = [
  ['language learning', 'Very High', 'C', 'Description', 'High', 'High'],
  ['learn languages', 'Very High', 'C', 'Description', 'High', 'High'],
  ['language app', 'Very High', 'C', 'Description', 'High', 'High'],
  ['language learning app', 'Very High', 'C', 'Google long description', 'High', 'High'],
  ['learn a language', 'Very High', 'C', 'Description', 'High', 'High'],
  ['language course', 'High', 'C', 'Google long description', 'Med', 'Med'],
  ['language lessons', 'High', 'C', 'Keyword field', 'High', 'Med'],
  ['foreign language', 'Medium', 'B', 'Keyword field', 'Med', 'Med'],
  ['second language', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['free language app', 'High', 'B', 'Google long description', 'Med', 'High'],
];
head.forEach(([kw, comp, opp, use, apple, gplay]) =>
  add(kw, { comp, opp, use, apple, gplay }));

// --------------------------------------------- the differentiator: games
// This is the cluster LingoQuest should own. Drops is the only major
// competitor with "Games" in its App Store title (verified on its store
// page), which leaves the long tail comparatively open.
const games = [
  ['language games', 'High', 'A', 'Subtitle', 'High', 'High'],
  ['language learning games', 'Medium', 'A', 'Title / Subtitle', 'High', 'High'],
  ['learn language games', 'Medium', 'A', 'Keyword field', 'High', 'High'],
  ['learn through games', 'Low', 'A', 'Keyword field', 'High', 'High'],
  ['learn while playing', 'Low', 'A', 'Description', 'Med', 'High'],
  ['play and learn languages', 'Low', 'A', 'Google long description', 'Med', 'High'],
  ['vocabulary games', 'Medium', 'A', 'Keyword field', 'High', 'High'],
  ['word games', 'Very High', 'C', 'Description', 'Med', 'Med'],
  ['vocab game', 'Low', 'A', 'Keyword field', 'High', 'High'],
  ['word game learn', 'Low', 'A', 'Keyword field', 'Med', 'High'],
  ['language quiz', 'Medium', 'B', 'Keyword field', 'High', 'High'],
  ['word quiz', 'High', 'B', 'Keyword field', 'Med', 'Med'],
  ['language challenge', 'Low', 'B', 'Description', 'Med', 'Med'],
  ['word challenge', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['gamified learning', 'Low', 'A', 'Google long description', 'Med', 'High'],
  ['gamification language', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['educational games', 'High', 'C', 'Google long description', 'Med', 'Med'],
  ['word puzzle language', 'Low', 'B', 'Keyword field', 'Med', 'Med'],
  ['falling words game', 'Low', 'A', 'Description', 'Med', 'Med'],
  ['memory match language', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['matching game words', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['sentence builder game', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['fun language learning', 'Medium', 'A', 'Description', 'High', 'High'],
  ['fun way to learn a language', 'Low', 'A', 'Description', 'Med', 'High'],
];
games.forEach(([kw, comp, opp, use, apple, gplay]) =>
  add(kw, { intent: 'Game / differentiator', comp, opp, use, apple, gplay }));

// ------------------------------------------------------------ skill terms
const skills = [
  ['vocabulary builder', 'High', 'B', 'Keyword field', 'High', 'Med'],
  ['vocabulary trainer', 'Medium', 'B', 'Keyword field', 'High', 'Med'],
  ['learn words', 'Medium', 'B', 'Keyword field', 'High', 'Med'],
  ['memorize vocabulary', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['flashcards', 'Very High', 'C', 'Google long description', 'Med', 'Med'],
  ['spaced repetition', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['listening practice', 'Medium', 'A', 'Keyword field', 'High', 'High'],
  ['speaking practice', 'High', 'B', 'Keyword field', 'Med', 'Med'],
  ['reading practice', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['pronunciation practice', 'High', 'C', 'Google long description', 'Low', 'Med'],
  ['conversation practice', 'High', 'C', 'Google long description', 'Low', 'Med'],
  ['language practice', 'Medium', 'A', 'Keyword field', 'High', 'High'],
  ['practice vocabulary', 'Low', 'A', 'Google long description', 'High', 'High'],
  ['review mistakes', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['learn phrases', 'Medium', 'B', 'Keyword field', 'Med', 'Med'],
  ['everyday phrases', 'Low', 'B', 'Google long description', 'Med', 'Med'],
  ['travel phrases', 'Medium', 'B', 'Keyword field', 'Med', 'Med'],
  ['phrasebook', 'Medium', 'C', 'Google long description', 'Low', 'Low'],
];
skills.forEach(([kw, comp, opp, use, apple, gplay]) =>
  add(kw, { intent: 'Skill / practice', comp, opp, use, apple, gplay }));

// ------------------------------------------------------- beginner & habit
const habit = [
  ['language for beginners', 'High', 'B', 'Google long description', 'Med', 'Med'],
  ['beginner language app', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['start learning a language', 'Low', 'B', 'Description', 'Med', 'Med'],
  ['5 minute lessons', 'Low', 'A', 'Description', 'Med', 'Med'],
  ['bite size lessons', 'Low', 'A', 'Description', 'Med', 'Med'],
  ['daily lessons', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['daily streak', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['learning streak', 'Low', 'B', 'Google long description', 'Med', 'Med'],
  ['daily goal', 'Medium', 'C', 'Google long description', 'Low', 'Low'],
  ['xp levels learning', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['achievements badges', 'Medium', 'C', 'Google long description', 'Low', 'Low'],
  ['learn fast', 'High', 'C', 'Google long description', 'Low', 'Low'],
  ['easy language learning', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['language placement test', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['10 languages', 'Low', 'A', 'Subtitle / Description', 'High', 'High'],
  ['multiple languages one app', 'Low', 'A', 'Google long description', 'Med', 'High'],
  ['switch language', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['separate progress per language', 'Low', 'A', 'Google long description', 'Med', 'Med'],
];
habit.forEach(([kw, comp, opp, use, apple, gplay]) =>
  add(kw, { intent: 'Habit / onboarding', comp, opp, use, apple, gplay }));

// -------------------------------------- per-course terms, searched in English
// These are serviceable today: the courses exist and they teach from
// English. This is the highest-intent traffic LingoQuest can actually
// convert and retain.
const courses = [
  ['Spanish', 'Very High', 'es'],
  ['French', 'Very High', 'fr'],
  ['German', 'High', 'de'],
  ['Italian', 'High', 'it'],
  ['Portuguese', 'Medium', 'pt'],
  ['Dutch', 'Low', 'nl'],
  ['Turkish', 'Low', 'tr'],
  ['Arabic', 'Medium', 'ar'],
  ['Japanese', 'High', 'ja'],
  ['Chinese', 'High', 'zh'],
];
const coursePatterns = [
  ['learn {L}', 'A', 'Keyword field', 'High', 'High'],
  ['{L} app', 'B', 'Keyword field', 'High', 'High'],
  ['{L} for beginners', 'A', 'Google long description', 'High', 'High'],
  ['{L} lessons', 'B', 'Google long description', 'Med', 'Med'],
  ['{L} vocabulary', 'A', 'Google long description', 'High', 'High'],
  ['{L} words', 'A', 'Google long description', 'Med', 'High'],
  ['{L} games', 'A', 'Google long description', 'High', 'High'],
  ['speak {L}', 'B', 'Google long description', 'Med', 'Med'],
  ['{L} practice', 'A', 'Google long description', 'High', 'High'],
  ['{L} flashcards', 'B', 'Google long description', 'Med', 'Med'],
];
for (const [L, comp] of courses) {
  for (const [pat, opp, use, apple, gplay] of coursePatterns) {
    add(pat.replace('{L}', L), {
      intent: 'Course (English query)',
      lang: 'English → ' + L,
      comp: pat.startsWith('learn ') || pat.endsWith(' app') ? comp : 'Medium',
      opp, use, apple, gplay, svc: 'Yes',
    });
  }
}

// ------------------------------------------- native-language storefront terms
// NOT serviceable today. Every one of these is searched by someone who
// would land on an English-only interface with English-only glosses.
// They belong on the roadmap behind UI localisation, not in this
// release's metadata.
const native = {
  Spanish: ['aprender idiomas', 'juegos para aprender idiomas', 'aprender inglés', 'vocabulario en inglés',
    'curso de idiomas', 'practicar idiomas', 'aprender jugando', 'aprender idiomas gratis',
    'juegos de vocabulario', 'aprender francés', 'aprender alemán', 'lecciones de idiomas'],
  German: ['sprachen lernen', 'vokabeln lernen', 'sprachlernspiel', 'englisch lernen',
    'spanisch lernen', 'vokabeltrainer', 'sprachen lernen spielerisch', 'sprachkurs app',
    'wortschatz trainieren', 'sprachen lernen kostenlos', 'lernspiele', 'täglich lernen'],
  French: ['apprendre une langue', 'apprendre les langues', 'jeux pour apprendre', 'vocabulaire anglais',
    'apprendre espagnol', 'cours de langue', 'apprendre en jouant', 'application langues',
    'jeux de vocabulaire', 'apprendre allemand', 'réviser vocabulaire', 'langue gratuite'],
  Italian: ['imparare le lingue', 'imparare inglese', 'giochi per imparare', 'vocabolario inglese',
    'corso di lingua', 'imparare giocando', 'app lingue', 'imparare spagnolo',
    'giochi di vocaboli', 'lezioni di lingua', 'studiare lingue', 'imparare gratis'],
  Portuguese: ['aprender idiomas', 'aprender inglês', 'jogos para aprender', 'vocabulário inglês',
    'curso de idiomas', 'aprender brincando', 'app de idiomas', 'aprender espanhol',
    'jogos de vocabulário', 'lições de idiomas', 'praticar idiomas', 'aprender de graça'],
  Dutch: ['talen leren', 'engels leren', 'woordenschat', 'taalspel',
    'taal app', 'spelenderwijs leren', 'spaans leren', 'duits leren',
    'woorden leren', 'taalcursus', 'dagelijks oefenen', 'gratis talen leren'],
  Turkish: ['dil öğrenme', 'ingilizce öğren', 'kelime oyunu', 'dil öğrenme oyunu',
    'kelime ezberleme', 'dil kursu', 'oyunla öğren', 'ispanyolca öğren',
    'almanca öğren', 'günlük pratik', 'ücretsiz dil', 'kelime hazinesi'],
  Arabic: ['تعلم اللغات', 'تعلم الإنجليزية', 'ألعاب تعلم اللغة', 'مفردات إنجليزية',
    'دورة لغة', 'تعلم باللعب', 'تطبيق لغات', 'تعلم الإسبانية',
    'حفظ الكلمات', 'دروس لغة', 'تدرب يوميا', 'تعلم مجانا'],
  Japanese: ['語学学習', '英語 勉強', '単語ゲーム', '語彙 アプリ',
    '言語 学習 アプリ', '遊んで学ぶ', 'スペイン語 勉強', '毎日 学習',
    '単語 暗記', '語学 ゲーム', '無料 語学', '発音 練習'],
  Chinese: ['学语言', '学英语', '单词游戏', '词汇 应用',
    '语言学习', '玩游戏学习', '学西班牙语', '每日学习',
    '背单词', '语言 课程', '免费 学语言', '口语 练习'],
};
for (const [lang, list] of Object.entries(native)) {
  for (const kw of list) {
    add(kw, {
      intent: 'Native storefront',
      lang,
      rel: 'Medium',
      comp: 'High',
      opp: 'C — blocked',
      use: 'Hold until UI localisation',
      apple: 'Med',
      gplay: 'Med',
      svc: 'No — English-only UI',
    });
  }
}

// ------------------------------------------------------- use case & context
const context = [
  ['learn language for travel', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['travel language app', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['language before a trip', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['learn on commute', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['learn in 5 minutes a day', 'Low', 'A', 'Description', 'Med', 'Med'],
  ['language app no ads', 'Low', 'B', 'Google long description', 'Med', 'High'],
  ['offline language learning', 'Medium', 'C', 'Google long description', 'Low', 'Low'],
  ['language app for adults', 'Medium', 'C', 'Google long description', 'Low', 'Low'],
  ['self study language', 'Medium', 'B', 'Google long description', 'Med', 'Med'],
  ['language learning motivation', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['stick with language learning', 'Low', 'A', 'Google long description', 'Low', 'Med'],
  ['language habit', 'Low', 'B', 'Google long description', 'Low', 'Med'],
];
context.forEach(([kw, comp, opp, use, apple, gplay]) =>
  add(kw, { intent: 'Use case', comp, opp, use, apple, gplay }));

// ------------------------------------------------- in-app feature language
// Terms drawn from features verified in the running build, so every one
// of them can be used in copy without overclaiming.
const features = [
  ['listen and select', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['match words to meanings', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['put words in order', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['word bubble game', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['word survival game', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['meaning shooter', 'Low', 'B', 'Google long description', 'Low', 'Low'],
  ['conversation challenge', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['listen and catch', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['phrase builder', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['daily challenge words', 'Low', 'B', 'Google long description', 'Low', 'Med'],
  ['practice mistakes', 'Low', 'A', 'Google long description', 'Med', 'Med'],
  ['words mastered', 'Low', 'B', 'Google long description', 'Low', 'Med'],
];
features.forEach(([kw, comp, opp, use, apple, gplay]) =>
  add(kw, { intent: 'Feature', comp, opp, use, apple, gplay }));

// ------------------------------------------------------------------ brand
['LingoQuest', 'Lingo Quest', 'lingoquest app', 'lingoquest games'].forEach((kw) =>
  add(kw, { intent: 'Brand', comp: 'Low', opp: 'A', use: 'Title',
    apple: 'High', gplay: 'High', rel: 'High' }));

writeFileSync('C:/Duolingo/marketing/build/keywords.json', JSON.stringify(rows), 'utf8');
console.log('keywords:', rows.length);
const byIntent = {};
rows.forEach((r) => { byIntent[r.intent] = (byIntent[r.intent] || 0) + 1; });
console.log(byIntent);
console.log('serviceable now:', rows.filter((r) => r.svc === 'Yes').length);

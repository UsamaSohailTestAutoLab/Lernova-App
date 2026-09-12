// Writes a genuine .docx (an OOXML package in a ZIP) for the ASO dossier.
//
// Hand-built rather than converted: there is no pandoc or python-docx in
// this environment, and a renamed HTML file with a .docx extension is
// not a Word document. This produces real WordprocessingML — headings,
// body copy, bullets and tables that Word, Pages and Google Docs all
// open and reflow natively.
import JSZip from 'jszip';
import { writeFileSync, readFileSync } from 'node:fs';

const esc = (s) => String(s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const body = [];

/** A paragraph. `style` maps to a style id defined in styles.xml. */
const p = (text, style = 'Body') => {
  body.push(`<w:p><w:pPr><w:pStyle w:val="${style}"/></w:pPr>` +
    runs(text) + '</w:p>');
};

/** Inline **bold** markers become real runs rather than literal asterisks. */
const runs = (text) => String(text).split(/(\*\*[^*]+\*\*)/).filter(Boolean)
  .map((chunk) => {
    const bold = chunk.startsWith('**') && chunk.endsWith('**');
    const t = bold ? chunk.slice(2, -2) : chunk;
    return `<w:r>${bold ? '<w:rPr><w:b/></w:rPr>' : ''}` +
      `<w:t xml:space="preserve">${esc(t)}</w:t></w:r>`;
  }).join('');

const bullet = (text) => {
  body.push('<w:p><w:pPr><w:pStyle w:val="Body"/>' +
    '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>' +
    runs(text) + '</w:p>');
};

const cell = (text, head = false, width = 1800) =>
  `<w:tc><w:tcPr><w:tcW w:w="${width}" w:type="dxa"/>` +
  (head ? '<w:shd w:val="clear" w:fill="EEF2EA"/>' : '') +
  '</w:tcPr><w:p><w:pPr><w:pStyle w:val="Cell"/></w:pPr>' +
  `<w:r>${head ? '<w:rPr><w:b/></w:rPr>' : ''}` +
  `<w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:p></w:tc>`;

const table = (headers, rows) => {
  const w = Math.floor(9360 / headers.length);
  const tr = (cells, head) => '<w:tr>' +
    (head ? '<w:trPr><w:tblHeader/></w:trPr>' : '') +
    cells.map((c) => cell(c, head, w)).join('') + '</w:tr>';
  body.push('<w:tbl><w:tblPr><w:tblStyle w:val="Grid"/>' +
    '<w:tblW w:w="9360" w:type="dxa"/>' +
    '<w:tblBorders>' +
    ['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((s) =>
      `<w:${s} w:val="single" w:sz="4" w:space="0" w:color="D8DED2"/>`).join('') +
    '</w:tblBorders></w:tblPr>' +
    tr(headers, true) + rows.map((r) => tr(r, false)).join('') + '</w:tbl>');
  p('', 'Body');
};

// ───────────────────────────────────────────────────────────── content
p('LingoQuest', 'Title');
p('Screenshots, Preview Video & ASO Strategy', 'Subtitle');
p('Prepared 12 September 2026 · from the running Flutter build on a physical Pixel 5a · ' +
  '34 screens visited · 10 screenshots and 2 videos produced.', 'Meta');
p('Facts are sourced from live App Store listings and published Apple/Google limits. ' +
  'Competition, opportunity and score columns are assessments, not measurements. ' +
  'No search-volume, download or revenue figures are estimated anywhere in this document.', 'Meta');

p('1. Executive summary', 'H1');
p('LingoQuest is a complete, working language-learning app with a genuine differentiator ' +
  'that its current positioning does not claim loudly enough. Ten courses, a structured ' +
  'Path, and **ten distinct mini-games built from the same vocabulary** are all live in the ' +
  'build I ran. The store listing should be built on the games.');
p('The five things that matter', 'H2');
bullet('**The USP is Learn → Practice → Play, and the app says so itself.** Its own onboarding ' +
  'carries a slide titled "Learn → Practice → Play". [FACT]');
bullet('**Ten games is the rarest asset here.** Of six major competitors checked, only Drops ' +
  'puts "Games" in its App Store title. [FACT]');
bullet('**The app is English-only, and that caps localisation.** No lib/l10n, no ' +
  'supportedLocales, and every course teaches its language from English. [RISK]');
bullet('**The icon is the weakest asset.** Green parrot on a green field, full-body, pointer ' +
  'vanishes below 60px. Scores 3/10 on small-size readability. [ESTIMATE]');
bullet('**Content depth is the real launch constraint.** Nine lessons per language across three ' +
  'units, while the achievements screen advertises a 30-day streak badge. [FACT]');
p('Recommended positioning — Brand: LingoQuest · USP: Learn languages by playing games · ' +
  'Proof: 10 games, 10 languages, one vocabulary.');

p('2. App screen inventory', 'H1');
p('Every screen below was opened on a physical Pixel 5a running the current build. ' +
  'Nothing in this table is inferred from source code. [FACT]');
const INV = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_inventory.json', 'utf8'));
table(['Screen', 'Path', 'Purpose', 'Screenshot potential'],
  INV.map((r) => [r[0], r[1], r[2], r[5].replace(/<\/?strong>/g, '')]));

p('Two features I did not expect to find', 'H2');
p('A quick placement test (8 questions, skippable) runs during onboarding, and every game ' +
  'opens with a Review Words carousel — flashcards with audio for the exact words that game ' +
  'is about to test. That second one is the mechanical proof of the Learn→Play claim.');

p('3. Product USP', 'H1');
p('Most competitors gamify the lesson. LingoQuest keeps the lesson and adds a games tab that ' +
  'draws from the same word list — so the game is practice, not a reward for practice.');
table(['Claim', 'Verified in build', 'Safe to say'], [
  ['10 learning languages', 'All 10 listed and selectable', 'Yes'],
  ['10 mini-games', 'All 10 present with individual levels', 'Yes'],
  ['Games use lesson vocabulary', 'Each game opens a Review Words carousel', 'Yes'],
  ['8 exercise types', 'Typed recall, MCQ, listening, image, sentence, matching, fill-blank, speaking', 'Yes'],
  ['Per-language progress', 'Languages screen shows independent position per language', 'Yes'],
  ['Mistake review', 'Missed/All filter, your vs correct answer, audio replay', 'Yes'],
  ['Streaks, XP, achievements', 'Streak chip, XP levels, 10+ badges, daily goal', 'Yes'],
  ['Placement test', '8-question quick placement during onboarding', 'Yes'],
  ['Offline use', 'NOT TESTED — bundled JSON suggests it works, unverified', 'No — verify first'],
  ['Speech recognition', 'Type exists in code; not reached in play', 'No — verify first'],
]);
p('Do not claim anything about fluency, CEFR levels, tutors, certificates or offline mode ' +
  'until verified. Two of the ten rows above are unverified and are excluded from every ' +
  'piece of copy in this document.');

p('4. Competitor analysis', 'H1');
p('Pulled from the live US App Store pages on 12 September 2026. Titles, subtitles and ' +
  'ratings are quoted exactly. [FACT]');
table(['App', 'Title', 'Subtitle', 'Rating', 'Rank'], [
  ['Duolingo', 'Duolingo: Language Lessons', 'Languages, Math, Music & Chess', '4.7 · 5.4M', '#1 Education'],
  ['Babbel', 'Babbel - Language Learning', 'Learn Spanish, French & more', '4.7 · 753K', '#60 Education'],
  ['Memrise', 'Memrise: Language Learning App', 'Learn Spanish, Japanese & More', '4.8 · 217K', '#190 Education'],
  ['Busuu', 'Busuu: Language Learning App', 'Learn Spanish, French, English', '4.7 · 101K', '#131 Education'],
  ['Drops', 'Drops: Language Learning Games', 'Learn Spanish, French, German', '4.7 · 72K', 'Education'],
  ['Mondly', 'Mondly: Learn 41 Languages', 'Learning Spanish Korean French', '4.7 · 33K', 'Education'],
]);
p('Five of six spend their subtitle listing languages. Only Drops claims games in its title — ' +
  'and Drops is vocabulary-only with no lesson path. LingoQuest can claim what none of them ' +
  'can: **a structured path and a games arcade sharing one vocabulary**.');
p('Competitor weaknesses worth targeting [ESTIMATE]', 'H2');
bullet('**Duolingo scope drift** — its subtitle now sells maths, music and chess.');
bullet('**Price** — Babbel lists up to $107.99/yr, Memrise up to $329.99 lifetime. ' +
  'LingoQuest at $30/yr is materially below the field.');
bullet('**Drops caps at vocabulary** — no sentences, no path, no grammar.');

p('5. Best user journey', 'H1');
const JOURNEY = [
  ['Choose a language', 'Ten flags, one tap. Each language keeps its own progress.'],
  ['Learn something', 'A five-minute lesson: flashcard carousel, then eight exercises across six formats.'],
  ['Play a game', 'The Fun Zone opens the same words as falling bubbles, matching pairs or a rising-water race.'],
  ['Practise what you missed', 'Wrong answers re-queue in the lesson, surface on the review screen, and again as "Practice Mistakes".'],
  ['Earn progress', 'XP, a level ring, a streak celebration, a daily-goal confirmation and an achievement.'],
  ['Come back', 'Home resumes exactly where you stopped, per language.'],
];
table(['Step', 'What happens'], JOURNEY.map((r, i) => [`${i + 1}. ${r[0]}`, r[1]]));

p('6. Screenshot strategy', 'H1');
table(['#', 'Question it answers', 'Answer'], [
  ['1', 'What is LingoQuest?', 'A language app with lessons, games, XP and a streak — all four visible at once'],
  ['2', 'What makes it different?', 'Spanish words falling as bubbles you catch — a real game'],
  ['3', 'How do I actually learn?', 'A five-minute lesson: see the word, hear it, pick the meaning'],
]);
bullet('**Size** 1320 × 2868 px, the 6.9-inch iPhone class — App Store Connect scales it down for the family.');
bullet('**Type** Baloo 2 and Inter, the app\u2019s own faces, so the store page and product match.');
bullet('**Device frame** a plain CSS-drawn rounded rectangle; no manufacturer handset artwork.');
bullet('**Palette rhythm** light green → deep green → light green → amber across the carousel.');

p('7-8. Screenshots 1-10 and exact copy', 'H1');
const COPY = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_copy.json', 'utf8'));
table(['#', 'Headline', 'Supporting text', 'Keyword theme', 'Why here'],
  COPY.map((r) => [String(r[0]), r[1], r[2], r[3], r[4]]));

p('9. Screenshot scoring', 'H1');
p('Seven criteria out of 10. Assessments from the finished assets, not measured ' +
  'conversion data. [ESTIMATE]');
const SHOTS = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_shots.json', 'utf8'));
table(['Rank', 'Screenshot', 'Visual', 'Clarity', 'USP', 'Feature', 'Conv', 'ASO', 'Diff', 'Total'],
  SHOTS.map((s) => ({ ...s, total: s.sc.reduce((a, b) => a + b, 0) }))
    .sort((a, b) => b.total - a.total)
    .map((r, i) => [String(i + 1), `#${r.n} ${r.hl}`, ...r.sc.map(String), String(r.total)]));
p('The two highest scorers are #4 (languages) and #5 (games grid) — both breadth claims no ' +
  'competitor screenshot matches. The weakest is #2, highest on differentiation and lowest on ' +
  'clarity, because a falling-bubble game needs empty vertical space to read as falling. ' +
  'That tension is the best A/B test in this package.');

p('10. App icon review', 'H1');
table(['Criterion', 'Score', 'Reasoning'], [
  ['Brand recognition', '5/10', 'Recognisable once known, but a cartoon bird is not distinctive here'],
  ['Language association', '2/10', 'Nothing signals language to a cold viewer'],
  ['Game association', '2/10', 'The pointer reads as teaching, not play'],
  ['Small-size readability', '3/10', 'Fails below ~60px: green-on-green kills the silhouette'],
  ['Uniqueness', '4/10', 'Green cartoon bird mascots are crowded; proximity to the leader\u2019s owl is a liability'],
  ['App Store attractiveness', '5/10', 'Clean and professional, but does not stop a scroll'],
  ['TOTAL', '21/60', ''],
]);
p('Recommended redesign [RECOMMENDATION]', 'H2');
bullet('**Crop to head and shoulders** — fill 80-85% of the canvas with the face.');
bullet('**Change the ground to amber** — the brand already owns #FFB020, and it separates ' +
  'the tile from every green competitor.');
bullet('**Drop the pointer stick** — first thing lost at small size, and it sells "teacher".');
bullet('**Add one subtle game cue** — a faint bubble highlight in the glasses lenses.');
p('Constraint: no owl, no green-bird-on-green, no speech-bubble-with-a-globe.');

p('11-12. Preview video storyboard and copy', 'H1');
p('26.7 seconds, 886 × 1920, H.264 High 4.0, 30 fps, AAC stereo 48 kHz — inside Apple\u2019s ' +
  '15-30 second window. Eight beats, all real footage, no voice-over.');
const STORY = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_story.json', 'utf8'));
table(['Time', 'Headline', 'Sub-line', 'Footage'],
  STORY.map((r) => [r[0] + 's', r[1], r[2], r[3]]));
p('Hook rationale: "Stop studying. Start playing." is punchier but alienates the ' +
  'serious-learner segment. "Learn. Play. Progress." says nothing concrete. ' +
  '"Learn a language by playing" wins — the whole product in five words, and literally ' +
  'true of the frame behind it.');

p('13. App Store metadata', 'H1');
p('Apple indexes title, subtitle and keyword field — 160 characters total. Promotional text ' +
  'and description are for conversion, not search. [FACT]');
const META = [
  ['Title (30)', 'LingoQuest: Language Games', '26'],
  ['Subtitle (30)', 'Learn Spanish, French & 8 More', '29'],
  ['Keywords (100)', 'vocabulary,word,game,practice,quiz,speak,listen,italian,german,japanese,arabic,dutch,turkish', '91'],
  ['Promotional text (170)', 'New: Word Survival and Meaning Shooter join the Fun Zone. Ten games, ten languages, one vocabulary — learn a word in a lesson, then play it until it sticks.', '158'],
];
table(['Field', 'Value', 'Chars'], META);
p('Brand first because brand terms convert best, then the two words that define the category ' +
  'position. "Language Games" is the phrase this app can own; "Language Lessons" is the ' +
  'phrase it would lose. No spaces after commas in the keyword field — Apple counts them — ' +
  'and nothing repeats the title or subtitle, which Apple already indexes.');

p('14. App Store description', 'H1');
readFileSync('C:/Duolingo/marketing/build/docx_appdesc.txt', 'utf8')
  .split('\n').forEach((line) => p(line || ' '));

p('15. Google Play metadata', 'H1');
table(['Field', 'Value'], [
  ['Title (30)', 'LingoQuest: Language Games'],
  ['Short description (80)', 'Learn Spanish, French, Japanese and 7 more — through 10 real word games.'],
]);
p('Long description', 'H2');
readFileSync('C:/Duolingo/marketing/build/docx_playdesc.txt', 'utf8')
  .split('\n').forEach((line) => p(line || ' '));

p('16. Keyword research — 318 terms', 'H1');
p('No search-volume figures appear anywhere. This environment has no Apple Search Ads or Play ' +
  'Console access, and invented numbers are worse than none. Competition and opportunity are ' +
  'estimates derived from how crowded the head term is and how closely it matches the app. ' +
  '[ESTIMATE]');
p('**Read the Serviceable column first.** 120 of the 318 terms are native-language storefront ' +
  'queries. They are researched and listed, but not usable in this release — the app\u2019s UI ' +
  'and every gloss are English. Shipping metadata against them buys installs that churn on ' +
  'first open.');
const KW = JSON.parse(readFileSync('C:/Duolingo/marketing/build/keywords.json', 'utf8'));
table(['Keyword', 'Intent', 'Language', 'Rel', 'Competition', 'Opp', 'Recommended use', 'Serviceable'],
  KW.map((r) => [r.kw, r.intent, r.lang, r.rel, r.comp, r.opp, r.use, r.svc]));

p('17. Nine-language ASO', 'H1');
const LANGS = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_langs.json', 'utf8'));
table(['Course', 'English terms (live)', 'Native terms (blocked)', 'Positioning line', 'Priority'],
  LANGS.map((r) => [r[0], r[1], r[2], r[3], r[4]]));
p('Where to spend first: **Spanish, French and Japanese.** Spanish has the largest ' +
  'learn-a-language demand in the English-speaking world and the most complete course. ' +
  'French is second-largest and the only other course with content beyond the base pass. ' +
  'Japanese is smaller in volume but skews young, game-literate and app-native — precisely ' +
  'the segment a games-first pitch converts best, and where "learn through games" faces the ' +
  'least entrenched competition. Arabic and Chinese are deliberately not in the first three: ' +
  'both need script and RTL handling I did not verify.');

p('18. Localisation strategy', 'H1');
p('Apple and Google both let you localise a listing without localising the app. Doing that ' +
  'here would put a Spanish store page in front of a Spanish speaker who then opens an ' +
  'English-only interface teaching Spanish from English. That is a refund, a one-star review, ' +
  'and a permanent dent in conversion.');
table(['Tier', 'Locales', 'Action now', 'Unblocks when'], [
  ['A — ship now', 'en-US, en-GB, en-AU, en-CA', 'Full metadata, all 10 screenshots, preview video', 'Live at launch'],
  ['B — metadata only', 'nl-NL, de-DE, sv, da, nb', 'Localised subtitle and keywords only; English description and screenshots; state "English-language app" in line 1', 'Optional at launch'],
  ['C — hold', 'es, fr, it, pt-BR, tr, ar, ja, zh-Hans', 'Nothing. Research banked in §16', 'Interface localisation + native glosses ship'],
]);
p('Tier C drafts — hold until localisation ships', 'H2');
const LOC = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_loc.json', 'utf8'));
table(['Locale', 'Title', 'Subtitle', 'Primary terms', 'Short description'], LOC);
p('None of these is a literal translation. "Aprender jugando" and "spielerisch lernen" are ' +
  'the phrases those markets actually use for play-based learning.');

p('19. Country strategy', 'H1');
table(['Tier', 'Markets', 'Why', 'Launch action'], [
  ['Tier 1', 'United States, United Kingdom, Canada, Australia',
    'Native English, highest iOS subscription spend, and the entire learn-Spanish/French/Japanese demand base',
    'Full listing, preview video, Search Ads on brand + games terms'],
  ['Tier 2', 'Netherlands, Sweden, Denmark, Norway, Ireland, Singapore, New Zealand',
    'Very high English proficiency and strong iOS share; an English UI is not a blocker',
    'English listing, Tier-B localised subtitle, organic only'],
  ['Tier 3', 'Germany, France, Spain, Italy, Brazil, Japan, Turkey, UAE',
    'Large demand but the English-only UI is a real conversion and retention penalty',
    'Hold paid spend until interface localisation ships'],
]);
p('One deliberate exception: **India and the Philippines** sit outside this ranking. English ' +
  'proficiency is high and volume is large, but subscription conversion is materially lower. ' +
  'Worth including for install volume and review velocity, worth excluding from any revenue ' +
  'forecast built on Tier 1 rates.');

p('20. A/B test plan — 20 experiments', 'H1');
const AB = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_ab.json', 'utf8'));
table(['#', 'Hypothesis', 'Variant A (control)', 'Variant B', 'Metric', 'Success'],
  AB.map((r) => [String(r[0]), r[1], r[2], r[3], r[4], r[5]]));
p('Tests 1-4 change what a person sees before they read anything, so they move the number most ' +
  'and should run first. Do not run the icon test and the screenshot-1 test concurrently — ' +
  'both change the search-result tile.');

p('21. 90-day roadmap', 'H1');
const ROAD = JSON.parse(readFileSync('C:/Duolingo/marketing/build/docx_road.json', 'utf8'));
table(['Window', 'Focus', 'Work'], ROAD);

p('22. Final recommended package', 'H1');
p('If I were launching LingoQuest with my own money, this is exactly what I would publish.');
table(['Slot', 'Ship this'], [
  ['App Store title', 'LingoQuest: Language Games'],
  ['Subtitle', 'Learn Spanish, French & 8 More'],
  ['Keywords', 'vocabulary,word,game,practice,quiz,speak,listen,italian,german,japanese,arabic,dutch,turkish'],
  ['Screenshots', 'All ten in the order in §7 — the games frame at #2 is the whole bet'],
  ['Preview video', 'LingoQuest_AppStore_Preview.mp4 — 26.7s, real gameplay, silent'],
  ['Icon', 'REDESIGN BEFORE LAUNCH. Head-and-shoulders on amber. The one asset I would not ship as-is'],
  ['Markets', 'Tier 1 at launch, Tier 2 organic, Tier 3 held'],
  ['Localisation', 'English only, until the interface is localised'],
  ['Price', '$12/mo with 3-day trial, $30/yr — under every competitor in §4'],
]);
p('The one thing I would fix before any of it', 'H2');
p('Nine lessons per language is three units. A learner who takes the app at its word and ' +
  'builds a streak will exhaust Spanish inside a fortnight, and the achievements screen is ' +
  'advertising a 30-day streak badge they cannot earn on content alone. Every pound spent on ' +
  'ASO before that gap closes is buying installs into a leaky bucket.');
p('**Ship the store package as specified, hold the paid acquisition until there is enough ' +
  'content to survive the streak the app is selling.**');

// ───────────────────────────────────────────────────────────── package
const STYLES = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr>
<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="21"/>
</w:rPr></w:rPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:pPr>
<w:spacing w:before="0" w:after="60"/></w:pPr><w:rPr><w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
<w:b/><w:sz w:val="56"/><w:color w:val="16200F"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:pPr>
<w:spacing w:after="200"/></w:pPr><w:rPr><w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/>
<w:sz w:val="32"/><w:color w:val="2E7D22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Meta"><w:name w:val="Meta"/><w:pPr>
<w:spacing w:after="120"/></w:pPr><w:rPr><w:sz w:val="18"/><w:color w:val="5E6B57"/><w:i/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="H1"><w:name w:val="heading 1"/>
<w:basedOn w:val="Body"/><w:pPr><w:keepNext/><w:pageBreakBefore/>
<w:spacing w:before="360" w:after="140"/><w:outlineLvl w:val="0"/></w:pPr>
<w:rPr><w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/><w:b/><w:sz w:val="34"/>
<w:color w:val="16200F"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="H2"><w:name w:val="heading 2"/>
<w:basedOn w:val="Body"/><w:pPr><w:keepNext/><w:spacing w:before="260" w:after="100"/>
<w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="2E7D22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:default="1" w:styleId="Body"><w:name w:val="Normal"/>
<w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>
<w:rPr><w:sz w:val="21"/><w:color w:val="16200F"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Cell"><w:name w:val="Cell"/><w:basedOn w:val="Body"/>
<w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
<w:rPr><w:sz w:val="17"/></w:rPr></w:style>
</w:styles>`;

const NUMBERING = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0">
<w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/>
<w:lvlJc w:val="left"/><w:pPr><w:ind w:left="420" w:hanging="240"/></w:pPr>
</w:lvl></w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>`;

const DOCUMENT = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>${body.join('')}
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>
<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"
w:header="709" w:footer="709" w:gutter="0"/></w:sectPr>
</w:body></w:document>`;

const zip = new JSZip();
zip.file('[Content_Types].xml', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>`);
zip.folder('_rels').file('.rels', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>`);
const word = zip.folder('word');
word.file('document.xml', DOCUMENT);
word.file('styles.xml', STYLES);
word.file('numbering.xml', NUMBERING);
word.folder('_rels').file('document.xml.rels', `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>`);

const buf = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
writeFileSync('C:/Duolingo/marketing/docs/LingoQuest_ASO_Strategy.docx', buf);
console.log('docx written:', buf.length, 'bytes ·', body.length, 'block elements');

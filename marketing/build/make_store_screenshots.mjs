// Builds the store screenshot sets — one template, every target.
//
// WHY ONE SCRIPT
//
// There were three near-identical copies of this (iPhone, iPad, Play),
// which is how the iPhone set drifted into drawing a fake device body
// while the others did not. One template, one shot list, one set of
// captions; the targets differ only in canvas size and where the
// captures come from.
//
// WHY NO DEVICE FRAME
//
// The first iPhone submission was rejected — "phone style not correct
// you are using other phone style screenshot" — for a hand-drawn phone
// body wrapped around captures taken on a Pixel 5a. Nothing here draws
// a device, a status bar or a home indicator any more. A real capture
// arrives with a real one, and every invented pixel is something a
// reviewer can call inaccurate.
//
// WHY ONE CAPTURE SET SERVES BOTH STORES
//
// The rule is asymmetric. Google Play does not care which platform a
// screenshot was rendered on; Apple does, and rejects. So capture once
// on iOS and use those pixels everywhere — iOS chrome on a Play listing
// is unremarkable, Android chrome on an App Store listing is a
// rejection. The reverse is not interchangeable, which is the whole
// reason the first set failed.
//
// USAGE
//
//   node make_store_screenshots.mjs iphone
//   node make_store_screenshots.mjs ipad
//   node make_store_screenshots.mjs play
//   node make_store_screenshots.mjs all
import { writeFileSync, mkdirSync, existsSync, readFileSync, statSync }
  from 'node:fs';
import { execFileSync } from 'node:child_process';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const ROOT = 'C:/Duolingo/marketing';
const BUILD = `${ROOT}/build`;

// --- targets ---------------------------------------------------------

const TARGETS = {
  iphone: {
    w: 1320, h: 2868,
    src: `${ROOT}/raw_ios_device`,
    out: `${ROOT}/LingoQuest_AppStore_Screenshots_iPhone`,
    // Apple checks this to the pixel and rejects anything else.
    strictSize: { w: 1320, h: 2868 },
    note: 'iPhone 6.9" — iPhone 16/17 Pro Max',
  },
  ipad: {
    w: 2064, h: 2752,
    src: `${ROOT}/raw_ipad_device`,
    out: `${ROOT}/LingoQuest_AppStore_Screenshots_iPad`,
    strictSize: null,
    // The iPad canvas is 3:4, so the same proportion of width is a much
    // taller object; it needs less to reach the bottom.
    shotWidth: 0.70,
    note: 'iPad 13" — mandatory while TARGETED_DEVICE_FAMILY is "1,2"',
  },
  play: {
    w: 1320, h: 2868,
    // The same iOS captures. Play accepts them and it keeps the two
    // listings visually identical; Android captures are the fallback
    // only for as long as the iOS ones do not exist yet.
    src: `${ROOT}/raw_ios_device`,
    fallbackSrc: `${ROOT}/raw_ios`,
    out: `${ROOT}/LingoQuest_PlayStore_Screenshots_Android`,
    strictSize: null,
    note: 'Google Play — 9:16, no exact-size rule',
  },
};

// --- grounds ---------------------------------------------------------
//
// The app's own green at full strength is what makes a screenshot —
// almost all of it near-white — read as a bright object on the page.

const DEEP = {
  bg: 'linear-gradient(168deg,#31A522 0%,#2A8B1E 55%,#1F6B16 100%)',
  head: '#FFFFFF', sub: 'rgba(255,255,255,.84)',
  bubble: 'rgba(255,255,255,.085)', bubbleRim: 'rgba(255,255,255,.22)',
  hi: 'rgba(255,255,255,.22)',
  glow: 'rgba(255,255,255,.17)',
  shadow: 'rgba(3,18,1,.46)', rim: 'rgba(255,255,255,.30)',
};
// Deliberately not a near-white ground. Almost every LingoQuest screen
// is itself near-white, so a pale background leaves the capture with
// nothing to sit against and the whole slide reads as washed out. This
// is pitched dark enough to frame white, light enough for dark type.
const LIGHT = {
  bg: 'linear-gradient(168deg,#D3EEC8 0%,#AEDD9B 55%,#8ACE73 100%)',
  head: '#0E3208', sub: 'rgba(14,50,8,.74)',
  bubble: 'rgba(23,82,16,.085)', bubbleRim: 'rgba(23,82,16,.18)',
  hi: 'rgba(255,255,255,.52)',
  glow: 'rgba(255,255,255,.46)',
  shadow: 'rgba(12,40,7,.34)', rim: 'rgba(255,255,255,.85)',
};
const AMBER = {
  bg: 'linear-gradient(168deg,#FFCB55 0%,#FFB020 55%,#EE9003 100%)',
  head: '#3A2603', sub: 'rgba(58,38,3,.76)',
  bubble: 'rgba(255,255,255,.20)', bubbleRim: 'rgba(255,255,255,.40)',
  hi: 'rgba(255,255,255,.46)',
  glow: 'rgba(255,255,255,.44)',
  shadow: 'rgba(84,52,2,.32)', rim: 'rgba(255,255,255,.78)',
};

// --- the shots -------------------------------------------------------
//
// One screen each. The old set stacked two tilted phones on some
// slides; a single upright screen is legible at the gallery thumbnail
// size people actually browse at.

const SHOTS = [
  { n: '01', theme: DEEP, shot: 'home.png',
    head: 'Learn a language<br>by <em>playing</em>',
    sub: 'Short lessons. Ten real games. One streak worth keeping.' },
  { n: '02', theme: DEEP, shot: 'wb_fall.png',
    head: 'Turn words<br>into <em>games</em>',
    sub: 'Catch the right translation before it reaches the bottom.' },
  { n: '03', theme: LIGHT, shot: 'funhub.png',
    head: '10 games,<br>one <em>vocabulary</em>',
    sub: 'Every game draws on the words you are actually learning.' },
  { n: '04', theme: AMBER, shot: 'languages.png',
    head: '10 languages,<br>separate progress',
    sub: 'Switch whenever you like. Each keeps its own streak.' },
  { n: '05', theme: DEEP, shot: 'memory_pairs.png',
    head: 'Flip. Match.<br><em>Remember.</em>',
    sub: 'Memory Match pairs every word with its meaning, against the clock.' },
  { n: '06', theme: LIGHT, shot: 'wb_burst3.png',
    head: 'Right answer?<br>Watch it <em>pop</em>',
    sub: 'Instant feedback on every tap, so nothing stays wrong for long.' },
  { n: '07', theme: DEEP, shot: 'sv3.png',
    head: 'Answer fast.<br>Stay afloat.',
    sub: 'Word Survival raises the water every time you hesitate.' },
  { n: '08', theme: LIGHT, shot: 'lesson_mcq.png',
    head: 'Short lessons<br>that <em>stick</em>',
    sub: 'A few minutes a day, built around spaced repetition.' },
  { n: '09', theme: AMBER, shot: 'lesson_correction.png',
    head: 'Every mistake<br>becomes practice',
    sub: 'Missed words come back until you have them for good.' },
  { n: '10', theme: DEEP, shot: 'statistics.png',
    head: 'Keep the<br><em>streak</em> alive',
    sub: 'XP, achievements and a daily goal that fits your week.' },
];

// --- helpers ---------------------------------------------------------

const sleepSync = (ms) =>
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

const pngSize = (p) => {
  const b = readFileSync(p);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
};

/// Edge returns before the PNG has landed, so an immediate existsSync
/// reports every shot as failed while the files appear a moment later.
/// Size has to settle too: a half-written PNG is already on disk, and
/// reading its header mid-flush gives a bogus dimension check.
const waitForFile = (p, ms = 20000) => {
  const until = Date.now() + ms;
  let last = -1;
  while (Date.now() < until) {
    if (existsSync(p)) {
      const size = statSync(p).size;
      if (size > 0 && size === last) return true;
      last = size;
    }
    sleepSync(150);
  }
  return false;
};

// Bubbles rather than plain discs — the app's own motif, and a rim
// light stops them reading as flat holes punched in the gradient.
const bubbles = (t, w, h) => [
  [-0.14, 0.04, 0.44], [0.74, 0.09, 0.33], [-0.09, 0.64, 0.52],
  [0.77, 0.79, 0.40], [0.31, -0.08, 0.29], [0.04, 0.33, 0.17],
].map(([x, y, d]) => {
  const s = Math.round(d * w);
  return `<i style="left:${Math.round(x * w)}px;top:${Math.round(y * h)}px;
    width:${s}px;height:${s}px;background:
      radial-gradient(circle at 32% 28%, ${t.bubbleRim} 0%, ${t.bubble} 42%, transparent 72%);
    border:2px solid ${t.bubble}"></i>`;
}).join('');

// --- template --------------------------------------------------------

const page = (s, cfg) => {
  const { w, h } = cfg;
  const k = w / 1320;                       // scale the type with the canvas
  const px = (n) => Math.round(n * k) + 'px';
  // Wide enough that the capture runs off the bottom edge. A screen
  // that stops just short of it reads as neither anchored nor floating,
  // which is the one result worth avoiding; letting it bleed says the
  // app carries on past the frame.
  const shotW = Math.round(w * (cfg.shotWidth ?? 0.82));

  return `<!doctype html>
<html><head><meta charset="utf-8">
<style>
  @font-face{font-family:'Baloo 2';src:url('file:///C:/Duolingo/assets/fonts/Baloo2.ttf') format('truetype');font-weight:700;}
  @font-face{font-family:'Inter';src:url('file:///C:/Duolingo/assets/fonts/Inter.ttf') format('truetype');font-weight:400;}
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:${w}px;height:${h}px;overflow:hidden;}
  body{background:${s.theme.bg};position:relative;
       display:flex;flex-direction:column;align-items:center;}

  .bubbles{position:absolute;inset:0;overflow:hidden;}
  .bubbles i{position:absolute;border-radius:50%;display:block;}

  /* A soft spotlight behind the screen, so the capture sits in the
     ground rather than on top of it. */
  .glow{position:absolute;left:50%;transform:translateX(-50%);
     top:${px(700)};width:${Math.round(w * 1.25)}px;height:${Math.round(w * 1.25)}px;
     background:radial-gradient(circle, ${s.theme.glow} 0%, transparent 62%);
     z-index:1;}

  h1{font-family:'Baloo 2',system-ui,sans-serif;font-weight:700;
     font-size:${px(124)};line-height:.97;letter-spacing:${px(-3)};
     color:${s.theme.head};text-align:center;margin-top:${px(136)};
     position:relative;z-index:3;padding:0 ${px(52)};
     text-wrap:balance;}
  h1 em{font-style:normal;position:relative;white-space:nowrap;z-index:1;}
  h1 em::after{content:'';position:absolute;left:${px(-14)};right:${px(-14)};
     bottom:${px(4)};height:${px(34)};border-radius:${px(17)};
     background:${s.theme.hi};z-index:-1;}

  p.sub{font-family:'Inter',system-ui,sans-serif;font-size:${px(45)};
     line-height:1.32;color:${s.theme.sub};text-align:center;
     margin-top:${px(30)};max-width:${px(1030)};
     position:relative;z-index:3;padding:0 ${px(40)};text-wrap:pretty;}

  /* The capture: upright, unframed, bleeding off the bottom edge so it
     reads as a screen continuing past the card rather than a floating
     rectangle. The rim is a hairline of light on the cut edge, which is
     what separates it from the ground without drawing a device. */
  .shot{position:relative;z-index:2;margin-top:${px(76)};
     width:${shotW}px;border-radius:${px(60)};
     box-shadow:0 ${px(40)} ${px(90)} ${s.theme.shadow},
                0 ${px(10)} ${px(26)} ${s.theme.shadow};}
  .shot::after{content:'';position:absolute;inset:0;border-radius:${px(60)};
     border:${px(3)} solid ${s.theme.rim};pointer-events:none;}
  .shot img{display:block;width:100%;height:auto;border-radius:${px(60)};}
</style></head>
<body>
  <div class="bubbles">${bubbles(s.theme, w, h)}</div>
  <div class="glow"></div>
  <h1>${s.head}</h1>
  <p class="sub">${s.sub}</p>
  <div class="shot"><img src="file:///${cfg.resolvedSrc}/${s.shot}" alt=""></div>
</body></html>`;
};

// --- build -----------------------------------------------------------

const build = (name) => {
  const cfg = TARGETS[name];
  mkdirSync(cfg.out, { recursive: true });

  // Pick the source, and say which one, so a fallback is never silent.
  cfg.resolvedSrc = cfg.src;
  const have = (dir) => SHOTS.every((s) => existsSync(`${dir}/${s.shot}`));
  if (!have(cfg.src) && cfg.fallbackSrc && have(cfg.fallbackSrc)) {
    cfg.resolvedSrc = cfg.fallbackSrc;
    console.log(`  note: no iOS captures, falling back to ${cfg.fallbackSrc}`);
  }

  const missing = SHOTS.filter((s) => !existsSync(`${cfg.resolvedSrc}/${s.shot}`));
  if (missing.length) {
    console.error(
      `\n[${name}] no captures in ${cfg.resolvedSrc}\n` +
      missing.map((s) => '  missing: ' + s.shot).join('\n') +
      '\n\nRun marketing/build/capture_ios.sh on macOS, or the\n' +
      'ios-screenshots GitHub Actions workflow.\n' +
      '\nDo not point this at marketing/raw_ios/ for the App Store —\n' +
      'those are Pixel 5a captures, and submitting them is what got\n' +
      'the listing rejected.\n',
    );
    return 1;
  }

  if (cfg.strictSize) {
    const bad = SHOTS
      .map((s) => ({ shot: s.shot, ...pngSize(`${cfg.resolvedSrc}/${s.shot}`) }))
      .filter((s) => s.w !== cfg.strictSize.w || s.h !== cfg.strictSize.h);
    if (bad.length) {
      console.error(
        `\n[${name}] captures must be exactly ` +
        `${cfg.strictSize.w}x${cfg.strictSize.h}:\n` +
        bad.map((s) => `  ${s.shot}: ${s.w}x${s.h}`).join('\n') +
        '\n\nResizing one to fit would put back the very problem this\n' +
        'pipeline exists to remove. Recapture on the right simulator.\n',
      );
      return 1;
    }
  }

  console.log(`\n[${name}] ${cfg.note}`);
  let failed = 0;
  for (const s of SHOTS) {
    const file = name === 'ipad'
      ? `${s.n}_AppStore_LingoQuest_iPad.png`
      : `${s.n}_AppStore_LingoQuest.png`;
    const htmlPath = `${BUILD}/${name}_${s.n}.html`;
    writeFileSync(htmlPath, page(s, cfg), 'utf8');

    const outPath = `${cfg.out}/${file}`.split('/').join('\\');
    execFileSync(EDGE, [
      '--headless=new', '--disable-gpu', '--force-device-scale-factor=1',
      '--hide-scrollbars', '--virtual-time-budget=5000',
      `--screenshot=${outPath}`,
      `--window-size=${cfg.w},${cfg.h}`, 'file:///' + htmlPath,
    ], { stdio: 'pipe' });

    if (!waitForFile(`${cfg.out}/${file}`)) {
      console.log('  FAIL ' + file);
      failed++;
      continue;
    }
    const { w, h } = pngSize(`${cfg.out}/${file}`);
    const ok = w === cfg.w && h === cfg.h;
    if (!ok) failed++;
    console.log(`  ${ok ? 'ok  ' : 'SIZE'} ${file}  ${w}x${h}`);
  }
  return failed;
};

const arg = (process.argv[2] || 'all').toLowerCase();
const names = arg === 'all' ? Object.keys(TARGETS) : [arg];
if (names.some((n) => !TARGETS[n])) {
  console.error(`Unknown target. One of: ${Object.keys(TARGETS).join(', ')}, all`);
  process.exit(2);
}
process.exit(names.reduce((acc, n) => acc + build(n), 0) ? 1 : 0);

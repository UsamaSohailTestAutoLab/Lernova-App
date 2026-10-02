// Builds the iPhone App Store screenshot set.
//
// WHY THIS WAS REWRITTEN
//
// The first submission was rejected: "phone style not correct, you are
// using other phone style screenshot."
//
// The reviewer was right. The old pipeline captured the app on a Pixel
// 5a with the display overridden to 1320x2868 @3x, painted out Android's
// status bar and gesture pill, then drew an iOS status bar, a Dynamic
// Island and a home indicator over the cleared bands, inside a
// hand-drawn phone body.
//
// Overriding the display size gets the *geometry* right. It cannot
// change the *renderer*. Those captures were still drawn by Android:
//
//   * Emoji came from Noto Color Emoji. LingoQuest's UI is full of them
//     — the medal, star, flame, trophy and controller on Home alone —
//     and Google's designs look nothing like Apple's. To a reviewer who
//     sees Apple Color Emoji every day this is unmistakable, and it is
//     almost certainly what gave the set away.
//   * Text was rasterised by Android, and the flag emoji, Material ink
//     and scroll affordances are all Android's.
//
// So the frame is gone and, more importantly, the source is gone. This
// template now composites *genuine iOS captures* and refuses to run
// without them (see SRC below). It draws no device body, no status bar
// and no home indicator, because a real capture already has a real one.
// Nothing here invents a pixel of chrome.
import { writeFileSync, mkdirSync, existsSync, readFileSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const OUT = 'C:/Duolingo/marketing/LingoQuest_AppStore_Screenshots_iPhone';
const BUILD = 'C:/Duolingo/marketing/build';

// Genuine iOS Simulator captures, produced by capture_ios.sh. Kept
// separate from raw_ios/ (the old Android-rendered set) so the two can
// never be confused again.
const SRC_DIR = 'C:/Duolingo/marketing/raw_ios_device';

mkdirSync(OUT, { recursive: true });

// The 6.9" slot. iPhone 16 Pro Max and 17 Pro Max are both 1320x2868.
const W = 1320;
const H = 2868;

const DEEP = {
  bg: 'linear-gradient(168deg,#31A522 0%,#2A8B1E 55%,#1F6B16 100%)',
  head: '#FFFFFF', sub: 'rgba(255,255,255,.84)',
  mark: 'rgba(255,255,255,.10)', hi: 'rgba(255,255,255,.22)',
  shadow: 'rgba(4,20,2,.42)',
};
const LIGHT = {
  bg: 'linear-gradient(168deg,#F4FBF1 0%,#DFF3D7 58%,#C3E7B6 100%)',
  head: '#0F3409', sub: 'rgba(15,52,9,.70)',
  mark: 'rgba(31,107,22,.09)', hi: 'rgba(63,191,43,.32)',
  shadow: 'rgba(16,46,10,.26)',
};
const AMBER = {
  bg: 'linear-gradient(168deg,#FFC94F 0%,#FFB020 55%,#F09405 100%)',
  head: '#3A2603', sub: 'rgba(58,38,3,.74)',
  mark: 'rgba(255,255,255,.24)', hi: 'rgba(255,255,255,.46)',
  shadow: 'rgba(90,56,2,.30)',
};

// One capture per shot. The old set stacked two tilted phones on some
// slides; a single upright screen reads better at gallery thumbnail
// size, and every extra composited device is another thing a reviewer
// can call inaccurate.
const SHOTS = [
  {
    file: '01_AppStore_LingoQuest.png', theme: DEEP, shot: 'home.png',
    head: 'Learn a language<br>by <em>playing</em>',
    sub: 'Short lessons. Ten real games. One streak worth keeping.',
  },
  {
    file: '02_AppStore_LingoQuest.png', theme: DEEP, shot: 'wb_fall.png',
    head: 'Turn words<br>into <em>games</em>',
    sub: 'Catch the right translation before it reaches the bottom.',
  },
  {
    file: '03_AppStore_LingoQuest.png', theme: LIGHT, shot: 'funhub.png',
    head: '10 games,<br>one <em>vocabulary</em>',
    sub: 'Every game draws on the words you are actually learning.',
  },
  {
    file: '04_AppStore_LingoQuest.png', theme: AMBER, shot: 'languages.png',
    head: '10 languages,<br>separate progress',
    sub: 'Switch whenever you like. Each one keeps its own streak.',
  },
  {
    file: '05_AppStore_LingoQuest.png', theme: DEEP, shot: 'memory_pairs.png',
    head: 'Flip. Match.<br><em>Remember.</em>',
    sub: 'Memory Match pairs every word with its meaning, against the clock.',
  },
  {
    file: '06_AppStore_LingoQuest.png', theme: LIGHT, shot: 'wb_burst3.png',
    head: 'Right answer?<br>Watch it <em>pop</em>',
    sub: 'Instant feedback on every tap, so nothing stays wrong for long.',
  },
  {
    file: '07_AppStore_LingoQuest.png', theme: DEEP, shot: 'sv3.png',
    head: 'Answer fast.<br>Stay afloat.',
    sub: 'Word Survival raises the water every time you hesitate.',
  },
  {
    file: '08_AppStore_LingoQuest.png', theme: LIGHT, shot: 'lesson_mcq.png',
    head: 'Short lessons<br>that <em>stick</em>',
    sub: 'A few minutes a day, built around spaced repetition.',
  },
  {
    file: '09_AppStore_LingoQuest.png', theme: AMBER, shot: 'lesson_correction.png',
    head: 'Every mistake<br>becomes practice',
    sub: 'Missed words come back until you have them for good.',
  },
  {
    file: '10_AppStore_LingoQuest.png', theme: DEEP, shot: 'statistics.png',
    head: 'Keep the<br><em>streak</em> alive',
    sub: 'XP, achievements and a daily goal that fits your week.',
  },
];

// --- guard rails -----------------------------------------------------
//
// Two ways to ship a rejection, both silent, both closed here.

const pngSize = (p) => {
  const b = readFileSync(p);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
};

const missing = SHOTS.filter((s) => !existsSync(`${SRC_DIR}/${s.shot}`));
if (missing.length) {
  console.error(
    `\nNo iOS captures in ${SRC_DIR}\n\n` +
    missing.map((s) => '  missing: ' + s.shot).join('\n') +
    '\n\nRun marketing/build/capture_ios.sh on macOS (or the\n' +
    'ios-screenshots GitHub Actions workflow) to produce them.\n\n' +
    'Do not point this at marketing/raw_ios/ — those are Pixel 5a\n' +
    'captures, and submitting them is what got the listing rejected.\n',
  );
  process.exit(1);
}

// A capture that is not exactly 1320x2868 is not from the 6.9"
// simulator, whatever it is. Resizing one to fit would reintroduce
// precisely the problem this rewrite exists to remove.
const wrongSize = SHOTS
  .map((s) => ({ shot: s.shot, ...pngSize(`${SRC_DIR}/${s.shot}`) }))
  .filter((s) => s.w !== W || s.h !== H);
if (wrongSize.length) {
  console.error(
    `\nCaptures must be exactly ${W}x${H} (iPhone 16/17 Pro Max):\n\n` +
    wrongSize.map((s) => `  ${s.shot}: ${s.w}x${s.h}`).join('\n') +
    '\n\nBoot the simulator named in capture_ios.sh and recapture.\n',
  );
  process.exit(1);
}

// --- template --------------------------------------------------------

const marks = (c) => [
  [-180, 120, 560], [980, 300, 420], [-120, 1870, 680], [1010, 2290, 520],
  [420, -220, 380],
].map(([x, y, d]) =>
  `<i style="left:${x}px;top:${y}px;width:${d}px;height:${d}px;background:${c}"></i>`,
).join('');

const page = (s) => `<!doctype html>
<html><head><meta charset="utf-8">
<style>
  @font-face{font-family:'Baloo 2';src:url('file:///C:/Duolingo/assets/fonts/Baloo2.ttf') format('truetype');font-weight:700;}
  @font-face{font-family:'Inter';src:url('file:///C:/Duolingo/assets/fonts/Inter.ttf') format('truetype');font-weight:400;}
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:${W}px;height:${H}px;overflow:hidden;}
  body{background:${s.theme.bg};position:relative;
       display:flex;flex-direction:column;align-items:center;}
  .marks{position:absolute;inset:0;overflow:hidden;}
  .marks i{position:absolute;border-radius:50%;display:block;}

  h1{font-family:'Baloo 2',system-ui,sans-serif;font-weight:700;
     font-size:124px;line-height:.97;letter-spacing:-3px;
     color:${s.theme.head};text-align:center;margin-top:132px;
     position:relative;z-index:3;padding:0 52px;}
  h1 em{font-style:normal;position:relative;white-space:nowrap;z-index:1;}
  h1 em::after{content:'';position:absolute;left:-14px;right:-14px;bottom:4px;
     height:34px;border-radius:17px;background:${s.theme.hi};z-index:-1;}

  p.sub{font-family:'Inter',system-ui,sans-serif;font-size:45px;line-height:1.32;
     color:${s.theme.sub};text-align:center;margin-top:32px;max-width:1030px;
     position:relative;z-index:3;padding:0 40px;}

  /* The capture itself, upright and unframed, bleeding off the bottom
     edge. The corner radius matches the display's own, so the screen
     ends the way the hardware does without a body drawn around it.
     Nothing overlaps the capture: what you see is the whole frame the
     simulator handed us, status bar and home indicator included. */
  .shot{position:relative;z-index:2;margin-top:74px;
     width:${Math.round(W * 0.745)}px;border-radius:62px;overflow:hidden;
     box-shadow:0 38px 86px ${s.theme.shadow}, 0 9px 24px ${s.theme.shadow};}
  .shot img{display:block;width:100%;height:auto;}
</style></head>
<body>
  <div class="marks">${marks(s.theme.mark)}</div>
  <h1>${s.head}</h1>
  <p class="sub">${s.sub}</p>
  <div class="shot"><img src="file:///${SRC_DIR}/${s.shot}" alt=""></div>
</body></html>`;

/// Sleeps without spinning the CPU or spawning a process.
const sleepSync = (ms) =>
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

/// Blocks until [p] exists and has stopped growing, or [ms] elapses.
///
/// Size has to settle as well as exist: a half-written PNG is already
/// on disk, and reading its header mid-flush gives a bogus dimension
/// check.
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

let failed = 0;
for (const s of SHOTS) {
  const htmlPath = `${BUILD}/ios_${s.file.replace('.png', '.html')}`;
  writeFileSync(htmlPath, page(s), 'utf8');
  const outPath = `${OUT}/${s.file}`.split('/').join('\\');
  execFileSync(EDGE, [
    '--headless=new', '--disable-gpu', '--force-device-scale-factor=1',
    '--hide-scrollbars', '--virtual-time-budget=4000',
    `--screenshot=${outPath}`,
    `--window-size=${W},${H}`, 'file:///' + htmlPath,
  ], { stdio: 'pipe' });

  // Edge returns before the PNG has landed, so checking immediately
  // reports every shot as failed while the files appear a moment later.
  // Wait for it rather than trusting the exit code, which is 0 either
  // way.
  if (!waitForFile(`${OUT}/${s.file}`)) {
    console.log('FAIL ' + s.file);
    failed++;
    continue;
  }
  const { w, h } = pngSize(`${OUT}/${s.file}`);
  const ok = w === W && h === H;
  if (!ok) failed++;
  console.log(`${ok ? 'ok  ' : 'SIZE'} ${s.file}  ${w}x${h}`);
}
process.exit(failed ? 1 : 0);

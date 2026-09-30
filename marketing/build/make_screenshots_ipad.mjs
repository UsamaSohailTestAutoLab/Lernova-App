// Builds the iPad App Store screenshot set.
//
// App Store Connect treats iPad as its own device family, and LingoQuest
// ships Universal (`TARGETED_DEVICE_FAMILY = "1,2"`), so a submission
// without this set is refused. Required size is 2064 x 2752 for the 13"
// slot; 2048 x 2732 is also accepted.
//
// Unlike the iPhone set, nothing here draws device chrome. Those shots
// were captured on Android at iPhone geometry and had an iOS status bar,
// Dynamic Island and home indicator painted over the cleared bands.
// These came off a real iPad, so the status bar in each frame is the
// device's own — real time, real battery. Drawing another over it would
// be inventing something that is already true.
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const RAW = 'C:/Duolingo/marketing/raw_ipad_device';
const OUT = 'C:/Duolingo/marketing/LingoQuest_AppStore_Screenshots_iPad';
const BUILD = 'C:/Duolingo/marketing/build';
mkdirSync(OUT, { recursive: true });

// iPad Pro 13", portrait. Every capture is already 3:4, so a screen
// drawn at this ratio never crops or letterboxes one.
const W = 2064;
const H = 2752;

const DEEP = {
  bg: 'linear-gradient(168deg,#31A522 0%,#2A8B1E 55%,#1F6B16 100%)',
  head: '#FFFFFF', sub: 'rgba(255,255,255,.84)',
  mark: 'rgba(255,255,255,.10)', hi: 'rgba(255,255,255,.22)',
};
const LIGHT = {
  bg: 'linear-gradient(168deg,#F4FBF1 0%,#DFF3D7 58%,#C3E7B6 100%)',
  head: '#0F3409', sub: 'rgba(15,52,9,.70)',
  mark: 'rgba(31,107,22,.09)', hi: 'rgba(63,191,43,.32)',
};
const AMBER = {
  bg: 'linear-gradient(168deg,#FFC94F 0%,#FFB020 55%,#F09405 100%)',
  head: '#3A2603', sub: 'rgba(58,38,3,.74)',
  mark: 'rgba(255,255,255,.24)', hi: 'rgba(255,255,255,.46)',
};

const SHOTS = [
  {
    file: '01_AppStore_LingoQuest_iPad.png', theme: DEEP,
    head: 'Learn a language<br>by <em>playing</em>',
    sub: 'Short lessons, ten real games, and a streak worth keeping.',
    front: '3.png',
  },
  {
    file: '02_AppStore_LingoQuest_iPad.png', theme: LIGHT,
    head: 'Ten games,<br>one <em>vocabulary</em>',
    sub: 'Every game practises the words your lessons just taught you.',
    front: '2.png',
  },
  {
    file: '03_AppStore_LingoQuest_iPad.png', theme: DEEP,
    head: 'Three hearts.<br>One <em>right answer</em>.',
    sub: 'Word Bubble gives you the word and the clock. Pick the meaning that fits.',
    front: '4.png',
  },
  {
    file: '04_AppStore_LingoQuest_iPad.png', theme: AMBER,
    head: '10 languages,<br>separate progress',
    sub: 'Switch any time. Each keeps its own lessons, XP and streak.',
    front: '1.png',
  },
];

// A fixed scatter of translucent circles — the Word Bubble motif used as
// page texture. Fixed rather than random so a rebuild is identical.
// Coordinates suit the 2064-wide canvas, so they are not the iPhone set's.
const BUBBLES = [
  [-220, 150, 620], [1680, 380, 470], [-140, 1980, 380], [1790, 1520, 560],
  [280, -190, 300], [1240, 2560, 480], [-250, 2760, 400], [1880, 2500, 330],
  [820, 180, 210], [420, 2260, 260],
];

const marks = (color) =>
  BUBBLES.map(
    ([x, y, d]) =>
      `<i style="left:${x}px;top:${y}px;width:${d}px;height:${d}px;background:${color};"></i>`,
  ).join('');

const src = (f) => `file:///${RAW}/${f}`;

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
     font-size:136px;line-height:.98;letter-spacing:-3.4px;
     color:${s.theme.head};text-align:center;margin-top:118px;
     position:relative;z-index:3;padding:0 80px;}
  h1 em{font-style:normal;position:relative;white-space:nowrap;z-index:1;}
  h1 em::after{content:'';position:absolute;left:-16px;right:-16px;bottom:6px;
     height:38px;border-radius:19px;background:${s.theme.hi};z-index:-1;}

  p.sub{font-family:'Inter',system-ui,sans-serif;font-size:50px;line-height:1.3;
     color:${s.theme.sub};text-align:center;margin-top:30px;max-width:1520px;
     position:relative;z-index:3;padding:0 60px;}

  /* An iPad body: a squarer corner than a phone and an even bezel on all
     four sides, because an iPad has no notch to break it. */
  .pad{position:relative;z-index:2;margin-top:64px;width:1560px;
     padding:26px;border-radius:62px;background:#0D1A0A;
     box-shadow:0 48px 104px rgba(6,26,4,.34),0 12px 30px rgba(6,26,4,.20);}
  .screen{position:relative;width:1508px;height:2011px;border-radius:26px;
     overflow:hidden;background:#F6FAF6;}
  /* Every capture is 3:4, so cover crops nothing — it only guards against
     a future capture that is a few pixels off. */
  .screen img{display:block;width:100%;height:100%;object-fit:cover;}
</style></head>
<body>
  <div class="marks">${marks(s.theme.mark)}</div>
  <h1>${s.head}</h1>
  <p class="sub">${s.sub}</p>
  <div class="pad"><div class="screen"><img src="${src(s.front)}" alt=""></div></div>
</body></html>`;

for (const s of SHOTS) {
  if (!existsSync(`${RAW}/${s.front}`)) {
    console.log(`SKIP ${s.file} — missing capture ${s.front}`);
    continue;
  }
  const htmlPath = `${BUILD}/${s.file.replace('.png', '.html')}`;
  writeFileSync(htmlPath, page(s), 'utf8');
  const outPath = `${OUT}/${s.file}`.split('/').join('\\');
  execFileSync(EDGE, [
    '--headless=new', '--disable-gpu', '--force-device-scale-factor=1',
    '--hide-scrollbars', `--screenshot=${outPath}`,
    `--window-size=${W},${H}`, 'file:///' + htmlPath,
  ], { stdio: 'pipe' });
  console.log(existsSync(`${OUT}/${s.file}`) ? 'ok   ' + s.file : 'FAIL ' + s.file);
}

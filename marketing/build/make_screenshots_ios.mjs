// Builds the iPhone App Store screenshot set.
//
// How these differ from the Play set: the app was captured with the
// device display overridden to 1320x2868 at 3x, so Flutter laid the UI
// out at 440x956pt — iPhone 16 Pro Max geometry exactly, not an Android
// screenshot stretched to fit. Android's status bar and gesture pill
// were then painted out (see clean_ios.mjs), and this template draws the
// iOS status bar, Dynamic Island and home indicator over the cleared
// bands.
//
// Those three elements are presentation, not capture — the same
// convention every App Store listing uses, and disclosed in the README.
// Everything inside them is the real running app.
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const OUT = 'C:/Duolingo/marketing/LingoQuest_AppStore_Screenshots_iPhone';
const BUILD = 'C:/Duolingo/marketing/build';
mkdirSync(OUT, { recursive: true });

const W = 1320;
const H = 2868;

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

const GAMES = [
  ['🫧', 'Word Bubble'], ['⚡', 'Word Rush'], ['🧩', 'Word Match'],
  ['🧠', 'Memory Match'], ['🔤', 'Sentence Builder'], ['💬', 'Phrase Builder'],
  ['🎧', 'Listen &amp; Catch'], ['🎯', 'Meaning Shooter'],
  ['🗣️', 'Conversation'], ['🌊', 'Word Survival'],
];

const SHOTS = [
  {
    file: '01_AppStore_LingoQuest.png', theme: DEEP, kind: 'duo',
    head: 'Learn a language<br>by <em>playing</em>',
    sub: 'Short lessons. Ten real games. One streak worth keeping.',
    front: 'home.png', back: 'memory_matched.png',
  },
  {
    file: '02_AppStore_LingoQuest.png', theme: DEEP, kind: 'duo',
    head: 'Turn words<br>into <em>games</em>',
    sub: 'Catch the right meaning before the bubble gets away.',
    front: 'wb_fall.png', back: 'wb_burst3.png',
  },
  {
    file: '03_AppStore_LingoQuest.png', theme: LIGHT, kind: 'grid',
    head: '10 games,<br>one <em>vocabulary</em>',
    sub: 'Every game practises the words your lessons just taught you.',
  },
  {
    file: '04_AppStore_LingoQuest.png', theme: AMBER, kind: 'phone',
    head: '10 languages,<br>separate progress',
    sub: 'Switch any time. Each keeps its own lessons, XP and streak.',
    front: 'languages.png', tilt: -3.5,
  },
  {
    file: '05_AppStore_LingoQuest.png', theme: DEEP, kind: 'duo',
    head: 'Flip. Match.<br><em>Remember.</em>',
    sub: 'Memory Match pairs every word with its meaning, against the clock.',
    front: 'memory_pairs.png', back: 'memory_matched.png',
  },
  {
    file: '06_AppStore_LingoQuest.png', theme: LIGHT, kind: 'phone',
    head: 'Right answer?<br>Watch it <em>pop</em>',
    sub: 'Correct bubbles burst into confetti and the next word drops in.',
    front: 'wb_burst3.png', tilt: 3,
  },
  {
    file: '07_AppStore_LingoQuest.png', theme: DEEP, kind: 'phone',
    head: 'Answer fast.<br>Stay afloat.',
    sub: 'Beat the rising water by picking the right meaning in time.',
    front: 'sv3.png', tilt: -3,
  },
  {
    file: '08_AppStore_LingoQuest.png', theme: LIGHT, kind: 'phone',
    head: 'Short lessons<br>that <em>stick</em>',
    sub: 'Read it, hear it, match it — five minutes at a time.',
    front: 'lesson_mcq.png', tilt: 3.5,
  },
  {
    file: '09_AppStore_LingoQuest.png', theme: AMBER, kind: 'phone',
    head: 'Every mistake<br>becomes practice',
    sub: 'Get it wrong and LingoQuest shows you why, then brings it back.',
    front: 'lesson_correction.png', tilt: -3,
  },
  {
    file: '10_AppStore_LingoQuest.png', theme: DEEP, kind: 'duo',
    head: 'Keep the<br><em>streak</em> alive',
    sub: 'XP, day streaks, badges and every word you have mastered.',
    front: 'statistics.png', back: 'achievements.png',
  },
];

const BUBBLES = [
  [-150, 110, 430], [1040, 300, 320], [-90, 1520, 250], [1130, 1160, 390],
  [190, -130, 210], [810, 2480, 330], [-170, 2210, 270], [1190, 2640, 230],
];
const marks = (c) => BUBBLES.map(([x, y, d]) =>
  `<i style="left:${x}px;top:${y}px;width:${d}px;height:${d}px;background:${c}"></i>`
).join('');

const src = (f) => 'file:///C:/Duolingo/marketing/ios_clean/' + f;

// The iOS furniture. Drawn, not captured — the cleared bands underneath
// are the app's own background colour.
const IOS_CHROME = `
  <div class="ios-status">
    <span class="t">9:41</span>
    <span class="ic">
      <svg viewBox="0 0 20 13" width="20" height="13" aria-hidden="true">
        <rect x="0"  y="9"   width="3" height="4"  rx="1" fill="currentColor"/>
        <rect x="4.5" y="6.5" width="3" height="6.5" rx="1" fill="currentColor"/>
        <rect x="9"  y="3.5" width="3" height="9.5" rx="1" fill="currentColor"/>
        <rect x="13.5" y="0" width="3" height="13" rx="1" fill="currentColor"/>
      </svg>
      <svg viewBox="0 0 18 13" width="18" height="13" aria-hidden="true">
        <path d="M9 12.2 6.3 9.3a3.9 3.9 0 0 1 5.4 0Z" fill="currentColor"/>
        <path d="M9 7.1a6.6 6.6 0 0 0-4.7 2L2.6 7.3a9 9 0 0 1 12.8 0l-1.7 1.8A6.6 6.6 0 0 0 9 7.1Z" fill="currentColor" opacity=".9"/>
        <path d="M9 2.4A11 11 0 0 0 1.4 5.5L0 4a13 13 0 0 1 18 0l-1.4 1.5A11 11 0 0 0 9 2.4Z" fill="currentColor" opacity=".8"/>
      </svg>
      <svg viewBox="0 0 27 13" width="27" height="13" aria-hidden="true">
        <rect x=".6" y=".6" width="22" height="11.8" rx="3.4"
              fill="none" stroke="currentColor" stroke-opacity=".4" stroke-width="1.2"/>
        <rect x="2.2" y="2.2" width="18.8" height="8.6" rx="2.2" fill="currentColor"/>
        <path d="M24.4 4.6v3.8a2.1 2.1 0 0 0 0-3.8Z" fill="currentColor" fill-opacity=".45"/>
      </svg>
    </span>
  </div>
  <div class="island"></div>
  <div class="home-ind"></div>`;

const phone = (file, cls, style) => `
  <div class="phone ${cls}" style="${style}">
    <div class="screen">
      <img src="${src(file)}" alt="">
      ${IOS_CHROME}
    </div>
  </div>`;

const stage = (s) => {
  if (s.kind === 'grid') {
    return `<div class="grid">${GAMES.map(([e, n]) =>
      `<div class="tile"><span class="e">${e}</span><span class="n">${n}</span></div>`
    ).join('')}</div>
    <img class="mascot" src="file:///C:/Duolingo/assets/images/lingoquest_parrot_celebrate.png" alt="">`;
  }
  if (s.kind === 'duo') {
    return `<div class="stage">
      ${phone(s.back, 'back', 'transform:rotate(6.5deg) translate(150px,120px) scale(.82);')}
      ${phone(s.front, 'front', 'transform:rotate(-3.5deg) translate(-46px,0);')}
    </div>`;
  }
  return `<div class="stage">${phone(s.front, 'front', `transform:rotate(${s.tilt || 0}deg);`)}</div>`;
};

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

  .stage{position:relative;z-index:2;margin-top:62px;width:100%;flex:1;}
  /* iPhone bodies are squarer-cornered than the Android frame and have a
     thinner, more even bezel. */
  .phone{position:absolute;top:0;left:50%;margin-left:-406px;
     width:812px;padding:11px;border-radius:76px;background:#0D1A0A;
     box-shadow:0 42px 92px rgba(6,26,4,.34),0 10px 26px rgba(6,26,4,.20);}
  .screen{position:relative;width:790px;height:1717px;border-radius:66px;
     overflow:hidden;background:#F6FAF6;}
  .screen img{display:block;width:100%;}

  /* iOS status bar, sitting in the band the Android one was lifted out
     of. Dark glyphs because every LingoQuest screen is light. */
  .ios-status{position:absolute;top:0;left:0;right:0;height:78px;
     display:flex;align-items:center;justify-content:space-between;
     padding:0 46px 0 52px;color:#0C1409;
     font-family:'Inter',system-ui,sans-serif;}
  .ios-status .t{font-size:31px;font-weight:600;letter-spacing:.2px;
     padding-top:12px;}
  .ios-status .ic{display:flex;align-items:center;gap:9px;padding-top:12px;}
  .ios-status svg{display:block;}
  .island{position:absolute;top:19px;left:50%;transform:translateX(-50%);
     width:224px;height:62px;border-radius:34px;background:#0A0A0A;}
  .home-ind{position:absolute;bottom:15px;left:50%;transform:translateX(-50%);
     width:268px;height:9px;border-radius:6px;background:rgba(12,20,9,.34);}

  .grid{position:relative;z-index:2;margin-top:92px;display:grid;
     grid-template-columns:repeat(2,1fr);gap:28px;width:1120px;}
  .tile{background:rgba(255,255,255,.92);border:2px solid rgba(31,107,22,.13);
     border-radius:34px;padding:44px 30px;display:flex;align-items:center;gap:24px;
     box-shadow:0 12px 28px rgba(16,40,10,.08);}
  .tile .e{font-size:66px;line-height:1;flex:none;}
  .tile .n{font-family:'Baloo 2',sans-serif;font-weight:700;font-size:42px;
     color:#153D0D;letter-spacing:-.5px;line-height:1.08;}
  .mascot{position:relative;z-index:2;width:420px;margin-top:56px;}
</style></head>
<body>
  <div class="marks">${marks(s.theme.mark)}</div>
  <h1>${s.head}</h1>
  <p class="sub">${s.sub}</p>
  ${stage(s)}
</body></html>`;

for (const s of SHOTS) {
  const htmlPath = `${BUILD}/ios_${s.file.replace('.png', '.html')}`;
  writeFileSync(htmlPath, page(s), 'utf8');
  const outPath = `${OUT}/${s.file}`.split('/').join('\\');
  execFileSync(EDGE, [
    '--headless=new', '--disable-gpu', '--force-device-scale-factor=1',
    '--hide-scrollbars', `--screenshot=${outPath}`,
    `--window-size=${W},${H}`, 'file:///' + htmlPath,
  ], { stdio: 'pipe' });
  console.log(existsSync(`${OUT}/${s.file}`) ? 'ok   ' + s.file : 'FAIL ' + s.file);
}

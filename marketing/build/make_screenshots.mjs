// Builds App Store marketing screenshots from the real captured screens.
//
// Rendered through headless Edge rather than an image library, because
// the headlines are set in the app's own Baloo 2 and Inter and a browser
// is the only renderer here that loads a local @font-face reliably. The
// phone body is drawn in CSS — a rounded rectangle, not a picture of any
// manufacturer's handset.
//
// Source pixels are untouched device captures in ../raw and frames cut
// from real screen recordings in ../video. Nothing in the app UI is
// redrawn, recoloured or rearranged; the additions are the ground, the
// bubble watermark, the headline and the frame.
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const RAW = 'C:/Duolingo/marketing/raw';
const VID = 'C:/Duolingo/marketing/video/frames';
const OUT = 'C:/Duolingo/marketing/LingoQuest_AppStore_Screenshots';
const BUILD = 'C:/Duolingo/marketing/build';
mkdirSync(OUT, { recursive: true });

// Apple's 6.9" iPhone class. Supplying only the largest size in the
// family is enough — App Store Connect scales it for the rest.
const W = 1320;
const H = 2868;

// Three grounds. Deep is the workhorse: the app's own primary green at
// full strength, which is what makes a phone screenshot — almost all of
// it near-white — read as a bright object sitting on the page. Light and
// amber are the relief, so the carousel has a rhythm rather than ten
// identical green tiles.
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
  bg: 'linear-gradient(168deg,#FFC busy)',
  head: '#3A2603', sub: 'rgba(58,38,3,.74)',
  mark: 'rgba(255,255,255,.24)', hi: 'rgba(255,255,255,.46)',
};
AMBER.bg = 'linear-gradient(168deg,#FFC94F 0%,#FFB020 55%,#F09405 100%)';

// The ten games, exactly as the Fun Zone lists them. The grid panel is
// built from the app's own roster rather than a marketing invention.
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
    front: 'raw/98_home_seeded.png', back: 'raw/mm_hero.png',
  },
  {
    file: '02_AppStore_LingoQuest.png', theme: DEEP, kind: 'duo',
    head: 'Turn words<br>into <em>games</em>',
    sub: 'Catch the right meaning before the bubble gets away.',
    front: 'raw/wb_midfall.png', back: 'raw/k03.png',
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
    front: 'raw/114_language_switch.png', tilt: -3.5,
  },
  {
    file: '05_AppStore_LingoQuest.png', theme: DEEP, kind: 'duo',
    head: 'Flip. Match.<br><em>Remember.</em>',
    sub: 'Memory Match pairs every word with its meaning, against the clock.',
    front: 'raw/m04_board.png', back: 'raw/mm_hero.png',
  },
  {
    file: '06_AppStore_LingoQuest.png', theme: LIGHT, kind: 'phone',
    head: 'Right answer?<br>Watch it <em>pop</em>',
    sub: 'Correct bubbles burst into confetti and the next word drops in.',
    front: 'raw/k03.png', tilt: 3,
  },
  {
    file: '07_AppStore_LingoQuest.png', theme: DEEP, kind: 'phone',
    head: 'Answer fast.<br>Stay afloat.',
    sub: 'Beat the rising water by picking the right meaning in time.',
    front: 'video/frames/sv_11.png', tilt: -3,
  },
  {
    file: '08_AppStore_LingoQuest.png', theme: LIGHT, kind: 'phone',
    head: 'Short lessons<br>that <em>stick</em>',
    sub: 'See it, hear it, say what it means — five minutes at a time.',
    front: 'raw/39_ex_image.png', tilt: 3.5,
  },
  {
    file: '09_AppStore_LingoQuest.png', theme: AMBER, kind: 'phone',
    head: 'Every mistake<br>becomes practice',
    sub: 'Get it wrong and LingoQuest shows you why, then brings it back.',
    front: 'raw/47_listen_result.png', tilt: -3,
  },
  {
    file: '10_AppStore_LingoQuest.png', theme: DEEP, kind: 'duo',
    head: 'Keep the<br><em>streak</em> alive',
    sub: 'XP, day streaks, badges and every word you have mastered.',
    front: 'raw/108_statistics.png', back: 'raw/111_achievements.png',
  },
];

// A fixed scatter of translucent circles — the Word Bubble motif used as
// page texture. Fixed rather than random so a rebuild is identical.
const BUBBLES = [
  [-150, 110, 430], [1040, 300, 320], [-90, 1520, 250], [1130, 1160, 390],
  [190, -130, 210], [810, 2480, 330], [-170, 2210, 270], [1190, 2640, 230],
];
const marks = (c) => BUBBLES.map(([x, y, d]) =>
  `<i style="left:${x}px;top:${y}px;width:${d}px;height:${d}px;background:${c}"></i>`
).join('');

const src = (rel) => 'file:///C:/Duolingo/marketing/' + rel;

const phone = (rel, cls, style) => `
  <div class="phone ${cls}" style="${style}">
    <div class="screen"><img src="${src(rel)}" alt=""></div>
  </div>`;

const stage = (s) => {
  if (s.kind === 'grid') {
    // The app's real cards, rendered by
    // test/widget/marketing_fun_grid.dart. This used to be ten
    // hand-made tiles imitating the UI, which is a thing that has to
    // be redrawn every time the UI moves and quietly goes stale when
    // it is not.
    return `<div class="grid"><img src="${src('raw/fun_grid_all.png')}" alt=""></div>
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
  /* The emphasised word gets a hand-drawn-feeling highlight bar, drawn
     in CSS so it scales with the type instead of sitting as an asset. */
  h1 em{font-style:normal;position:relative;white-space:nowrap;z-index:1;}
  h1 em::after{content:'';position:absolute;left:-14px;right:-14px;bottom:4px;
     height:34px;border-radius:17px;background:${s.theme.hi};z-index:-1;}

  p.sub{font-family:'Inter',system-ui,sans-serif;font-size:45px;line-height:1.32;
     color:${s.theme.sub};text-align:center;margin-top:32px;max-width:1030px;
     position:relative;z-index:3;padding:0 40px;}

  .stage{position:relative;z-index:2;margin-top:62px;width:100%;flex:1;}
  .phone{position:absolute;top:0;left:50%;margin-left:-406px;
     width:812px;padding:14px;border-radius:66px;background:#101A0C;
     box-shadow:0 42px 92px rgba(6,26,4,.34),0 10px 26px rgba(6,26,4,.20);}
  .screen{width:784px;height:1742px;border-radius:52px;overflow:hidden;background:#F6FAF6;}
  .screen img{display:block;width:100%;}

  /* The games panel. Ten modes as tiles read at thumbnail size where a
     screenshot of the scrolling list would not. */
  .grid{position:relative;z-index:2;margin-top:64px;width:1090px;flex:none;
     border-radius:44px;overflow:hidden;
     box-shadow:0 24px 54px rgba(16,40,10,.18);}
  .grid img{display:block;width:1090px;height:auto;}
  .tile{background:rgba(255,255,255,.90);border:2px solid rgba(31,107,22,.13);
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
void VID;

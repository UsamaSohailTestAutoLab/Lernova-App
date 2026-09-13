// Builds the iPhone App Store preview video.
//
// Every frame comes from the app running at iPhone 16 Pro Max geometry —
// the device display was overridden to 1320x2868 at 3x, so Flutter laid
// out at 440x956pt. Two beats are live screen recordings made at that
// geometry; the rest are device screenshots with a slow push-in, the
// same treatment the Play cut uses for its still beats.
//
// Android's status bar and gesture pill are covered and the iOS status
// bar, Dynamic Island and home indicator drawn in their place — the same
// presentation convention as the iPhone screenshot set, and disclosed in
// the README.
//
// Output targets Apple's iPhone preview spec: 886x1920 portrait, H.264
// High profile, constant 30fps, AAC stereo 48kHz, 15-30 seconds.
import { writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const FF = 'C:/Users/admin/AppData/Local/Temp/claude/c--Duolingo/b8e326e1-aa3e-4407-b889-c3a9e18c0d73/scratchpad/imgtool/node_modules/ffmpeg-static/ffmpeg.exe';
const CLEAN = 'C:/Duolingo/marketing/ios_clean';
const VID = 'C:/Duolingo/marketing/video';
const TMP = 'C:/Duolingo/marketing/build/vtmp_ios';
const OUT = 'C:/Duolingo/marketing';

rmSync(TMP, { recursive: true, force: true });
mkdirSync(TMP, { recursive: true });

const W = 886;
const H = 1920;
const BAND_H = 300;
const STAGE_H = H - BAND_H;           // 1620

// The capture is 1320x2868. Fitted to the stage by height it is 746 wide,
// leaving a 70px gutter each side. Android's chrome bands scale with it.
const CONTENT_W = 746;
const GUTTER = (W - CONTENT_W) / 2;   // 70
const TOP_BAND = 75;                  // 132px source
const BOT_BAND = 42;                  // 74px source
const CLIP_BG = '#F7F9F6';            // sampled from both recordings

const ff = (args) => execFileSync(FF, ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'pipe' });
const shot = (html, png, w, h) => {
  writeFileSync(html, arguments, 'utf8');
};

function render(htmlPath, pngPath, w, h) {
  execFileSync(EDGE, [
    '--headless=new', '--disable-gpu', '--force-device-scale-factor=1',
    '--hide-scrollbars', `--screenshot=${pngPath.split('/').join('\\')}`,
    `--window-size=${w},${h}`, 'file:///' + htmlPath,
  ], { stdio: 'pipe' });
}

// ─────────────────────────────────────────────────────────── iOS chrome
// Shared markup so the strips and the full still frames draw identical
// furniture.
const iosChromeCss = `
  .ios-status{position:absolute;top:0;left:0;right:0;height:${TOP_BAND}px;
     display:flex;align-items:center;justify-content:space-between;
     padding:0 26px 0 30px;color:#0C1409;
     font-family:'Inter',system-ui,sans-serif;}
  .ios-status .t{font-size:23px;font-weight:600;letter-spacing:.2px;padding-top:9px;}
  .ios-status .ic{display:flex;align-items:center;gap:6px;padding-top:9px;}
  .ios-status svg{display:block;}
  .island{position:absolute;top:13px;left:50%;transform:translateX(-50%);
     width:158px;height:44px;border-radius:24px;background:#0A0A0A;}
  .home-ind{position:absolute;bottom:10px;left:50%;transform:translateX(-50%);
     width:190px;height:6px;border-radius:4px;background:rgba(12,20,9,.34);}`;

const iosChromeHtml = `
  <div class="ios-status">
    <span class="t">9:41</span>
    <span class="ic">
      <svg viewBox="0 0 20 13" width="16" height="11"><rect x="0" y="9" width="3" height="4" rx="1" fill="currentColor"/><rect x="4.5" y="6.5" width="3" height="6.5" rx="1" fill="currentColor"/><rect x="9" y="3.5" width="3" height="9.5" rx="1" fill="currentColor"/><rect x="13.5" y="0" width="3" height="13" rx="1" fill="currentColor"/></svg>
      <svg viewBox="0 0 18 13" width="14" height="11"><path d="M9 12.2 6.3 9.3a3.9 3.9 0 0 1 5.4 0Z" fill="currentColor"/><path d="M9 7.1a6.6 6.6 0 0 0-4.7 2L2.6 7.3a9 9 0 0 1 12.8 0l-1.7 1.8A6.6 6.6 0 0 0 9 7.1Z" fill="currentColor" opacity=".9"/><path d="M9 2.4A11 11 0 0 0 1.4 5.5L0 4a13 13 0 0 1 18 0l-1.4 1.5A11 11 0 0 0 9 2.4Z" fill="currentColor" opacity=".8"/></svg>
      <svg viewBox="0 0 27 13" width="21" height="11"><rect x=".6" y=".6" width="22" height="11.8" rx="3.4" fill="none" stroke="currentColor" stroke-opacity=".4" stroke-width="1.2"/><rect x="2.2" y="2.2" width="18.8" height="8.6" rx="2.2" fill="currentColor"/><path d="M24.4 4.6v3.8a2.1 2.1 0 0 0 0-3.8Z" fill="currentColor" fill-opacity=".45"/></svg>
    </span>
  </div>
  <div class="island"></div>`;

const fontFaces = `
  @font-face{font-family:'Baloo 2';src:url('file:///C:/Duolingo/assets/fonts/Baloo2.ttf') format('truetype');font-weight:700;}
  @font-face{font-family:'Inter';src:url('file:///C:/Duolingo/assets/fonts/Inter.ttf') format('truetype');font-weight:400;}`;

// A strip for the clip beats: opaque, the sampled game background, with
// the status bar drawn on it.
{
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>${fontFaces}
    *{margin:0;padding:0;box-sizing:border-box;}
    html,body{width:${CONTENT_W}px;height:${TOP_BAND}px;overflow:hidden;background:${CLIP_BG};}
    body{position:relative;}${iosChromeCss}</style></head>
    <body>${iosChromeHtml}</body></html>`;
  writeFileSync(`${TMP}/strip_top.html`, html, 'utf8');
  render(`${TMP}/strip_top.html`, `${TMP}/strip_top.png`, CONTENT_W, TOP_BAND);
}
{
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>
    *{margin:0;padding:0;box-sizing:border-box;}
    html,body{width:${CONTENT_W}px;height:${BOT_BAND}px;overflow:hidden;background:${CLIP_BG};}
    body{position:relative;}${iosChromeCss}</style></head>
    <body><div class="home-ind"></div></body></html>`;
  writeFileSync(`${TMP}/strip_bot.html`, html, 'utf8');
  render(`${TMP}/strip_bot.html`, `${TMP}/strip_bot.png`, CONTENT_W, BOT_BAND);
}

// ───────────────────────────────────────────────────────────── captions
const captionHtml = (head, sub, dark) => `<!doctype html><html><head><meta charset="utf-8"><style>${fontFaces}
*{margin:0;padding:0;box-sizing:border-box;}
html,body{width:${W}px;height:${BAND_H}px;overflow:hidden;}
body{background:${dark ? '#14210F' : '#123A0C'};display:flex;flex-direction:column;
     align-items:center;justify-content:center;padding:0 48px;}
h1{font-family:'Baloo 2',sans-serif;font-weight:700;font-size:60px;line-height:1.08;
   color:#fff;text-align:center;letter-spacing:-0.5px;}
p{font-family:'Inter',sans-serif;font-size:30px;line-height:1.3;color:#9ADB8B;
  text-align:center;margin-top:14px;}
</style></head><body><h1>${head}</h1>${sub ? `<p>${sub}</p>` : ''}</body></html>`;

// ───────────────────────────────────────────────────────────── segments
// Same nine beats and the same words as the Play cut, so the two videos
// tell one story. The live-recording beats are the two the device was
// still attached for.
const SEGMENTS = [
  { id: 's1', kind: 'still', src: 'home.png', dur: 2.6,
    head: 'Learn a language<br>by playing', sub: 'LingoQuest' },
  { id: 's2', kind: 'still', src: 'languages.png', dur: 2.4,
    head: 'Choose your quest', sub: '10 languages, each with its own progress' },
  { id: 's3', kind: 'still', src: 'lesson_mcq.png', dur: 2.5,
    head: 'Learn new words', sub: 'Short lessons you finish in five minutes' },
  { id: 's3b', kind: 'still', src: 'fun_grid_phone.png', dur: 2.2,
    head: 'Ten games,<br>one vocabulary', sub: 'Every game practises what the lesson just taught' },
  { id: 's4', kind: 'still', src: 'wb_fall.png', dur: 2.7,
    head: 'Then play them', sub: 'Catch the right meaning before it gets away' },
  { id: 's5', kind: 'clip', src: `${VID}/wb_ios.mp4`, start: 1.6, dur: 3.2,
    head: 'Get it right,<br>watch it pop', sub: 'Correct answers burst into confetti' },
  { id: 's6', kind: 'clip', src: `${VID}/mm_ios.mp4`, start: 1.4, dur: 3.6,
    head: 'Flip. Match.<br>Remember.', sub: 'Pair every word with its meaning' },
  { id: 's7', kind: 'still', src: 'sv3.png', dur: 2.9,
    head: 'Or beat the<br>rising water', sub: 'Ten games, one vocabulary' },
  { id: 's8', kind: 'still', src: 'statistics.png', dur: 2.3,
    head: 'Build your streak', sub: 'XP, day streaks and every word mastered' },
  { id: 's9', kind: 'still', src: 'home.png', dur: 2.1,
    head: 'Start your<br>Language Quest', sub: 'LingoQuest — free to download' },
];

const parts = [];
for (const seg of SEGMENTS) {
  const capHtml = `${TMP}/${seg.id}_cap.html`;
  const capPng = `${TMP}/${seg.id}_cap.png`;
  writeFileSync(capHtml, captionHtml(seg.head, seg.sub, seg.kind === 'clip'), 'utf8');
  render(capHtml, capPng, W, BAND_H);

  const outMp4 = `${TMP}/${seg.id}.mp4`;

  if (seg.kind === 'still') {
    // The whole stage is composed in the browser so the iOS chrome sits
    // on each screen's own background colour rather than one guessed fill.
    const stageHtml = `${TMP}/${seg.id}_stage.html`;
    const stagePng = `${TMP}/${seg.id}_stage.png`;
    writeFileSync(stageHtml, `<!doctype html><html><head><meta charset="utf-8"><style>${fontFaces}
      *{margin:0;padding:0;box-sizing:border-box;}
      html,body{width:${W}px;height:${STAGE_H}px;overflow:hidden;background:#F2FAF0;}
      body{position:relative;display:flex;justify-content:center;}
      .wrap{position:relative;width:${CONTENT_W}px;height:${STAGE_H}px;}
      .wrap img{display:block;width:100%;}
      ${iosChromeCss}</style></head>
      <body><div class="wrap">
        <img src="file:///${CLEAN}/${seg.src}" alt="">
        ${iosChromeHtml}
        <div class="home-ind"></div>
      </div></body></html>`, 'utf8');
    render(stageHtml, stagePng, W, STAGE_H);

    const frames = Math.round(seg.dur * 30);
    const zoom = `zoompan=z='min(1.0+0.0008*on,1.09)':d=1:` +
      `x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=${W}x${STAGE_H}:fps=30`;
    ff(['-loop', '1', '-framerate', '30', '-t', String(seg.dur), '-i', stagePng, '-i', capPng,
      '-filter_complex', `[0:v]${zoom}[v];[v][1:v]vstack=inputs=2,format=yuv420p[out]`,
      '-map', '[out]', '-r', '30', '-c:v', 'libx264', '-profile:v', 'high',
      '-level', '4.0', '-pix_fmt', 'yuv420p', outMp4]);
    void frames;
  } else {
    // Scale the recording, cover Android's two bands, lay the iOS strips
    // over them, then stack the caption underneath.
    const chain =
      `[0:v]scale=-2:${STAGE_H},pad=${W}:${STAGE_H}:${GUTTER}:0:color=0xF2FAF0,setsar=1,fps=30,` +
      `drawbox=x=${GUTTER}:y=0:w=${CONTENT_W}:h=${TOP_BAND}:color=0xF7F9F6@1:t=fill,` +
      `drawbox=x=${GUTTER}:y=${STAGE_H - BOT_BAND}:w=${CONTENT_W}:h=${BOT_BAND}:color=0xF7F9F6@1:t=fill[v];` +
      `[v][2:v]overlay=${GUTTER}:0[v2];` +
      `[v2][3:v]overlay=${GUTTER}:${STAGE_H - BOT_BAND}[v3];` +
      `[v3][1:v]vstack=inputs=2,format=yuv420p[out]`;
    ff(['-ss', String(seg.start), '-t', String(seg.dur), '-i', seg.src,
      '-i', capPng, '-i', `${TMP}/strip_top.png`, '-i', `${TMP}/strip_bot.png`,
      '-filter_complex', chain,
      '-map', '[out]', '-r', '30', '-c:v', 'libx264', '-profile:v', 'high',
      '-level', '4.0', '-pix_fmt', 'yuv420p', outMp4]);
  }
  console.log('segment', seg.id, existsSync(outMp4) ? 'ok' : 'FAIL');
  parts.push(outMp4);
}

const listFile = `${TMP}/list.txt`;
writeFileSync(listFile, parts.map((p) => `file '${p}'`).join('\n'), 'utf8');

const finalPath = `${OUT}/LingoQuest_AppStore_Preview_iPhone.mp4`;
ff(['-f', 'concat', '-safe', '0', '-i', listFile,
  '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
  '-shortest', '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0',
  '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'aac', '-b:a', '128k', '-ar', '48000',
  '-movflags', '+faststart', finalPath]);
console.log('iPhone preview:', existsSync(finalPath) ? 'ok' : 'FAIL');

const socialParts = [parts[0], parts[4], parts[8]];
writeFileSync(`${TMP}/social.txt`, socialParts.map((p) => `file '${p}'`).join('\n'), 'utf8');
const socialPath = `${OUT}/LingoQuest_Social_Preview_iPhone.mp4`;
ff(['-f', 'concat', '-safe', '0', '-i', `${TMP}/social.txt`,
  '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
  '-shortest', '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0',
  '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'aac', '-b:a', '128k', '-ar', '48000',
  '-movflags', '+faststart', socialPath]);
console.log('iPhone social:', existsSync(socialPath) ? 'ok' : 'FAIL');
void shot;

// Builds the App Store preview video from real captured footage.
//
// Every frame is either a device screen recording (adb screenrecord) or
// a device screenshot. Nothing is mocked up or re-animated; the only
// additions are the caption band and the cross-cuts.
//
// Output targets Apple's iPhone preview spec: 886x1920 portrait, H.264
// High profile, constant 30fps, AAC stereo 48kHz, 15-30 seconds.
import { writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const FF = 'C:/Users/admin/AppData/Local/Temp/claude/c--Duolingo/b8e326e1-aa3e-4407-b889-c3a9e18c0d73/scratchpad/imgtool/node_modules/ffmpeg-static/ffmpeg.exe';
const RAW = 'C:/Duolingo/marketing/raw';
const VID = 'C:/Duolingo/marketing/video';
const TMP = 'C:/Duolingo/marketing/build/vtmp';
const OUT = 'C:/Duolingo/marketing';

rmSync(TMP, { recursive: true, force: true });
mkdirSync(TMP, { recursive: true });

const W = 886;
const H = 1920;
const BAND_H = 300;

const ff = (args) => execFileSync(FF, ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'pipe' });

// ---------------------------------------------------------------- captions

// Rendered in the app's own Baloo 2 through headless Edge — ffmpeg's
// drawtext cannot load a local face reliably on Windows, and the
// headline type is half the point of a preview.
const captionHtml = (head, sub, dark) => `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'Baloo 2';src:url('file:///C:/Duolingo/assets/fonts/Baloo2.ttf') format('truetype');font-weight:700;}
@font-face{font-family:'Inter';src:url('file:///C:/Duolingo/assets/fonts/Inter.ttf') format('truetype');font-weight:400;}
*{margin:0;padding:0;box-sizing:border-box;}
html,body{width:${W}px;height:${BAND_H}px;overflow:hidden;}
body{background:${dark ? '#14210F' : '#123A0C'};display:flex;flex-direction:column;
     align-items:center;justify-content:center;padding:0 48px;}
h1{font-family:'Baloo 2',sans-serif;font-weight:700;font-size:60px;line-height:1.08;
   color:#fff;text-align:center;letter-spacing:-0.5px;}
p{font-family:'Inter',sans-serif;font-size:30px;line-height:1.3;color:#9ADB8B;
  text-align:center;margin-top:14px;}
</style></head><body><h1>${head}</h1>${sub ? `<p>${sub}</p>` : ''}</body></html>`;

// ----------------------------------------------------------------- segments

// The storyboard. `still` segments are screenshots with a slow push-in;
// `clip` segments are real gameplay recordings, trimmed to their most
// legible stretch.
const SEGMENTS = [
  { id: 's1', kind: 'still', src: `${RAW}/98_home_seeded.png`, dur: 2.6,
    head: 'Learn a language<br>by playing', sub: 'LingoQuest' },
  { id: 's2', kind: 'still', src: `${RAW}/114_language_switch.png`, dur: 2.4,
    head: 'Choose your quest', sub: '10 languages, each with its own progress' },
  { id: 's3', kind: 'still', src: `${RAW}/39_ex_image.png`, dur: 2.5,
    head: 'Learn new words', sub: 'Short lessons you finish in five minutes' },
  { id: 's3b', kind: 'still', src: `${RAW}/fun_grid_phone.png`, dur: 2.2,
    head: 'Ten games,<br>one vocabulary', sub: 'Every game practises what the lesson just taught' },
  { id: 's4', kind: 'clip', src: `${VID}/wb2.mp4`, start: 1.0, dur: 3.3,
    head: 'Then play them', sub: 'Catch the right meaning before it gets away' },
  { id: 's5', kind: 'clip', src: `${VID}/burst2.mp4`, start: 1.7, dur: 3.2,
    head: 'Get it right,<br>watch it pop', sub: 'Correct answers burst into confetti' },
  { id: 's6', kind: 'clip', src: `${VID}/memory2.mp4`, start: 2.0, dur: 3.6,
    head: 'Flip. Match.<br>Remember.', sub: 'Pair every word with its meaning' },
  { id: 's7', kind: 'clip', src: `${VID}/survival.mp4`, start: 7.0, dur: 2.9,
    head: 'Or beat the<br>rising water', sub: 'Ten games, one vocabulary' },
  { id: 's8', kind: 'still', src: `${RAW}/108_statistics.png`, dur: 2.3,
    head: 'Build your streak', sub: 'XP, day streaks and every word mastered' },
  { id: 's9', kind: 'still', src: `${RAW}/98_home_seeded.png`, dur: 2.1,
    head: 'Start your<br>Language Quest', sub: 'LingoQuest — free to download' },
];

// Scale any source into the frame without cropping, on the app's own
// off-white ground, then drop the caption band over the bottom.
const FIT = `scale=${W}:${H - BAND_H}:force_original_aspect_ratio=decrease,` +
  `pad=${W}:${H - BAND_H}:(ow-iw)/2:(oh-ih)/2:color=0xF2FAF0,setsar=1`;

const parts = [];
for (const seg of SEGMENTS) {
  const capHtml = `${TMP}/${seg.id}_cap.html`;
  const capPng = `${TMP}/${seg.id}_cap.png`;
  writeFileSync(capHtml, captionHtml(seg.head, seg.sub, seg.kind === 'clip'), 'utf8');
  execFileSync(EDGE, [
    '--headless=new', '--disable-gpu', '--force-device-scale-factor=1',
    '--hide-scrollbars', `--screenshot=${capPng.split('/').join('\\')}`,
    `--window-size=${W},${BAND_H}`, 'file:///' + capHtml,
  ], { stdio: 'pipe' });

  const outMp4 = `${TMP}/${seg.id}.mp4`;
  const frames = Math.round(seg.dur * 30);

  if (seg.kind === 'still') {
    // A slow push-in so a screenshot still reads as motion.
    const zoom = `zoompan=z='min(1.0+0.0008*on,1.09)':d=1:` +
      `x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=${W}x${H - BAND_H}:fps=30`;
    ff(['-loop', '1', '-framerate', '30', '-t', String(seg.dur), '-i', seg.src, '-i', capPng,
      '-filter_complex',
      `[0:v]${FIT},${zoom}[v];[v][1:v]vstack=inputs=2,format=yuv420p[out]`,
      '-map', '[out]', '-r', '30', '-c:v', 'libx264', '-profile:v', 'high',
      '-level', '4.0', '-pix_fmt', 'yuv420p', outMp4]);
  } else {
    ff(['-ss', String(seg.start), '-t', String(seg.dur), '-i', seg.src, '-i', capPng,
      '-filter_complex',
      `[0:v]${FIT},fps=30[v];[v][1:v]vstack=inputs=2,format=yuv420p[out]`,
      '-map', '[out]', '-r', '30', '-c:v', 'libx264', '-profile:v', 'high',
      '-level', '4.0', '-pix_fmt', 'yuv420p', outMp4]);
  }
  console.log('segment', seg.id, existsSync(outMp4) ? 'ok' : 'FAIL');
  parts.push(outMp4);
}

// ------------------------------------------------------------------ concat

const listFile = `${TMP}/list.txt`;
writeFileSync(listFile, parts.map((p) => `file '${p}'`).join('\n'), 'utf8');

// A silent AAC 48 kHz stereo track: Apple validates the audio settings
// even when a preview has nothing to say.
const finalPath = `${OUT}/LingoQuest_AppStore_Preview.mp4`;
ff(['-f', 'concat', '-safe', '0', '-i', listFile,
  '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
  '-shortest', '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0',
  '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'aac', '-b:a', '128k', '-ar', '48000',
  '-movflags', '+faststart', finalPath]);
console.log('preview:', existsSync(finalPath) ? 'ok' : 'FAIL');

// A shorter square-ish social cut: the hook, one game, the CTA.
const socialParts = [parts[0], parts[4], parts[8]];
const socialList = `${TMP}/social.txt`;
writeFileSync(socialList, socialParts.map((p) => `file '${p}'`).join('\n'), 'utf8');
const socialPath = `${OUT}/LingoQuest_Social_Preview.mp4`;
ff(['-f', 'concat', '-safe', '0', '-i', socialList,
  '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
  '-shortest', '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0',
  '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'aac', '-b:a', '128k', '-ar', '48000',
  '-movflags', '+faststart', socialPath]);
console.log('social:', existsSync(socialPath) ? 'ok' : 'FAIL');

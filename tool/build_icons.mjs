#!/usr/bin/env node
// Regenerates every launcher icon from one source image.
//
//   node tool/build_icons.mjs <source.png> [--bg #RRGGBB]
//
// Writes:
//   assets/icon/app_icon_master.png            1024, the archival master
//   android .../mipmap-*/ic_launcher.png       legacy square icon
//   android .../mipmap-*/ic_launcher_foreground.png  adaptive foreground
//   android .../mipmap-*/ic_launcher_background.png  adaptive background
//   ios .../AppIcon.appiconset/Icon-App-*.png  every size Contents.json lists
//
// Needs `sharp`, which is not a project dependency — install it wherever
// you run this (`npm i sharp` in a scratch directory and run with
// NODE_PATH pointing at that node_modules).

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const sharp = require('sharp');

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

const args = process.argv.slice(2);
const src = args.find((a) => !a.startsWith('--'));
if (!src) {
  console.error('usage: node tool/build_icons.mjs <source.png> [--bg #RRGGBB]');
  process.exit(1);
}
const bgArg = args.indexOf('--bg');
const BG = bgArg >= 0 ? args[bgArg + 1] : '#277A1C'; // AppColors.primary
const rgb = {
  r: parseInt(BG.slice(1, 3), 16),
  g: parseInt(BG.slice(3, 5), 16),
  b: parseInt(BG.slice(5, 7), 16),
};

/// Strips a flat backdrop and returns the character on transparency,
/// cropped to its own bounds.
///
/// Done by flood-filling inward from the border rather than keying on
/// colour: this character has white eyes and a cream belly that a
/// global "remove everything light" rule would erase from the middle
/// of its face.
async function cutout(file) {
  const { data, info } = await sharp(file).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  const W = info.width, H = info.height, C = info.channels;

  // Sample the corners to learn what the backdrop actually is, rather
  // than assuming white or black.
  const corners = [0, (W - 1), (H - 1) * W, H * W - 1].map((i) => {
    const p = i * C;
    return [data[p], data[p + 1], data[p + 2]];
  });
  const bg = corners[0];
  const near = (p) =>
    Math.abs(data[p] - bg[0]) < 42 &&
    Math.abs(data[p + 1] - bg[1]) < 42 &&
    Math.abs(data[p + 2] - bg[2]) < 42;

  const outside = new Uint8Array(W * H);
  const st = new Int32Array(W * H);
  let sp = 0;
  const push = (x, y) => {
    const i = y * W + x;
    if (!outside[i] && near(i * C)) { outside[i] = 1; st[sp++] = i; }
  };
  for (let x = 0; x < W; x++) { push(x, 0); push(x, H - 1); }
  for (let y = 0; y < H; y++) { push(0, y); push(W - 1, y); }
  while (sp > 0) {
    const i = st[--sp], x = i % W, y = (i - x) / W;
    if (x > 0) push(x - 1, y);
    if (x < W - 1) push(x + 1, y);
    if (y > 0) push(x, y - 1);
    if (y < H - 1) push(x, y + 1);
  }

  const out = Buffer.alloc(W * H * 4);
  let x0 = W, y0 = H, x1 = 0, y1 = 0;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x, si = i * C, di = i * 4;
      out[di] = data[si]; out[di + 1] = data[si + 1]; out[di + 2] = data[si + 2];
      out[di + 3] = outside[i] ? 0 : 255;
      if (!outside[i]) {
        if (x < x0) x0 = x; if (x > x1) x1 = x;
        if (y < y0) y0 = y; if (y > y1) y1 = y;
      }
    }
  }

  return sharp(out, { raw: { width: W, height: H, channels: 4 } })
    .extract({ left: x0, top: y0, width: x1 - x0 + 1, height: y1 - y0 + 1 })
    .png().toBuffer();
}

/// The character centred on [canvas], occupying [fraction] of it.
async function compose(character, canvas, fraction, opaque) {
  const inner = Math.round(canvas * fraction);
  const art = await sharp(character)
    .resize({ width: inner, height: inner, fit: 'inside' })
    .toBuffer();
  const base = sharp({
    create: {
      width: canvas, height: canvas, channels: 4,
      background: opaque ? { ...rgb, alpha: 1 } : { r: 0, g: 0, b: 0, alpha: 0 },
    },
  });
  return base.composite([{ input: art, gravity: 'center' }]).png().toBuffer();
}

const write = (p, buf) => {
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, buf);
};

const DENSITIES = [
  ['mdpi', 48, 108],
  ['hdpi', 72, 162],
  ['xhdpi', 96, 216],
  ['xxhdpi', 144, 324],
  ['xxxhdpi', 192, 432],
];

(async () => {
  const character = await cutout(src);

  // Archival master.
  write(join(root, 'assets/icon/app_icon_master.png'),
    await compose(character, 1024, 0.74, true));

  for (const [d, legacy, adaptive] of DENSITIES) {
    const dir = join(root, 'android/app/src/main/res', `mipmap-${d}`);
    write(join(dir, 'ic_launcher.png'),
      await compose(character, legacy, 0.74, true));
    // Adaptive foregrounds are masked and then inset by the launcher —
    // only the middle ~66% of the canvas is guaranteed visible on every
    // icon shape. 0.55 fills that circle without touching its edge; the
    // tall pointer stick is what sets the limit, not the bird.
    write(join(dir, 'ic_launcher_foreground.png'),
      await compose(character, adaptive, 0.55, false));
    write(join(dir, 'ic_launcher_background.png'),
      await sharp({
        create: { width: adaptive, height: adaptive, channels: 4,
          background: { ...rgb, alpha: 1 } },
      }).png().toBuffer());
  }

  // iOS rejects any alpha channel in an app icon, so these are flattened.
  const iosDir = join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const manifest = JSON.parse(
    readFileSync(join(iosDir, 'Contents.json'), 'utf8'),
  );
  const wanted = new Map();
  for (const i of manifest.images) {
    if (!i.filename) continue;
    const [w] = i.size.split('x').map(Number);
    wanted.set(i.filename, Math.round(w * parseFloat(i.scale)));
  }
  for (const [name, px] of wanted) {
    if (!existsSync(join(iosDir, name))) continue;
    const buf = await compose(character, px, 0.74, true);
    write(join(iosDir, name), await sharp(buf).flatten({ background: rgb })
      .png({ compressionLevel: 9 }).toBuffer());
  }

  console.log(`icons rebuilt from ${src} on ${BG}`);
  console.log(`  android: ${DENSITIES.length} densities x 3 files`);
  console.log(`  ios:     ${wanted.size} sizes`);
})();

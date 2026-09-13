import { copyFileSync, existsSync, mkdirSync, readdirSync } from 'node:fs';
import { dirname } from 'node:path';

/**
 * Copies the freshly built screenshots and videos into every folder
 * that ships a copy of them.
 *
 * The builders write one set each — `LingoQuest_AppStore_Screenshots`
 * for the Android-geometry captures and
 * `LingoQuest_AppStore_Screenshots_iPhone` for the iPhone ones — but the
 * hand-off folders (the Play set, the assembled ASO package, the iPhone
 * bundle) were populated by copying them across by hand. That is the
 * kind of step nobody remembers, and it showed: after the game cards
 * were redesigned and the screenshots rebuilt, the Play folder still
 * held images of a screen that no longer existed.
 *
 *     node marketing/build/sync_assets.mjs
 */
const M = 'C:/Duolingo/marketing';

/** source set → every folder that must mirror it. */
const FANOUT = [
  [
    `${M}/LingoQuest_AppStore_Screenshots`,
    [
      `${M}/LingoQuest_PlayStore_Screenshots_Android`,
      `${M}/LingoQuest_AppStore_ASO_Package/LingoQuest_PlayStore_Screenshots_Android`,
    ],
  ],
  [
    `${M}/LingoQuest_AppStore_Screenshots_iPhone`,
    [
      `${M}/LingoQuest_AppStore_ASO_Package/LingoQuest_AppStore_Screenshots_iPhone`,
      `${M}/LingoQuest_iPhone_Screenshots/LingoQuest_AppStore_Screenshots_iPhone`,
    ],
  ],
];

/** built video → every folder that ships a copy of it. */
const VIDEOS = [
  [
    `${M}/LingoQuest_AppStore_Preview.mp4`,
    `${M}/LingoQuest_AppStore_ASO_Package/Video/Android/LingoQuest_AppStore_Preview.mp4`,
  ],
  [
    `${M}/LingoQuest_Social_Preview.mp4`,
    `${M}/LingoQuest_AppStore_ASO_Package/Video/Android/LingoQuest_Social_Preview.mp4`,
  ],
  [
    `${M}/LingoQuest_AppStore_Preview_iPhone.mp4`,
    `${M}/LingoQuest_AppStore_ASO_Package/Video/iPhone/LingoQuest_AppStore_Preview_iPhone.mp4`,
  ],
  [
    `${M}/LingoQuest_Social_Preview_iPhone.mp4`,
    `${M}/LingoQuest_AppStore_ASO_Package/Video/iPhone/LingoQuest_Social_Preview_iPhone.mp4`,
  ],
];

let copied = 0;
for (const [from, targets] of FANOUT) {
  if (!existsSync(from)) {
    console.error(`missing source set: ${from}`);
    process.exitCode = 1;
    continue;
  }
  const files = readdirSync(from).filter((f) => f.endsWith('.png'));
  for (const to of targets) {
    mkdirSync(to, { recursive: true });
    for (const f of files) {
      copyFileSync(`${from}/${f}`, `${to}/${f}`);
      copied++;
    }
    console.log(`${files.length.toString().padStart(2)} → ${to.slice(M.length + 1)}`);
  }
}
for (const [from, to] of VIDEOS) {
  if (!existsSync(from)) {
    console.error(`missing video: ${from}`);
    process.exitCode = 1;
    continue;
  }
  mkdirSync(dirname(to), { recursive: true });
  copyFileSync(from, to);
  copied++;
  console.log(` 1 → ${to.slice(M.length + 1)}`);
}

console.log(`\n${copied} files copied.`);

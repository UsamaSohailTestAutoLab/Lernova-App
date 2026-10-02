# App Store screenshots

## Why the first iPhone set was rejected

> "phone style not correct you are using other phone style screenshot"

The reviewer was right, and the dimensions were never the problem — the
submitted files were already exactly 1320×2868.

The set had been captured on a **Pixel 5a** with the display overridden
to `1320x2868 @3x`, so Flutter laid the UI out at 440×956pt: iPhone 16
Pro Max geometry, exactly. Android's status bar and gesture pill were
then painted out, and an iOS status bar, Dynamic Island and home
indicator were drawn over the cleared bands inside a hand-drawn phone
body.

That gets the **geometry** right. It cannot change the **renderer**.

The giveaway is the emoji. LingoQuest's UI is full of them — the medal,
star, flame, trophy, controller and railway on Home alone — and on
Android they come from **Noto Color Emoji**, whose designs look nothing
like Apple's. Magnify the medal in any of the old captures and it is
plainly Google's. A reviewer who sees Apple Color Emoji every working
day spots that immediately.

Text rasterisation, the flag emoji, Material ink and the scroll
affordances were Android's too.

**There is no way to fix this in post.** The screenshots have to be
rendered by iOS.

## Capturing on a real iPhone

The simplest route, and it needs no Mac. Drop the PNGs into
`marketing/raw_ios_device/` under the names in the table below, then
run the compositor.

### Which iPhone

It has to be a **Pro Max or Plus**, because the 6.9" slot only takes
two sizes and only those handsets produce them:

| Handset | Capture size |
|---|---|
| iPhone 16 Pro Max, 17 Pro Max | 1320×2868 |
| iPhone 14/15 Pro Max, 15/16 Plus | 1290×2796 |

Either is accepted as-is; the compositor reads the size off the
captures and builds the canvas to match. A smaller iPhone cannot be
enlarged to fit — that is the same mistake as the Pixel captures, and
the script refuses it.

All ten must come from the **same** phone.

### Before capturing

- **Light mode.** The layout assumes light screens.
- **Sign out of nothing, delete nothing** — the state matters. The
  listing shows a lived-in account: 4860 XP, a 24-day streak, 10
  achievements. A fresh install shows zeroes and sells nothing.
- Battery above ~40% and full signal; the real status bar is kept, and
  Apple does not require the 9:41 convention on device captures.

### The ten screens

| File | Screen |
|---|---|
| `home.png` | Home tab, scrolled to the top |
| `wb_fall.png` | Word Bubble mid-round, bubbles falling |
| `funhub.png` | Fun tab, the game grid |
| `languages.png` | Settings → Language, picker open |
| `memory_pairs.png` | Memory Match, memorise phase, timer visible |
| `wb_burst3.png` | Word Bubble as a correct bubble pops |
| `sv3.png` | Word Survival level 3, water partway up |
| `lesson_mcq.png` | A Path lesson, multiple-choice question |
| `lesson_correction.png` | A Path lesson, correction bar after a wrong answer |
| `statistics.png` | Profile / statistics, streak and achievements |

### Getting them off the phone

**Do not send them through WhatsApp, Telegram or Messenger.** Those
resample images on the way through, and a 1320×2868 capture arrives
smaller. That silently reintroduces the wrong-size problem.

AirDrop, iCloud Drive, Google Drive, or email **as an attachment**, all
of which preserve the original file.

## Producing the iPhone set (simulator route)

### 1. Capture on a 6.9" simulator

```bash
./marketing/build/capture_ios.sh
```

Needs macOS with Xcode. It boots an iPhone 17 Pro Max (falling back to
16 Pro Max — both render 1320×2868), applies Apple's 9:41 status-bar
convention via `simctl status_bar override`, builds and installs the
app, then prompts for each of the ten screens in turn. Captures land in
`marketing/raw_ios_device/` and each one's size is verified as it is
taken.

The status bar override is a simulator setting, not a drawn overlay —
the status bar in the capture is still the real one.

**No Mac?** Run the `ios-screenshots` workflow from the Actions tab. It
does the same on a hosted macOS runner and uploads the PNGs as an
artifact. It cannot navigate the app, so it returns the launch screen
only; the rest need either a local run or an `integration_test` driver.

### 2. Composite

```bash
node marketing/build/make_store_screenshots.mjs iphone
```

Writes `marketing/LingoQuest_AppStore_Screenshots_iPhone/`.

The template draws **no device body, no status bar and no home
indicator** — a real capture already has a real one, and every piece of
invented chrome is something a reviewer can call inaccurate. Each shot
is a single upright screen bleeding off the bottom edge, with the
caption above it.

It refuses to run if `marketing/raw_ios_device/` is missing a screen or
holds anything that is not exactly 1320×2868, so the Android set cannot
quietly come back.

## One set, both stores

The rule is asymmetric:

- iOS-rendered screenshots on **Google Play** — fine. Google has no rule
  about which platform a screenshot came from.
- Android-rendered screenshots on the **App Store** — rejected. This is
  what happened.

So capture once on iOS and use those pixels for both listings. The
`play` target reads the same `raw_ios_device/` directory for exactly
that reason, and falls back to the Android captures — saying so out
loud — only while the iOS ones do not exist.

```bash
node marketing/build/make_store_screenshots.mjs all     # iphone, ipad, play
```

One script builds all three targets from one shot list and one
template. There used to be three near-identical copies, which is how
the iPhone one drifted into drawing a fake device body while the others
did not.

## Do not use these

- `marketing/raw/` — Pixel 5a captures, 1080×2400. Correct for Play.
- `marketing/raw_ios/` — Pixel 5a at overridden iPhone geometry. **This
  is the rejected source.** Kept only so the mistake stays legible.
- `marketing/ios_clean/` — the same, with Android chrome painted out.

## Sizes App Store Connect accepts

| Slot | Required | Notes |
|---|---|---|
| iPhone 6.9" | 1320×2868 or 1290×2796 | iPhone 16/17 Pro Max |
| iPad 13" | 2064×2752 | Mandatory: `TARGETED_DEVICE_FAMILY = "1,2"` |

## iPad

`marketing/raw_ipad_device/` holds captures from a real iPad, so these
are genuinely iOS-rendered and not affected by the rejection above. They
are 1536×2048, upscaled to 2064×2752 — same 3:4 aspect, so no
distortion, but `3.png` is only 768×1024 and is being enlarged 2.7×.
Recapture that one on a 13" iPad or simulator when convenient.

The app still has **no iPad layout** — the phone layout is stretched, so
Fun cards run ~740pt wide against ~174pt on a phone.

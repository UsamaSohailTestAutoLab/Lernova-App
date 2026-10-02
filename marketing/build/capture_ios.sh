#!/usr/bin/env bash
#
# Captures the App Store screenshot sources on an iOS Simulator.
#
# WHY THIS EXISTS
#
# The first submission was rejected with "phone style not correct, you
# are using other phone style screenshot". The screenshots had been
# taken on a Pixel 5a with the display forced to 1320x2868, which gets
# the geometry right but leaves every pixel rendered by Android —
# Google's emoji above all, which look nothing like Apple's and give the
# whole set away immediately.
#
# Geometry can be faked. A renderer cannot. These have to come from iOS.
#
# WHAT THIS PRODUCES
#
# PNGs in marketing/raw_ios_device/ at exactly 1320x2868, drawn by iOS,
# with a real iOS status bar pinned to Apple's own 9:41 convention. Feed
# them to make_screenshots_ios.mjs.
#
# USAGE
#
#   ./marketing/build/capture_ios.sh            # interactive
#   ./marketing/build/capture_ios.sh home.png   # capture one and exit
#
# Needs macOS with Xcode. No Mac? Push the branch and run the
# "ios-screenshots" GitHub Actions workflow, which does all of this on a
# hosted macOS runner and uploads the result as a build artifact.
set -euo pipefail

# iPhone 16 Pro Max and 17 Pro Max both render at 1320x2868, which is
# the 6.9" slot App Store Connect asks for. Whichever this Xcode has.
DEVICE="${DEVICE:-iPhone 17 Pro Max}"
FALLBACK_DEVICE="iPhone 16 Pro Max"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO/marketing/raw_ios_device"
mkdir -p "$OUT"

# The ten screens the compositor consumes, in the order it lists them.
# Keep these names in step with SHOTS in make_screenshots_ios.mjs.
SCREENS=(
  "home.png|Home tab, scrolled to the top"
  "wb_fall.png|Word Bubble mid-round, bubbles falling"
  "funhub.png|Fun tab, the game grid"
  "languages.png|Settings > Language, the picker open"
  "memory_pairs.png|Memory Match, the memorise phase with the timer up"
  "wb_burst3.png|Word Bubble at the instant a correct bubble pops"
  "sv3.png|Word Survival level 3, water partway up"
  "lesson_mcq.png|A Path lesson, multiple-choice question"
  "lesson_correction.png|A Path lesson, the correction bar after a wrong answer"
  "statistics.png|Profile / statistics, streak and achievements visible"
)

say() { printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }

command -v xcrun >/dev/null || { echo "xcrun not found — needs macOS with Xcode."; exit 1; }

# --- boot ------------------------------------------------------------

if ! xcrun simctl list devices available | grep -q "$DEVICE"; then
  warn "No '$DEVICE' in this Xcode; falling back to '$FALLBACK_DEVICE'."
  DEVICE="$FALLBACK_DEVICE"
fi
xcrun simctl list devices available | grep -q "$DEVICE" || {
  echo "Neither device is available. Install a 6.9\" simulator in Xcode > Settings > Components."
  exit 1
}

UDID="$(xcrun simctl list devices available \
        | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
say "Using $DEVICE  ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID" || true

# Apple's own screenshot convention: 9:41, full bars, no carrier
# clutter. This is a simulator display setting, not a drawn overlay —
# the status bar in the capture is still the real one.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

# --- build & install --------------------------------------------------

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  say "Building the app for the simulator…"
  ( cd "$REPO" && flutter build ios --simulator --debug )
  APP="$REPO/build/ios/iphonesimulator/Runner.app"
  [[ -d "$APP" ]] || { echo "Build produced no $APP"; exit 1; }
  xcrun simctl install "$UDID" "$APP"
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  "$REPO/build/ios/iphonesimulator/Runner.app/Info.plist" 2>/dev/null || echo '')"
if [[ -n "$BUNDLE_ID" ]]; then
  xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null || true
  say "Launched $BUNDLE_ID"
fi

# --- capture ----------------------------------------------------------

shoot() {
  local name="$1"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name" >/dev/null
  # Verify rather than trust: a wrong simulator silently yields a wrong
  # size, and the compositor would be the first to notice otherwise.
  local dims
  dims="$(sips -g pixelWidth -g pixelHeight "$OUT/$name" \
          | awk '/pixel(Width|Height)/{printf "%s ", $2}')"
  set -- $dims
  if [[ "${1:-}" == "1320" && "${2:-}" == "2868" ]]; then
    say "  saved $name  ${1}x${2}"
  else
    warn "  saved $name  ${1:-?}x${2:-?}  — expected 1320x2868, wrong simulator?"
  fi
}

if [[ $# -gt 0 ]]; then
  shoot "$1"
  exit 0
fi

say ""
say "Drive the app to each screen in the Simulator, then press Enter."
say "Press s to skip one, q to stop."
say ""

for entry in "${SCREENS[@]}"; do
  name="${entry%%|*}"
  desc="${entry#*|}"
  printf '\033[36m%-24s\033[0m %s ' "$name" "$desc"
  read -r key </dev/tty
  case "$key" in
    q|Q) say "stopped"; break ;;
    s|S) warn "  skipped $name"; continue ;;
    *)   shoot "$name" ;;
  esac
done

say ""
say "Captures are in marketing/raw_ios_device/"
say "Now run:  node marketing/build/make_screenshots_ios.mjs"

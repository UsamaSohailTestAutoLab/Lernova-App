LINGOQUEST — STORE LAUNCH PACKAGE
Compiled 12 September 2026 · revision 3

--------------------------------------------------------------------------
WHAT THIS IS
--------------------------------------------------------------------------
A complete store-listing package built by running the actual LingoQuest
app on a physical Pixel 5a, visiting 38 screens, and capturing everything
from the live build. No mockups, no invented screens, no stock artwork.

There are now TWO screenshot sets, each captured at its own platform's
native geometry — not one set resized to fit the other.


--------------------------------------------------------------------------
CONTENTS
--------------------------------------------------------------------------
LingoQuest_AppStore_Screenshots_iPhone/
    10 screenshots, 1320x2868 px — for the Apple App Store.
    Captured with the device display overridden to 1320x2868 at 3x, so
    Flutter laid the UI out at 440x956 pt: iPhone 16 Pro Max geometry
    exactly. Apple's 6.9" class; App Store Connect scales these down for
    every smaller iPhone, so one set covers the family.

LingoQuest_PlayStore_Screenshots_Android/
    10 screenshots, 1320x2868 px — for Google Play.
    Captured at the phone's own 1080x2400 and composed at the same canvas
    size. Android status bar and gesture pill left intact, because that
    is correct for a Play listing.

Video/
  LingoQuest_AppStore_Preview.mp4  27.6s · 886x1920 · H.264 High 4.0 ·
                                   30 fps · AAC stereo 48 kHz.
                                   Inside Apple's 15-30s window.
  LingoQuest_Social_Preview.mp4    Short cut for social channels.
                                   NOT for App Store upload (under 15s).

Documents/
  LingoQuest_ASO_Strategy.pdf      35-page report
  LingoQuest_ASO_Strategy.docx     Editable Word version
  LingoQuest_ASO_Strategy.html     Interactive version — the keyword table
                                   is filterable. Keep keywords.json in the
                                   same folder for it to load.
  keywords.json                    318 researched keywords, raw data

Source_Captures/                   Unedited device captures behind the
                                   marketing frames, for provenance


--------------------------------------------------------------------------
THE TEN SCREENSHOTS (same story in both sets)
--------------------------------------------------------------------------
 1  Learn a language by playing      Home dashboard + Memory Match board
 2  Turn words into games            Word Bubble mid-play
 3  10 games, one vocabulary         All ten modes as a legible tile grid
 4  10 languages, separate progress  Languages screen
 5  Flip. Match. Remember.           Memory Match — colour-paired cards
 6  Right answer? Watch it pop       The confetti burst on a correct tap
 7  Answer fast. Stay afloat.        Word Survival — rising water
 8  Short lessons that stick         Multiple-choice exercise
 9  Every mistake becomes practice   Wrong answer, corrected
10  Keep the streak alive            Statistics + achievements

The two sets are genuinely different renders, not the same pixels twice.
The iPhone frames fit more on screen — Home shows a "continue the Path"
row the Android frames do not.


--------------------------------------------------------------------------
THE PREVIEW VIDEO — NINE BEATS
--------------------------------------------------------------------------
 0.0-3.2   Learn a language by playing
 3.2-6.2   Choose your quest
 6.2-9.0   Learn new words
 9.0-12.7  Then play them              (Word Bubble, live recording)
12.7-16.3  Get it right, watch it pop  (correct answer bursting, live)
16.3-20.3  Flip. Match. Remember.      (Memory Match, live recording)
20.3-23.5  Or beat the rising water    (Word Survival, live recording)
23.5-26.3  Build your streak
26.3-27.6  Start your Language Quest


--------------------------------------------------------------------------
THREE THINGS TO READ BEFORE YOU UPLOAD
--------------------------------------------------------------------------

1. HOW THE IPHONE SET WAS MADE, AND WHAT IS DRAWN.
   There is no Mac or iOS simulator in the environment where this was
   built. Rather than resize Android captures, the Android device's
   display was overridden to iPhone 16 Pro Max geometry so the app itself
   laid out at iPhone dimensions — the layout, type sizes and spacing are
   what an iPhone produces.

   Android's status bar and gesture pill were then painted out using the
   app's own background colour, and the iOS status bar (9:41), Dynamic
   Island and home indicator are DRAWN in the template. Those three are
   presentation, the same convention every App Store listing uses.
   Everything inside them is the real running app.

   If you want literally iOS-rendered pixels, re-capture the same ten
   screens on an iPhone or simulator and drop them into
   ../build/make_screenshots_ios.mjs — it takes file paths, nothing else
   changes.

2. THE APP IS ENGLISH-ONLY, AND THAT CAPS LOCALISATION.
   Verified: no lib/l10n, no supportedLocales, and every course teaches
   its language FROM English. Localising store metadata into the nine
   course languages would buy installs from people who cannot use the
   product. Section 18 of the report sets out a three-tier approach.
   Localised metadata is drafted and ready, but it is marked HOLD.

3. THE DEMO STATE IN SOME SCREENSHOTS IS SEEDED, NOT PLAYED.
   Frames showing a 24-day streak, 4860 XP and unlocked games use
   progress written directly into the app's local storage to produce a
   realistic "three weeks in" state — standard practice for store
   screenshots, disclosed here so nobody mistakes it for measured usage.
   Every UI element shown is real and reachable. All gameplay frames are
   unmodified live play.


--------------------------------------------------------------------------
THE HEADLINE RECOMMENDATION
--------------------------------------------------------------------------
Title:     LingoQuest: Language Games          (26/30)
Subtitle:  Learn Spanish, French & 8 More      (29/30)
Keywords:  vocabulary,word,game,practice,quiz,speak,listen,italian,
           german,japanese,arabic,dutch,turkish   (91/100)

Positioning: ten games and ten languages sharing one vocabulary. Of the
six major competitors checked on the live App Store, only Drops puts
"Games" in its title — and Drops has no lesson path. That gap is the
whole bet, and it is why the gameplay frame sits at screenshot #2.

TWO BLOCKERS BEFORE PAID ACQUISITION:
  - Redesign the icon. It scores 21/60; small-size readability is 3/10.
  - Close the content gap. Nine lessons per language cannot support the
    30-day streak badge the achievements screen already advertises.

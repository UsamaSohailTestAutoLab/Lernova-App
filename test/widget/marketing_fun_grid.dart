import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/theme/app_colors.dart';
import 'package:lingoquest/core/theme/app_spacing.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/features/fun/presentation/widgets/game_mode_card.dart';

/// Renders the Fun Zone grid straight out of the app's own widgets, at
/// store-screenshot resolution, for the marketing build to composite.
///
/// Not a device capture and not a mock-up: this is [GameModeCard], the
/// same class the app builds, laid out by the same Flutter engine at a
/// chosen size. It exists because a phone screen only fits four of the
/// ten cards, and the screenshot it feeds is the one that says "ten
/// games" — so the shot needs all ten in one frame, which no single
/// capture can give.
///
/// Named without the `_test` suffix so `flutter test` leaves it alone.
/// Refresh the source images with:
///
///     flutter test test/widget/marketing_fun_grid.dart --update-goldens
///
/// The state below is a plausible subscriber's: every game reachable, at
/// the mixed levels somebody a few weeks in would have. That is what the
/// screenshot is advertising, and it is a state the app really produces.
Future<void> _loadRealFonts() async {
  for (final family in const {
    'Inter': 'assets/fonts/Inter.ttf',
    'Baloo 2': 'assets/fonts/Baloo2.ttf',
  }.entries) {
    final loader = FontLoader(family.key)..addFont(rootBundle.load(family.value));
    await loader.load();
  }
}

/// Whether a colour emoji font was found and registered.
bool _emojiLoaded = false;

/// Loads a colour emoji font from the host so the game glyphs render.
///
/// The headless test renderer ships no emoji font, so every `mode.emoji`
/// comes out as a tofu box — invisible in an ordinary golden, fatal in
/// an image bound for a store listing. On a device the platform's own
/// emoji font covers this; here it has to be supplied.
///
/// Host-specific by nature, so it degrades rather than fails: if nothing
/// turns up, the render is skipped rather than writing a marketing image
/// full of empty squares.
Future<void> _loadEmojiFont() async {
  const candidates = [
    r'C:\Windows\Fonts\seguiemj.ttf',
    '/System/Library/Fonts/Apple Color Emoji.ttc',
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader('MarketingEmoji')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    _emojiLoaded = true;
    return;
  }
}

/// Levels a real account would carry after a few weeks of play.
const _levels = <FunGameMode, int>{
  FunGameMode.fallingWords: 6,
  FunGameMode.wordRush: 4,
  FunGameMode.wordMatch: 5,
  FunGameMode.memoryMatch: 3,
  FunGameMode.phraseBuilder: 2,
  FunGameMode.listenAndCatch: 3,
  FunGameMode.conversationChallenge: 2,
  FunGameMode.sentenceBuilder: 4,
  FunGameMode.meaningShooter: 2,
  FunGameMode.wordSurvival: 1,
};

Widget _grid({required double width, required int columns}) => Container(
      color: AppColors.lightBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      // Wrap rather than GridView: ten cards over three columns leaves
      // the last row two short, and a grid parks that card hard left
      // beside two holes. Wrap centres it, so the odd one out reads as
      // composition instead of an accident.
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final mode in FunGameMode.values)
            SizedBox(
              width: _cardWidth(width, columns),
              height: _cardWidth(width, columns) / 0.95,
              child: GameModeCard(
                mode: mode,
                level: _levels[mode] ?? 1,
                unlocked: true,
                onTap: () {},
              ),
            ),
        ],
      ),
    );

/// Card width for a given canvas and column count, keeping the app's own
/// gutters so the cards sit at the proportions they really have.
double _cardWidth(double width, int columns) =>
    (width - AppSpacing.lg * 2 - AppSpacing.md * (columns - 1)) / columns;

/// The poster shape: three across, all ten in one frame. Feeds the
/// store screenshot whose headline is "10 games".
const _poster = Size(640, 912);

/// Phone shape, two across, as the Fun Zone really lays out. Feeds the
/// preview video, whose frame is a phone and would letterbox the
/// poster into a stripe between two grey bars.
const _phone = Size(400, 870);

/// How much bigger the written image is than that layout.
///
/// `matchesGoldenFile` captures at logical size and ignores the view's
/// device pixel ratio, so a straight render comes out around 650px wide
/// — fine for a golden, far too soft for a 1320px store panel. Scaling
/// the laid-out grid through a [FittedBox] rasterises it at the larger
/// size, which is sharp, rather than upscaling a small bitmap, which is
/// not.
const _supersample = 3.0;

Future<void> _render(
  WidgetTester tester, {
  required String out,
  required Size layout,
  required int columns,
}) async {
  // Better no image than one bound for a store listing with a row of
  // empty squares where the game icons should be.
  if (!_emojiLoaded) {
    markTestSkipped('no colour emoji font on this host — nothing written');
    return;
  }

  tester.view.physicalSize = Size(
    layout.width * _supersample,
    layout.height * _supersample,
  );
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // The emoji font is added as a *fallback* rather than the family,
      // so Inter and Baloo still set every word of real text and only
      // the glyphs they lack fall through to it.
      theme: AppTheme.light().copyWith(
        textTheme: AppTheme.light()
            .textTheme
            .apply(fontFamilyFallback: const ['MarketingEmoji']),
      ),
      home: DefaultTextStyle.merge(
        style: const TextStyle(fontFamilyFallback: ['MarketingEmoji']),
        child: Scaffold(
          backgroundColor: AppColors.lightBg,
          // Transform.scale rather than FittedBox: a FittedBox inside a
          // Scaffold body sizes itself to the child and leaves the rest
          // of the canvas empty, which produced a store image with the
          // cards huddled in one corner.
          body: SizedBox(
            width: layout.width * _supersample,
            height: layout.height * _supersample,
            child: Transform.scale(
              scale: _supersample,
              alignment: Alignment.topLeft,
              // OverflowBox, not SizedBox: the parent hands down *tight*
              // constraints, which a SizedBox cannot shrink below — so
              // the grid laid itself out at full canvas width and the
              // transform then blew one card up to fill the frame.
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: layout.width,
                maxWidth: layout.width,
                minHeight: layout.height,
                maxHeight: layout.height,
                child: _grid(width: layout.width, columns: columns),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await expectLater(find.byType(Scaffold), matchesGoldenFile(out));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
    await _loadEmojiFont();
  });

  testWidgets('Fun grid poster, Android build', (tester) async {
    await _render(
      tester,
      out: '../../marketing/raw/fun_grid_all.png',
      layout: _poster,
      columns: 3,
    );
  });

  testWidgets('Fun Zone at phone shape, for the video', (tester) async {
    await _render(
      tester,
      out: '../../marketing/raw/fun_grid_phone.png',
      layout: _phone,
      columns: 2,
    );
  });

  testWidgets('Fun Zone at phone shape, for the iPhone video', (tester) async {
    // The iPhone video builder resolves its stills against ios_clean/,
    // so the same image is written there rather than copied by hand
    // afterwards — a copy step is exactly what left the Play screenshots
    // stale.
    await _render(
      tester,
      out: '../../marketing/ios_clean/fun_grid_phone.png',
      layout: _phone,
      columns: 2,
    );
  });

  testWidgets('Fun grid poster, iPhone build', (tester) async {
    // Same image: the cards are identical on both platforms, and the
    // two builders only differ in the frame they composite it into.
    await _render(
      tester,
      out: '../../marketing/raw_ios/fun_grid_all.png',
      layout: _poster,
      columns: 3,
    );
  });
}

// Regenerates the Android launcher icon from the original, code-drawn
// Lernova parrot mascot (see lib/core/widgets/lernova_parrot.dart) —
// no external image tooling, no image asset, nothing traced from any
// other app's icon.
//
// This is a one-off asset-generation script, not a test, but it needs a
// real Flutter rasterizer to turn the CustomPainter art into PNG bytes —
// `flutter test` is the only way to get one without standing up a full
// device build. Run it with:
//
//   flutter test tool/gen_app_icon.dart
//
// Writes two things:
//  - `ic_launcher_foreground.png` / `ic_launcher_background.png` per
//    density, used by the adaptive-icon XML (mipmap-anydpi-v26) that
//    modern launchers read.
//  - the legacy flat `ic_launcher.png` per density, for API <26.
//
// Re-run whenever the parrot artwork changes; nothing else in the app
// depends on this file.
//
// Why both: a flat square PNG alone looked right in isolation but was
// shrunk *again* when installed — the Pixel Launcher (and most others on
// Android 8+) don't trust a plain legacy icon to already be safe-zoned,
// so they wrap it as if it were an adaptive icon's foreground and inset
// it a second time, on top of whatever padding the PNG already has. The
// fix is a real adaptive icon: a transparent foreground sized to the
// official safe zone, and a separate solid background layer, so the OS
// composites and masks them itself instead of guessing.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lernova/core/theme/app_colors.dart';
import 'package:lernova/core/widgets/lernova_parrot.dart';

/// Legacy flat-icon pixel sizes per density (API <26 fallback).
const _legacyTargets = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// Adaptive-icon canvas sizes per density: Android's spec is a 108dp
/// canvas regardless of legacy icon size, at the same density scale
/// factor (mdpi=1x, hdpi=1.5x, xhdpi=2x, xxhdpi=3x, xxxhdpi=4x).
const _adaptiveTargets = {
  'mipmap-mdpi': 108,
  'mipmap-hdpi': 162,
  'mipmap-xhdpi': 216,
  'mipmap-xxhdpi': 324,
  'mipmap-xxxhdpi': 432,
};

const _legacyBaseSize = 192.0;
const _adaptiveBaseSize = 108.0;

/// Android's adaptive-icon "safe zone" is a 66dp circle centred on the
/// 108dp canvas (≈61% of the width). Padding each side by 22% leaves a
/// content box of 56% of the canvas, and — because the parrot art is
/// taller than it is wide — `BoxFit.contain` inside that square box
/// shrinks it further by width, landing comfortably inside the circle
/// with room for the wing/tail's asymmetric reach to the right.
const _safeZonePadding = _adaptiveBaseSize * 0.22;

void main() {
  testWidgets('regenerate the Android launcher icon', (tester) async {
    final legacyKey = GlobalKey();
    final foregroundKey = GlobalKey();
    final backgroundKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Legacy flat icon: background baked in, since pre-26
              // devices never mask or re-inset it.
              RepaintBoundary(
                key: legacyKey,
                child: Container(
                  width: _legacyBaseSize,
                  height: _legacyBaseSize,
                  color: AppColors.primary,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(_legacyBaseSize * 0.14),
                  child: const FittedBox(
                    child: LernovaParrot(
                      size: _legacyBaseSize,
                      mood: LernovaParrotMood.celebrate,
                    ),
                  ),
                ),
              ),
              // Adaptive foreground: transparent, parrot only, kept
              // inside the safe zone — the OS applies its own mask and
              // any launcher-specific parallax/motion on this layer.
              RepaintBoundary(
                key: foregroundKey,
                child: Container(
                  width: _adaptiveBaseSize,
                  height: _adaptiveBaseSize,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(_safeZonePadding),
                  child: const FittedBox(
                    child: LernovaParrot(
                      size: _adaptiveBaseSize,
                      mood: LernovaParrotMood.celebrate,
                    ),
                  ),
                ),
              ),
              // Adaptive background: solid fill, no content — must be
              // fully opaque and edge-to-edge since the mask crops it.
              RepaintBoundary(
                key: backgroundKey,
                child: Container(
                  width: _adaptiveBaseSize,
                  height: _adaptiveBaseSize,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final legacyBoundary =
        legacyKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final foregroundBoundary =
        foregroundKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final backgroundBoundary =
        backgroundKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    await tester.runAsync(() async {
      for (final entry in _legacyTargets.entries) {
        final pixelRatio = entry.value / _legacyBaseSize;
        final image = await legacyBoundary.toImage(pixelRatio: pixelRatio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await _write(bytes!, 'android/app/src/main/res/${entry.key}/ic_launcher.png');
      }

      for (final entry in _adaptiveTargets.entries) {
        final pixelRatio = entry.value / _adaptiveBaseSize;

        final fg = await foregroundBoundary.toImage(pixelRatio: pixelRatio);
        final fgBytes = await fg.toByteData(format: ui.ImageByteFormat.png);
        await _write(
          fgBytes!,
          'android/app/src/main/res/${entry.key}/ic_launcher_foreground.png',
        );

        final bg = await backgroundBoundary.toImage(pixelRatio: pixelRatio);
        final bgBytes = await bg.toByteData(format: ui.ImageByteFormat.png);
        await _write(
          bgBytes!,
          'android/app/src/main/res/${entry.key}/ic_launcher_background.png',
        );
      }

      // A large master, handy for a Play Store listing later — not
      // referenced by the app itself.
      final master = await legacyBoundary.toImage(pixelRatio: 1024 / _legacyBaseSize);
      final masterBytes = await master.toByteData(format: ui.ImageByteFormat.png);
      await _write(masterBytes!, 'assets/icon/app_icon_master.png');
    });
  });
}

Future<void> _write(ByteData bytes, String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  // ignore: avoid_print
  print('wrote $path (${bytes.lengthInBytes} bytes)');
}

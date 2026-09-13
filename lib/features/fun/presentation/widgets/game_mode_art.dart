import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_enums.dart';

/// The illustrated ground each Fun game card sits on.
///
/// Drawn rather than shipped. Ten painted illustrations would be ten
/// raster assets at three densities — about thirty files to keep in step
/// with the palette, re-export whenever a colour moves, and ship in the
/// APK. These are a few hundred lines of [Canvas] calls that take their
/// colours from the theme, render sharp at any card size, and cost
/// nothing to add an eleventh of.
///
/// Each motif is a loose visual metaphor for what the game *does* —
/// bubbles rising for the catching game, letter tiles streaking for the
/// timed one, cards face-down for the memory one — so the grid can be
/// read at a glance before any of the titles are.
enum GameArtMotif {
  bubbles,
  streakTiles,
  puzzle,
  faceDownCards,
  wordChips,
  soundWaves,
  speechBubbles,
  letterBlocks,
  target,
  water,
}

/// One game's ground: two colours and a motif.
///
/// [light] and [dark] are the *card* colours, not tints of one hue —
/// picked per theme so a card reads as a lit panel on the light ground
/// and a deep one on the dark, rather than the same swatch dimmed.
class GameArt {
  final Color light;
  final Color dark;
  final GameArtMotif motif;

  const GameArt({
    required this.light,
    required this.dark,
    required this.motif,
  });

  Color base(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Deliberately not in `AppColors`: these are illustration colours for
/// one screen, not brand tokens, and mixing them into the palette would
/// invite them into places they do not belong.
const Map<FunGameMode, GameArt> _art = {
  FunGameMode.fallingWords: GameArt(
    light: Color(0xFFCDE7FA),
    dark: Color(0xFF12324A),
    motif: GameArtMotif.bubbles,
  ),
  FunGameMode.wordRush: GameArt(
    light: Color(0xFFFFD98A),
    dark: Color(0xFF4A3410),
    motif: GameArtMotif.streakTiles,
  ),
  FunGameMode.wordMatch: GameArt(
    light: Color(0xFFB8E8C8),
    dark: Color(0xFF12401F),
    motif: GameArtMotif.puzzle,
  ),
  FunGameMode.memoryMatch: GameArt(
    light: Color(0xFFE6D4F5),
    dark: Color(0xFF2E1D47),
    motif: GameArtMotif.faceDownCards,
  ),
  FunGameMode.phraseBuilder: GameArt(
    light: Color(0xFFDCD9F7),
    dark: Color(0xFF221F4A),
    motif: GameArtMotif.wordChips,
  ),
  FunGameMode.listenAndCatch: GameArt(
    light: Color(0xFFBFD3F5),
    dark: Color(0xFF111C42),
    motif: GameArtMotif.soundWaves,
  ),
  FunGameMode.conversationChallenge: GameArt(
    light: Color(0xFFBDEDE8),
    dark: Color(0xFF0E3B37),
    motif: GameArtMotif.speechBubbles,
  ),
  FunGameMode.sentenceBuilder: GameArt(
    light: Color(0xFFCFDCE8),
    dark: Color(0xFF1B2C3A),
    motif: GameArtMotif.letterBlocks,
  ),
  FunGameMode.meaningShooter: GameArt(
    light: Color(0xFFFAD0CC),
    dark: Color(0xFF461818),
    motif: GameArtMotif.target,
  ),
  FunGameMode.wordSurvival: GameArt(
    light: Color(0xFFBFE6F2),
    dark: Color(0xFF0E3244),
    motif: GameArtMotif.water,
  ),
};

GameArt artFor(FunGameMode mode) =>
    _art[mode] ??
    const GameArt(
      light: Color(0xFFDCE6DC),
      dark: Color(0xFF1B2B1E),
      motif: GameArtMotif.bubbles,
    );

/// Ink that reads on a given card colour.
///
/// Computed from the ground's luminance rather than hard-coded per card,
/// which is what keeps ten different palettes legible without ten
/// hand-checked text colours — and keeps the next palette legible too.
Color inkOn(Color background) =>
    background.computeLuminance() > 0.45
        ? const Color(0xFF15221A)
        : const Color(0xFFF4F8F4);

/// The colour the motif is drawn in: a deeper, richer version of the
/// card's own hue.
///
/// Not ink at low opacity. Translucent near-black over a pale blue is
/// grey, and a grid of grey shapes on pastel grounds looks like a
/// rendering fault rather than an illustration. Staying on the ground's
/// own hue — darker and more saturated on a light card, lighter on a
/// dark one — is what makes the bubbles read as *blue* bubbles.
Color motifOn(Color ground) {
  final hsl = HSLColor.fromColor(ground);
  final light = ground.computeLuminance() > 0.45;
  return hsl
      .withLightness(
        (light ? hsl.lightness * 0.58 : hsl.lightness * 1.9 + 0.12)
            .clamp(0.0, 1.0),
      )
      .withSaturation((hsl.saturation * 1.35).clamp(0.0, 1.0))
      .toColor();
}

/// The painted ground for one card.
///
/// The motif is drawn low and to the right, and a scrim runs from the
/// top down to roughly the middle. Both exist for the same reason: the
/// title and the lock line have to stay readable, and artwork running
/// under text is the single fastest way to make a beautiful grid
/// unusable.
class GameModeArtwork extends StatelessWidget {
  final FunGameMode mode;

  /// Dimmed for a card that is locked behind a Fun *level*, which the
  /// learner unlocks by playing. A Pro-locked card keeps its full
  /// colour: it is an offer, and showing it drained is a poor advert for
  /// the thing being sold.
  final bool muted;

  const GameModeArtwork({super.key, required this.mode, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final art = artFor(mode);
    final ground = art.base(brightness);
    final ink = inkOn(ground);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _GameArtPainter(
          motif: art.motif,
          ground: ground,
          ink: ink,
          tone: motifOn(ground),
          muted: muted,
        ),
        // The painter fills whatever the card gives it.
        size: Size.infinite,
      ),
    );
  }
}

class _GameArtPainter extends CustomPainter {
  final GameArtMotif motif;
  final Color ground;
  final Color ink;

  /// The motif's own colour — see [motifOn].
  final Color tone;

  final bool muted;

  _GameArtPainter({
    required this.motif,
    required this.ground,
    required this.ink,
    required this.tone,
    required this.muted,
  });

  /// How strongly the motif sits against its ground.
  ///
  /// Low on purpose. These are grounds, not pictures: turn them up and
  /// the card competes with its own label.
  double get _strength => muted ? 0.14 : 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // A soft vertical lift, so a card is never a flat rectangle of
    // colour: lighter at the top where the title sits, deeper at the
    // bottom where the art is.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(ground, ink, 0.04)!,
            Color.lerp(ground, ink, 0.16)!,
          ],
        ).createShader(Offset.zero & size),
    );

    final paint = Paint()..color = tone.withValues(alpha: _strength);
    final line = Paint()
      ..color = tone.withValues(alpha: (_strength * 1.5).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    switch (motif) {
      case GameArtMotif.bubbles:
        _bubbles(canvas, size, paint, line);
      case GameArtMotif.streakTiles:
        _streakTiles(canvas, size, paint, line);
      case GameArtMotif.puzzle:
        _puzzle(canvas, size, paint);
      case GameArtMotif.faceDownCards:
        _faceDownCards(canvas, size, paint, line);
      case GameArtMotif.wordChips:
        _wordChips(canvas, size, paint, line);
      case GameArtMotif.soundWaves:
        _soundWaves(canvas, size, line);
      case GameArtMotif.speechBubbles:
        _speechBubbles(canvas, size, paint, line);
      case GameArtMotif.letterBlocks:
        _letterBlocks(canvas, size, paint, line);
      case GameArtMotif.target:
        _target(canvas, size, line);
      case GameArtMotif.water:
        _water(canvas, size, paint);
    }

    // The scrim. Opaque ground at the top, clear by the middle, so the
    // title and the lock line always sit on plain colour however busy
    // the motif under them is.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ground, ground.withValues(alpha: 0.0)],
          stops: const [0.30, 0.62],
        ).createShader(Offset.zero & size),
    );

    canvas.restore();
  }

  // ---------------------------------------------------------------- motifs

  /// Rising bubbles, for the game where meanings float up and away.
  void _bubbles(Canvas canvas, Size size, Paint fill, Paint stroke) {
    const circles = [
      (0.24, 0.92, 0.20),
      (0.62, 0.78, 0.30),
      (0.86, 0.98, 0.16),
      (0.44, 0.62, 0.11),
      (0.15, 0.70, 0.09),
      (0.78, 0.56, 0.07),
    ];
    for (final (cx, cy, r) in circles) {
      final centre = Offset(cx * size.width, cy * size.height);
      final radius = r * size.width;
      canvas.drawCircle(centre, radius, fill);
      canvas.drawCircle(centre, radius, stroke);
      // A highlight, so they read as bubbles rather than dots.
      canvas.drawCircle(
        centre.translate(-radius * 0.32, -radius * 0.34),
        radius * 0.16,
        Paint()..color = tone.withValues(alpha: (_strength * 1.5).clamp(0.0, 1.0)),
      );
    }
  }

  /// Letter tiles streaking past, for the timed game.
  void _streakTiles(Canvas canvas, Size size, Paint fill, Paint stroke) {
    // Speed lines first, so the tiles sit on top of them.
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.58 + i * 0.105);
      canvas.drawLine(
        Offset(size.width * 0.04, y),
        Offset(size.width * (0.5 + i * 0.14), y),
        Paint()
          ..color = tone.withValues(alpha: _strength * 0.55)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    const tiles = [(0.42, 0.86), (0.63, 0.74), (0.84, 0.90)];
    final side = size.width * 0.20;
    for (final (cx, cy) in tiles) {
      final rect = Rect.fromCenter(
        center: Offset(cx * size.width, cy * size.height),
        width: side,
        height: side,
      );
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(side * 0.22));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
    }
  }

  /// Interlocking pieces, for the pairing game.
  void _puzzle(Canvas canvas, Size size, Paint fill) {
    const pieces = [(0.30, 0.84, 0.0), (0.66, 0.72, 0.6), (0.88, 0.95, -0.4)];
    for (final (cx, cy, rot) in pieces) {
      canvas.save();
      canvas.translate(cx * size.width, cy * size.height);
      canvas.rotate(rot);
      final s = size.width * 0.22;
      final path = Path()
        ..moveTo(-s / 2, -s / 2)
        ..lineTo(0, -s / 2)
        // The tab on the top edge.
        ..cubicTo(-s * 0.12, -s * 0.76, s * 0.32, -s * 0.76, s * 0.14, -s / 2)
        ..lineTo(s / 2, -s / 2)
        ..lineTo(s / 2, 0)
        // And the one on the right.
        ..cubicTo(s * 0.76, -s * 0.12, s * 0.76, s * 0.32, s / 2, s * 0.14)
        ..lineTo(s / 2, s / 2)
        ..lineTo(-s / 2, s / 2)
        ..close();
      canvas.drawPath(path, fill);
      canvas.restore();
    }
  }

  /// A fanned deck, face down, for the memory game.
  void _faceDownCards(Canvas canvas, Size size, Paint fill, Paint stroke) {
    const cards = [(0.30, 0.88, -0.22), (0.58, 0.82, 0.02), (0.85, 0.90, 0.26)];
    final w = size.width * 0.23;
    final h = w * 1.42;
    for (final (cx, cy, rot) in cards) {
      canvas.save();
      canvas.translate(cx * size.width, cy * size.height);
      canvas.rotate(rot);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Radius.circular(w * 0.18),
      );
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
      // A four-pointed star on the back of each.
      _star(canvas, Offset.zero, w * 0.22, stroke..style = PaintingStyle.fill);
      stroke.style = PaintingStyle.stroke;
      canvas.restore();
    }
  }

  void _star(Canvas canvas, Offset centre, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? r : r * 0.38;
      final angle = i * math.pi / 4 - math.pi / 2;
      final p = centre +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  /// Word chips slotting together, for the phrase game.
  void _wordChips(Canvas canvas, Size size, Paint fill, Paint stroke) {
    const chips = [
      (0.30, 0.72, 0.34),
      (0.70, 0.80, 0.44),
      (0.26, 0.92, 0.40),
      (0.72, 0.98, 0.32),
    ];
    for (final (cx, cy, w) in chips) {
      final rect = Rect.fromCenter(
        center: Offset(cx * size.width, cy * size.height),
        width: w * size.width,
        height: size.height * 0.11,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.height / 2),
      );
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
    }
  }

  /// A waveform, for the listening game.
  void _soundWaves(Canvas canvas, Size size, Paint stroke) {
    final baseline = size.height * 0.84;
    final bars = (size.width / (size.width * 0.085)).floor();
    for (var i = 0; i < bars; i++) {
      final t = i / (bars - 1);
      // A shaped envelope rather than random heights, so it reads as one
      // sound rather than a bar chart.
      final amp = (math.sin(t * math.pi * 2.4) * 0.5 + 0.5) *
          (0.35 + 0.65 * math.sin(t * math.pi));
      final h = size.height * 0.30 * amp + 4;
      final x = size.width * (0.06 + t * 0.88);
      canvas.drawLine(
        Offset(x, baseline - h),
        Offset(x, baseline + h),
        stroke,
      );
    }
  }

  /// Two bubbles in conversation.
  void _speechBubbles(Canvas canvas, Size size, Paint fill, Paint stroke) {
    void bubble(Rect rect, {required bool tailLeft}) {
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(rect.height * 0.34));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
      final tailX = tailLeft ? rect.left + rect.width * 0.22 : rect.right - rect.width * 0.22;
      final path = Path()
        ..moveTo(tailX, rect.bottom - 1)
        ..lineTo(tailX + (tailLeft ? -10 : 10), rect.bottom + 12)
        ..lineTo(tailX + (tailLeft ? 10 : -10), rect.bottom - 1)
        ..close();
      canvas.drawPath(path, fill);
    }

    bubble(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.60,
        size.width * 0.50,
        size.height * 0.16,
      ),
      tailLeft: true,
    );
    bubble(
      Rect.fromLTWH(
        size.width * 0.36,
        size.height * 0.84,
        size.width * 0.56,
        size.height * 0.16,
      ),
      tailLeft: false,
    );
  }

  /// Stacked blocks, for the ordering game.
  void _letterBlocks(Canvas canvas, Size size, Paint fill, Paint stroke) {
    const blocks = [
      (0.22, 0.90),
      (0.50, 0.90),
      (0.78, 0.90),
      (0.36, 0.68),
      (0.64, 0.68),
    ];
    final side = size.width * 0.21;
    for (final (cx, cy) in blocks) {
      final rect = Rect.fromCenter(
        center: Offset(cx * size.width, cy * size.height),
        width: side,
        height: side,
      );
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(side * 0.20));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
      // A rule across each, standing in for the letter without needing
      // to lay out real text in a background.
      canvas.drawLine(
        rect.center.translate(-side * 0.18, side * 0.14),
        rect.center.translate(side * 0.18, side * 0.14),
        stroke,
      );
    }
  }

  /// Concentric rings, for the game about hitting the right meaning.
  void _target(Canvas canvas, Size size, Paint stroke) {
    final centre = Offset(size.width * 0.72, size.height * 0.86);
    final outer = size.width * 0.34;
    for (var i = 4; i >= 1; i--) {
      canvas.drawCircle(centre, outer * i / 4, stroke);
    }
    canvas.drawCircle(
      centre,
      outer * 0.14,
      Paint()..color = tone.withValues(alpha: (_strength * 1.5).clamp(0.0, 1.0)),
    );
  }

  /// Rising water, for the survival game.
  void _water(Canvas canvas, Size size, Paint fill) {
    for (var layer = 0; layer < 3; layer++) {
      final top = size.height * (0.62 + layer * 0.13);
      final amplitude = size.height * 0.035;
      final path = Path()..moveTo(0, top);
      const steps = 14;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final y = top +
            math.sin(i / steps * math.pi * 2 + layer * 1.1) * amplitude;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = tone.withValues(alpha: (_strength * (0.45 + layer * 0.24)).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_GameArtPainter old) =>
      old.motif != motif ||
      old.ground != ground ||
      old.ink != ink ||
      old.tone != tone ||
      old.muted != muted;
}

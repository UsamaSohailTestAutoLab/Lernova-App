import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

enum LingoQuestParrotMood {
  /// Resting smile, eyes open.
  happy,

  /// Eyes squeezed shut in a grin, crest raised.
  celebrate,

  /// Head tilted, one eye slightly narrowed.
  curious,

  /// Both eyes drooping, crest lowered — out of hearts, a miss.
  sad,

  /// Book under one wing, pointer raised — about to explain something.
  /// For the moments just *before* the learning rather than after it:
  /// a lesson intro, a word preview.
  teaching,
}

/// LingoQuest's mascot: a round, friendly parrot.
///
/// A parrot because the bird that *repeats what it hears* is the obvious
/// companion for a language app — and because its silhouette is
/// unmistakably its own: a three-feather crest, a large hooked amber
/// beak, a swept tail and a single folded wing.
///
/// Artwork resolves in three steps, each falling through to the next:
/// the pose for this [mood] (or [heroAsset] under a wordmark), then
/// [artworkAsset], then the custom-painted parrot below.
///
/// That chain is the point. Every screen draws its mascot through this
/// one widget, so supplying only the base file has to be enough to
/// dress the whole app, adding a pose file has to be all it takes to
/// specialise one mood, and supplying none has to degrade to the
/// painted character rather than to a broken-image box seventeen times
/// over.
class LingoQuestParrot extends StatefulWidget {
  final double size;
  final LingoQuestParrotMood mood;

  /// A slow idle bob. Off by default: on a screen the learner sits on,
  /// a permanent loop repaints forever for no gain.
  final bool animate;

  /// Draws the "LingoQuest" wordmark underneath, matching the brand style
  /// used everywhere else the name appears standalone (Welcome,
  /// Settings).
  final bool showWordmark;

  /// The mascot artwork every screen falls back to. Drop a
  /// transparent-background PNG here and the whole app picks it up;
  /// delete it and the painted parrot returns.
  static const artworkAsset = 'assets/images/lingoquest_parrot.png';

  /// Optional per-pose artwork. Each is used only where its mood is
  /// asked for, and each falls back to [artworkAsset] on its own, so
  /// they can be added one at a time rather than all or nothing.
  static const celebrateAsset =
      'assets/images/lingoquest_parrot_celebrate.png';
  static const curiousAsset = 'assets/images/lingoquest_parrot_curious.png';
  static const sadAsset = 'assets/images/lingoquest_parrot_sad.png';
  static const teachingAsset = 'assets/images/lingoquest_parrot_teaching.png';

  /// Shown with the wordmark, where the mascot is standing in for the
  /// brand rather than reacting to something.
  static const heroAsset = 'assets/images/lingoquest_parrot_hero.png';

  /// The pose this instance asks for before any fallback applies.
  String get poseAsset {
    if (showWordmark) return heroAsset;
    return switch (mood) {
      LingoQuestParrotMood.celebrate => celebrateAsset,
      LingoQuestParrotMood.curious => curiousAsset,
      LingoQuestParrotMood.sad => sadAsset,
      LingoQuestParrotMood.teaching => teachingAsset,
      LingoQuestParrotMood.happy => artworkAsset,
    };
  }

  /// Height as a multiple of [size], per pose.
  ///
  /// The poses are not all the same shape — the celebrating one has its
  /// wings spread and is wider than it is tall, while the rest are
  /// upright. A single box shape would letterbox that pose inside it and
  /// render it visibly smaller than every other mood on the same screen.
  /// So [size] means width, and the box takes the pose's own proportions.
  double get poseAspect {
    if (showWordmark) return 1.24;
    return switch (mood) {
      LingoQuestParrotMood.celebrate => 0.79,
      LingoQuestParrotMood.curious => 1.05,
      LingoQuestParrotMood.sad => 1.19,
      LingoQuestParrotMood.teaching => 1.19,
      LingoQuestParrotMood.happy => 1.23,
    };
  }

  const LingoQuestParrot({
    super.key,
    this.size = 96,
    this.mood = LingoQuestParrotMood.happy,
    this.animate = false,
    this.showWordmark = false,
  });

  @override
  State<LingoQuestParrot> createState() => _LingoQuestParrotState();
}

class _LingoQuestParrotState extends State<LingoQuestParrot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool _ambientChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ambientChecked) {
      _ambientChecked = true;
      if (widget.animate && AppMotion.ambientEnabled(context)) {
        _bob.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  /// Pose, then base, then paint. Written as nested [Image.asset]
  /// error builders rather than an existence check because there is no
  /// synchronous way to ask whether an asset is bundled — the load
  /// failing *is* the check, and it costs nothing once resolved.
  Widget _artwork() {
    // Every call site scales one large source down to between 48 and
    // 130 logical pixels, which is exactly where nearest-neighbour
    // sampling shows.
    const quality = FilterQuality.medium;
    final pose = widget.poseAsset;

    Widget painted() => CustomPaint(painter: _ParrotPainter(mood: widget.mood));

    Widget base() => Image.asset(
          LingoQuestParrot.artworkAsset,
          fit: BoxFit.contain,
          filterQuality: quality,
          errorBuilder: (context, error, stackTrace) => painted(),
        );

    if (pose == LingoQuestParrot.artworkAsset) return base();

    return Image.asset(
      pose,
      fit: BoxFit.contain,
      filterQuality: quality,
      errorBuilder: (context, error, stackTrace) => base(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final art = SizedBox(
      width: widget.size,
      height: widget.size * widget.poseAspect,
      child: _artwork(),
    );

    final symbol = widget.animate
        ? AnimatedBuilder(
            animation: _bob,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -widget.size * 0.045 * _bob.value),
              child: child,
            ),
            child: art,
          )
        // A one-shot settle on first build: lively without leaving a
        // ticker running behind the whole screen.
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Transform.scale(
              scale: 0.82 + 0.18 * t.clamp(0.0, 1.0),
              child: child,
            ),
            child: art,
          );

    if (!widget.showWordmark) return symbol;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        symbol,
        SizedBox(height: widget.size * 0.12),
        Text(
          'LingoQuest',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
  }
}

class _ParrotPainter extends CustomPainter {
  final LingoQuestParrotMood mood;
  _ParrotPainter({required this.mood});

  static const _ink = Color(0xFF14320F);
  static const _cream = Color(0xFFFFF6E4);
  static const _creamShade = Color(0xFFF3E7C9);
  static const _beakLight = Color(0xFFFFC24D);
  static const _beakDark = Color(0xFFE08A12);
  static const _irisRing = Color(0xFF2E5C1F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _groundShadow(canvas, w, h);
    _tail(canvas, w, h);
    _body(canvas, w, h);
    _feet(canvas, w, h);
    _wing(canvas, w, h);
    _crest(canvas, w, h);
    _head(canvas, w, h);
    _face(canvas, w, h);
  }

  /// A soft footprint built from stacked, fading ovals rather than a
  /// blurred one — cheap to paint and keeps a crisp look at small sizes.
  void _groundShadow(Canvas canvas, double w, double h) {
    for (final step in [(1.0, 0.05), (0.85, 0.08), (0.68, 0.12)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.975),
          width: w * 0.62 * step.$1,
          height: h * 0.05 * step.$1,
        ),
        Paint()..color = AppColors.primaryDark.withValues(alpha: step.$2),
      );
    }
  }

  /// Swept tail feathers behind the body — the long, pointed tail is a
  /// big part of reading as "parrot" rather than any round bird.
  void _tail(Canvas canvas, double w, double h) {
    final tailRect = Rect.fromLTWH(w * 0.58, h * 0.70, w * 0.42, h * 0.30);
    final tail = Path()
      ..moveTo(w * 0.60, h * 0.72)
      ..lineTo(w * 0.99, h * 0.90)
      ..lineTo(w * 0.93, h * 0.95)
      ..lineTo(w * 0.62, h * 0.86)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green600, AppColors.green800],
        ).createShader(tailRect),
    );

    final under = Path()
      ..moveTo(w * 0.60, h * 0.78)
      ..lineTo(w * 0.93, h * 0.96)
      ..lineTo(w * 0.84, h * 0.98)
      ..lineTo(w * 0.60, h * 0.88)
      ..close();
    canvas.drawPath(under, Paint()..color = AppColors.green600);

    // A thin bright edge along the top of the tail sells the glossy,
    // lacquered-feather look the rest of the body has.
    canvas.drawLine(
      Offset(w * 0.615, h * 0.735),
      Offset(w * 0.965, h * 0.905),
      Paint()
        ..color = AppColors.green400.withValues(alpha: 0.7)
        ..strokeWidth = w * 0.012
        ..strokeCap = StrokeCap.round,
    );
  }

  void _body(Canvas canvas, double w, double h) {
    final body = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.705),
      width: w * 0.68,
      height: h * 0.50,
    );
    // Light source top-left: a radial gradient reads as a glossy, lit
    // sphere far better than the flat linear wash a small icon gets
    // squashed into.
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.05,
          colors: const [AppColors.green300, AppColors.primary, AppColors.green800],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(body),
    );

    // Pale chest patch, itself lightly shaded so it doesn't read as a
    // flat sticker dropped on top.
    final chest = Rect.fromCenter(
      center: Offset(w * 0.47, h * 0.755),
      width: w * 0.40,
      height: h * 0.33,
    );
    canvas.drawOval(
      chest,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.1,
          colors: [Colors.white, _cream, _creamShade],
        ).createShader(chest),
    );

    // Soft contact shadow where the head overlaps the body, and where
    // the wing meets it — the single depth cue a flat fill can't give.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.475), width: w * 0.56, height: h * 0.09),
      Paint()..color = AppColors.green800.withValues(alpha: 0.16),
    );

    // A slim rim-light along the top-left silhouette edge.
    canvas.drawArc(
      body.inflate(-w * 0.01),
      math.pi * 1.08,
      math.pi * 0.62,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..strokeCap = StrokeCap.round,
    );
  }

  void _feet(Canvas canvas, double w, double h) {
    for (final dx in [0.40, 0.58]) {
      final foot = Rect.fromCenter(
        center: Offset(w * dx, h * 0.945),
        width: w * 0.15,
        height: h * 0.045,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(foot, Radius.circular(w * 0.03)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_beakLight, AppColors.accent],
          ).createShader(foot),
      );
    }
  }

  /// One folded wing, leaf-shaped, with two feather lines scored into it.
  void _wing(Canvas canvas, double w, double h) {
    final wing = Path()
      ..moveTo(w * 0.72, h * 0.56)
      ..quadraticBezierTo(w * 0.90, h * 0.68, w * 0.74, h * 0.86)
      ..quadraticBezierTo(w * 0.66, h * 0.72, w * 0.72, h * 0.56)
      ..close();
    final wingRect = wing.getBounds();
    canvas.drawPath(
      wing,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green400, AppColors.green600],
        ).createShader(wingRect),
    );

    canvas.drawLine(
      Offset(w * 0.735, h * 0.585),
      Offset(w * 0.865, h * 0.665),
      Paint()
        ..color = AppColors.green300.withValues(alpha: 0.65)
        ..strokeWidth = w * 0.012
        ..strokeCap = StrokeCap.round,
    );

    final line = Paint()
      ..color = AppColors.green800.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.735, h * 0.66), Offset(w * 0.80, h * 0.72), line);
    canvas.drawLine(Offset(w * 0.730, h * 0.74), Offset(w * 0.785, h * 0.79), line);
  }

  /// Three amber crest feathers. The most distinctive part of the
  /// silhouette — raised higher when celebrating, drooped when sad.
  void _crest(Canvas canvas, double w, double h) {
    final raised = mood == LingoQuestParrotMood.celebrate;
    final drooped = mood == LingoQuestParrotMood.sad;
    final length = w * (raised ? 0.32 : (drooped ? 0.20 : 0.25));
    final origin = Offset(w * 0.50, h * 0.145);

    const angles = [-0.62, -0.03, 0.56];
    for (var i = 0; i < angles.length; i++) {
      final isMiddle = i == 1;
      final feather = Rect.fromCenter(
        center: Offset(0, -length * 0.52),
        width: w * 0.105,
        height: length * (isMiddle ? 1.12 : 0.94),
      );
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angles[i]);
      canvas.drawOval(
        feather,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isMiddle
                ? const [_beakLight, AppColors.accent]
                : const [AppColors.accent, _beakDark],
          ).createShader(feather),
      );
      // A thin bright streak down each feather's centre for gloss.
      canvas.drawLine(
        Offset(0, -length * 0.92),
        Offset(0, -length * 0.18),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = w * 0.015
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  void _head(Canvas canvas, double w, double h) {
    final head = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.335),
      width: w * 0.68,
      height: h * 0.42,
    );
    canvas.drawOval(
      head,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.6),
          radius: 1.05,
          colors: const [AppColors.green300, AppColors.green400, AppColors.green600],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(head),
    );

    // Cream face mask around the eyes and beak — the cheek patch real
    // parrots wear, and what keeps the eyes readable at small sizes.
    final mask = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.365),
      width: w * 0.52,
      height: h * 0.30,
    );
    canvas.drawOval(
      mask,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.15,
          colors: const [Colors.white, _cream],
        ).createShader(mask),
    );
  }

  void _face(Canvas canvas, double w, double h) {
    final leftEye = Offset(w * 0.375, h * 0.315);
    final rightEye = Offset(w * 0.625, h * 0.315);

    switch (mood) {
      case LingoQuestParrotMood.celebrate:
        _happyArc(canvas, leftEye, w);
        _happyArc(canvas, rightEye, w);
      case LingoQuestParrotMood.curious:
        _eye(canvas, leftEye, w, openness: 1);
        _eye(canvas, rightEye, w, openness: 0.55);
      // The painted fallback has no book to hold, so teaching is drawn
      // attentive and wide-eyed, the same as happy.
      case LingoQuestParrotMood.teaching:
      case LingoQuestParrotMood.happy:
        _eye(canvas, leftEye, w, openness: 1);
        _eye(canvas, rightEye, w, openness: 1);
      case LingoQuestParrotMood.sad:
        _eye(canvas, leftEye, w, openness: 0.7);
        _eye(canvas, rightEye, w, openness: 0.7);
    }

    // Blush is skipped when sad — a flushed, cheerful cheek reads wrong
    // next to a droop, and the mood needs to be unambiguous at a glance.
    if (mood != LingoQuestParrotMood.sad) {
      _blush(canvas, Offset(w * 0.255, h * 0.405), w);
      _blush(canvas, Offset(w * 0.745, h * 0.405), w);
    }
    _beak(canvas, w, h);
  }

  /// Big, glossy and slightly recessed — a soft shadow ring behind the
  /// white sets the eye into the face instead of floating on top of it,
  /// and the double catchlight is what makes it read as "glassy" rather
  /// than a flat white disc with a dot.
  void _eye(Canvas canvas, Offset center, double w, {required double openness}) {
    final r = w * 0.076;

    canvas.drawCircle(
      center.translate(0, r * 0.12),
      r * 1.14,
      Paint()..color = _ink.withValues(alpha: 0.10),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);

    // A slim iris ring gives the pupil a real edge instead of a hard cut
    // straight from white to black.
    canvas.drawCircle(center, r * 0.66, Paint()..color = _irisRing);
    canvas.drawCircle(center, r * 0.58, Paint()..color = _ink);

    // Primary catchlight (bigger, upper-left) plus a small secondary one
    // opposite it — the pairing is what sells "glossy glass" rather than
    // one flat dot.
    canvas.drawCircle(
      center.translate(-r * 0.24, -r * 0.28),
      r * 0.26,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      center.translate(r * 0.30, r * 0.20),
      r * 0.11,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );

    // A lid dropping over the top for a narrowed eye.
    if (openness < 1) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 1.05),
        math.pi,
        math.pi * (1 - openness),
        true,
        Paint()..color = _cream,
      );
    }
  }

  void _happyArc(Canvas canvas, Offset center, double w) {
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(0, w * 0.014), radius: w * 0.068),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.030
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Layered, fading ovals rather than one flat wash — a cheap stand-in
  /// for a soft airbrushed blush.
  void _blush(Canvas canvas, Offset center, double w) {
    const blush = Color(0xFFFF9B8A);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 0.16, height: w * 0.10),
      Paint()..color = blush.withValues(alpha: 0.28),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 0.11, height: w * 0.07),
      Paint()..color = blush.withValues(alpha: 0.42),
    );
  }

  /// The hooked mandible: wide at the top, curving to a point that
  /// overhangs the lower jaw. Nothing like a small triangular beak.
  void _beak(Canvas canvas, double w, double h) {
    final upper = Path()
      ..moveTo(w * 0.425, h * 0.395)
      ..quadraticBezierTo(w * 0.50, h * 0.345, w * 0.575, h * 0.395)
      ..quadraticBezierTo(w * 0.585, h * 0.480, w * 0.500, h * 0.520)
      ..quadraticBezierTo(w * 0.415, h * 0.480, w * 0.425, h * 0.395)
      ..close();
    final upperRect = upper.getBounds();
    canvas.drawPath(
      upper,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_beakLight, AppColors.accent],
        ).createShader(upperRect),
    );

    // Lower jaw peeking out under the hook.
    final lower = Path()
      ..moveTo(w * 0.455, h * 0.455)
      ..quadraticBezierTo(w * 0.500, h * 0.500, w * 0.545, h * 0.455)
      ..quadraticBezierTo(w * 0.500, h * 0.478, w * 0.455, h * 0.455)
      ..close();
    canvas.drawPath(lower, Paint()..color = _beakDark);

    // A small gloss ellipse near the top of the hook, plus the nostril.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.463, h * 0.375), width: w * 0.03, height: h * 0.02),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(w * 0.468, h * 0.392),
      w * 0.016,
      Paint()..color = _beakDark.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _ParrotPainter oldDelegate) =>
      oldDelegate.mood != mood;
}

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_story.dart';
import 'game_theme.dart';

// ─── scenery ────────────────────────────────────────────────────────────────
//
// Scenery is static per (theme, chapter, size): callers record it once into a
// Picture (Flame) or a RepaintBoundary (widgets) and never repaint it per
// frame. Detail grows with the chapter: more stars, nebulae, planets and, at
// chapter 5, the deep-space core (or the moonlit castle at Easter).

/// Evenly spaced stops: dart:ui gradients require them for 3+ colours.
List<double>? evenStops(List<Color> colors) => colors.length <= 2
    ? null
    : [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)];

/// Sky, far objects and static stars. Moving stars (Flame) go on top of this.
void paintStorySky(
    Canvas canvas, Size size, GameVisualTheme theme, GameStoryChapter chapter) {
  final stage = GameStory.stage(theme, chapter);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
          Offset.zero, Offset(0, size.height), [stage.skyTop, stage.skyBottom]),
  );
  final random = Random(31 * chapter.level + theme.index);
  if (theme == GameVisualTheme.space || chapter == GameStoryChapter.five) {
    _stars(canvas, size, random,
        count: 50 + 35 * chapter.index, colored: chapter.index >= 2);
  }
  if (theme == GameVisualTheme.space) {
    _spaceFar(canvas, size, chapter, stage, random);
  } else {
    _easterFar(canvas, size, chapter, stage, random);
  }
}

/// Foreground landscape below [groundY] (a 0..1 fraction of the height).
void paintStoryGround(
    Canvas canvas, Size size, GameVisualTheme theme, GameStoryChapter chapter,
    {double groundY = 0.88}) {
  final stage = GameStory.stage(theme, chapter);
  final top = size.height * groundY;
  final random = Random(97 * chapter.level + theme.index);
  if (theme == GameVisualTheme.space) {
    _spaceGround(canvas, size, chapter, stage, top, random);
  } else {
    _easterGround(canvas, size, chapter, stage, top, random);
  }
}

void _stars(Canvas canvas, Size size, Random random,
    {required int count, required bool colored}) {
  final paint = Paint();
  const tints = [
    Color(0xFFFFFFFF),
    Color(0xFFBFDBFE),
    Color(0xFFFDE68A),
    Color(0xFFF0ABFC)
  ];
  for (var i = 0; i < count; i++) {
    final at = Offset(random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.85);
    final r = 0.5 + random.nextDouble() * (i % 17 == 0 ? 2.2 : 1.1);
    final tint = colored ? tints[i % tints.length] : tints[0];
    paint.color = tint.withValues(alpha: 0.25 + random.nextDouble() * 0.65);
    canvas.drawCircle(at, r, paint);
    if (r > 1.8) {
      // A few bright stars get a cross flare.
      paint.color = tint.withValues(alpha: 0.35);
      canvas.drawRect(
          Rect.fromCenter(center: at, width: r * 7, height: 0.8), paint);
      canvas.drawRect(
          Rect.fromCenter(center: at, width: 0.8, height: r * 7), paint);
    }
  }
}

void _glowBlob(
    Canvas canvas, Offset center, double radius, Color color, double alpha) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(center, radius, [
        color.withValues(alpha: alpha),
        color.withValues(alpha: 0),
      ]),
  );
}

void _planet(Canvas canvas, Offset c, double r, List<Color> colors,
    {Color? atmosphere}) {
  if (atmosphere != null) _glowBlob(canvas, c, r * 1.35, atmosphere, 0.45);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
          c - Offset(r * 0.35, r * 0.35), r * 1.4, colors, evenStops(colors)),
  );
  // Night side shading.
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.linear(c - Offset(r, 0), c + Offset(r, 0), [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.55),
      ]),
  );
}

void _spaceFar(Canvas canvas, Size size, GameStoryChapter chapter,
    StoryStage stage, Random random) {
  final w = size.width, h = size.height;
  switch (chapter) {
    case GameStoryChapter.one:
      _glowBlob(canvas, Offset(w * 0.8, h * 0.18), w * 0.25,
          const Color(0xFF3B82F6), 0.12);
      _planet(canvas, Offset(w * 0.82, h * 0.16), w * 0.035,
          const [Color(0xFFFFF7D6), Color(0xFFFFC857)],
          atmosphere: const Color(0xFFFFC857));
    case GameStoryChapter.two:
      _planet(canvas, Offset(w * 0.2, h * 0.17), w * 0.09,
          const [Color(0xFF93C5FD), Color(0xFF2563EB), Color(0xFF1E3A8A)],
          atmosphere: const Color(0xFF60A5FA));
      _glowBlob(canvas, Offset(w * 0.75, h * 0.35), w * 0.3,
          const Color(0xFF6366F1), 0.1);
    case GameStoryChapter.three:
      _glowBlob(canvas, Offset(w * 0.3, h * 0.3), w * 0.45,
          const Color(0xFFB91C1C), 0.16);
      _glowBlob(canvas, Offset(w * 0.85, h * 0.12), w * 0.3,
          const Color(0xFFF472B6), 0.12);
      _planet(canvas, Offset(w * 0.78, h * 0.2), w * 0.03,
          const [Color(0xFFE7E5E4), Color(0xFF78716C)]);
      _planet(canvas, Offset(w * 0.15, h * 0.1), w * 0.018,
          const [Color(0xFFD6D3D1), Color(0xFF57534E)]);
    case GameStoryChapter.four:
      for (final (x, y, r, c) in [
        (0.2, 0.25, 0.45, const Color(0xFF7C3AED)),
        (0.8, 0.4, 0.4, const Color(0xFF0891B2)),
      ]) {
        _glowBlob(canvas, Offset(w * x, h * y), w * r, c, 0.16);
      }
      _saturn(canvas, Offset(w * 0.68, h * 0.24), w * 0.12);
      // Asteroid belt.
      final rock = Paint();
      for (var i = 0; i < 40; i++) {
        final x = random.nextDouble() * w;
        final y = h * 0.45 +
            sin(x / w * pi * 2) * h * 0.04 +
            random.nextDouble() * h * 0.05;
        rock.color = Color.lerp(const Color(0xFF6B7280),
                const Color(0xFFD4A373), random.nextDouble())!
            .withValues(alpha: 0.7);
        canvas.drawCircle(Offset(x, y), 0.8 + random.nextDouble() * 2.2, rock);
      }
    case GameStoryChapter.five:
      for (final (x, y, r, c) in [
        (0.25, 0.2, 0.5, const Color(0xFF7C3AED)),
        (0.75, 0.15, 0.4, const Color(0xFFDB2777)),
        (0.55, 0.5, 0.55, const Color(0xFF0E7490)),
        (0.1, 0.55, 0.35, const Color(0xFF4338CA)),
      ]) {
        _glowBlob(canvas, Offset(w * x, h * y), w * r, c, 0.22);
      }
      _galaxy(canvas, Offset(w * 0.5, h * 0.3), w * 0.32, random);
      _blackHole(canvas, Offset(w * 0.18, h * 0.14), w * 0.05);
  }
}

void _saturn(Canvas canvas, Offset c, double r) {
  final ring = Rect.fromCenter(center: c, width: r * 4.2, height: r * 1.1);
  final ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.22
    ..shader = ui.Gradient.linear(ring.centerLeft, ring.centerRight, const [
      Color(0x00D4A373),
      Color(0xCCF5DEB3),
      Color(0xCCD4A373),
      Color(0x00D4A373),
    ], const [
      0,
      0.3,
      0.7,
      1
    ]);
  // Back half of the ring, planet, then front half.
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(ring.left, ring.top - r, ring.right, c.dy));
  canvas.drawOval(ring, ringPaint);
  canvas.restore();
  _planet(canvas, c, r,
      const [Color(0xFFFDE68A), Color(0xFFD4A373), Color(0xFF92400E)],
      atmosphere: const Color(0xFFFBBF24));
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(ring.left, c.dy, ring.right, ring.bottom + r));
  canvas.drawOval(ring, ringPaint);
  canvas.restore();
}

void _galaxy(Canvas canvas, Offset c, double r, Random random) {
  _glowBlob(canvas, c, r * 0.5, const Color(0xFFFDE68A), 0.5);
  final dot = Paint();
  for (var arm = 0; arm < 3; arm++) {
    for (var i = 0; i < 90; i++) {
      final t = i / 90;
      final angle = arm * 2 * pi / 3 + t * 3.2;
      final d = r * t;
      final jitter = (random.nextDouble() - 0.5) * r * 0.12;
      final p = c +
          Offset(cos(angle) * (d + jitter), sin(angle) * (d + jitter) * 0.45);
      dot.color =
          Color.lerp(const Color(0xFFFDE68A), const Color(0xFFA78BFA), t)!
              .withValues(alpha: 0.75 * (1 - t) + 0.1);
      canvas.drawCircle(p, 0.6 + (1 - t) * 1.4, dot);
    }
  }
}

void _blackHole(Canvas canvas, Offset c, double r) {
  _glowBlob(canvas, c, r * 2.6, const Color(0xFFF97316), 0.35);
  canvas.drawOval(
    Rect.fromCenter(center: c, width: r * 3.6, height: r * 0.9),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28
      ..shader = ui.Gradient.linear(
          c - Offset(r * 1.8, 0), c + Offset(r * 1.8, 0), const [
        Color(0x00FDE68A),
        Color(0xFFFDE68A),
        Color(0xFFF97316),
        Color(0x00F97316)
      ], const [
        0,
        0.35,
        0.7,
        1
      ]),
  );
  canvas.drawCircle(c, r, Paint()..color = Colors.black);
  canvas.drawCircle(
    c,
    r * 1.08,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..color = const Color(0xFFFFEDD5),
  );
}

void _spaceGround(Canvas canvas, Size size, GameStoryChapter chapter,
    StoryStage stage, double top, Random random) {
  final w = size.width, h = size.height;
  switch (chapter) {
    case GameStoryChapter.one:
      // The curve of Earth with its atmosphere.
      final earth = Rect.fromCenter(
          center: Offset(w / 2, top + w * 1.2), width: w * 3, height: w * 2.5);
      _glowBlob(
          canvas, Offset(w / 2, top), w * 0.8, const Color(0xFF60A5FA), 0.25);
      canvas.drawOval(
        earth,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, h), const [
            Color(0xFF60A5FA),
            Color(0xFF1D4ED8),
            Color(0xFF0B1F4D),
          ], const [
            0,
            0.25,
            1
          ]),
      );
      final land = Paint()
        ..color = const Color(0xFF16A34A).withValues(alpha: 0.55);
      for (var i = 0; i < 5; i++) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(
                    w * (0.1 + i * 0.22), top + h * 0.05 + (i.isEven ? 6 : 14)),
                width: w * 0.14,
                height: h * 0.025),
            land);
      }
    case GameStoryChapter.two:
      _ridge(canvas, size, top, const [Color(0xFFD1D5DB), Color(0xFF6B7280)],
          random,
          rough: 6);
      final crater = Paint()
        ..color = const Color(0xFF4B5563).withValues(alpha: 0.6);
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFF3F4F6).withValues(alpha: 0.5);
      for (var i = 0; i < 9; i++) {
        final c = Offset(random.nextDouble() * w,
            top + 12 + random.nextDouble() * (h - top - 16));
        final r = 4 + random.nextDouble() * 12;
        final oval =
            Rect.fromCenter(center: c, width: r * 2.4, height: r * 0.9);
        canvas.drawOval(oval, crater);
        canvas.drawOval(oval, rim);
      }
    case GameStoryChapter.three:
      _ridge(canvas, size, top - h * 0.03,
          const [Color(0xFF9A3412), Color(0xFF431407)], random,
          rough: 18);
      _ridge(canvas, size, top + h * 0.02,
          const [Color(0xFFEA580C), Color(0xFF7C2D12)], random,
          rough: 10);
      final dust = Paint()
        ..color = const Color(0xFFFDBA74).withValues(alpha: 0.07);
      for (var i = 0; i < 4; i++) {
        canvas.drawOval(
            Rect.fromLTWH(
                -w * 0.2 + i * w * 0.35, top - h * 0.05, w * 0.6, h * 0.05),
            dust);
      }
    case GameStoryChapter.four:
      // Icy moon surface with glowing crystals.
      _ridge(canvas, size, top, const [Color(0xFFBAE6FD), Color(0xFF1E3A8A)],
          random,
          rough: 8);
      _crystals(canvas, size, top, random, const Color(0xFF67E8F9),
          count: 7, scale: 0.6);
    case GameStoryChapter.five:
      _ridge(canvas, size, top, const [Color(0xFF312E81), Color(0xFF05030F)],
          random,
          rough: 14);
      _crystals(canvas, size, top, random, const Color(0xFFF0ABFC),
          count: 11, scale: 1.1);
  }
}

void _ridge(
    Canvas canvas, Size size, double top, List<Color> colors, Random random,
    {double rough = 8}) {
  final path = Path()..moveTo(0, top);
  for (var x = 0.0; x <= size.width; x += size.width / 14) {
    path.lineTo(x, top + (random.nextDouble() - 0.5) * rough);
  }
  path
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
  canvas.drawPath(
    path,
    Paint()
      ..shader =
          ui.Gradient.linear(Offset(0, top), Offset(0, size.height), colors),
  );
}

void _crystals(Canvas canvas, Size size, double top, Random random, Color color,
    {required int count, required double scale}) {
  for (var i = 0; i < count; i++) {
    final x = (i + 0.5) / count * size.width + (random.nextDouble() - 0.5) * 20;
    final hgt = (18 + random.nextDouble() * 34) * scale;
    final wid = hgt * 0.35;
    final base = top + 6 + random.nextDouble() * 8;
    _glowBlob(canvas, Offset(x, base - hgt * 0.5), hgt * 0.9, color, 0.22);
    final shard = Path()
      ..moveTo(x, base - hgt)
      ..lineTo(x + wid / 2, base)
      ..lineTo(x - wid / 2, base)
      ..close();
    canvas.drawPath(
      shard,
      Paint()
        ..shader = ui.Gradient.linear(Offset(x, base - hgt), Offset(x, base), [
          Colors.white.withValues(alpha: 0.95),
          color.withValues(alpha: 0.85),
        ]),
    );
  }
}

void _easterFar(Canvas canvas, Size size, GameStoryChapter chapter,
    StoryStage stage, Random random) {
  final w = size.width, h = size.height;
  final cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
  void clouds(int n) {
    for (var i = 0; i < n; i++) {
      final c = Offset(
          random.nextDouble() * w, h * (0.08 + random.nextDouble() * 0.3));
      for (var k = 0; k < 4; k++) {
        canvas.drawCircle(c + Offset(k * 14.0 - 20, (k.isEven ? 0 : -6)),
            14 + (k % 2) * 6, cloud);
      }
    }
  }

  switch (chapter) {
    case GameStoryChapter.one:
      clouds(3);
    case GameStoryChapter.two:
      _sun(canvas, Offset(w * 0.82, h * 0.12), w * 0.07);
      clouds(4);
    case GameStoryChapter.three:
      clouds(3);
      final rainbow = [
        const Color(0xFFFF8FAB),
        const Color(0xFFFFB38A),
        const Color(0xFFFFD166),
        const Color(0xFFB8F27C),
        const Color(0xFF7BDFF2),
        const Color(0xFFC4A7F5),
      ];
      for (var i = 0; i < rainbow.length; i++) {
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.62),
              width: w * (1.3 - i * 0.06),
              height: h * (0.9 - i * 0.045)),
          pi,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.03
            ..color = rainbow[i].withValues(alpha: 0.6),
        );
      }
    case GameStoryChapter.four:
      _sun(canvas, Offset(w * 0.2, h * 0.14), w * 0.09);
      clouds(2);
    case GameStoryChapter.five:
      // Moonlit night: big moon, a few glowing clouds.
      _glowBlob(canvas, Offset(w * 0.78, h * 0.15), w * 0.3,
          const Color(0xFFFDE68A), 0.3);
      canvas.drawCircle(Offset(w * 0.78, h * 0.15), w * 0.08,
          Paint()..color = const Color(0xFFFFF7D6));
      canvas.drawCircle(Offset(w * 0.75, h * 0.13), w * 0.015,
          Paint()..color = const Color(0xFFE7DFC0));
      canvas.drawCircle(Offset(w * 0.81, h * 0.18), w * 0.01,
          Paint()..color = const Color(0xFFE7DFC0));
  }
}

void _sun(Canvas canvas, Offset c, double r) {
  _glowBlob(canvas, c, r * 3, const Color(0xFFFFD166), 0.5);
  final ray = Paint()
    ..color = const Color(0xFFFFD166).withValues(alpha: 0.6)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 12; i++) {
    final a = i / 12 * pi * 2;
    canvas.drawLine(c + Offset(cos(a), sin(a)) * r * 1.3,
        c + Offset(cos(a), sin(a)) * r * 1.8, ray);
  }
  canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFE08A));
}

void _easterGround(Canvas canvas, Size size, GameStoryChapter chapter,
    StoryStage stage, double top, Random random) {
  final w = size.width, h = size.height;
  void hills(Color far, Color near, double amp) {
    for (final (color, offset) in [(far, -h * 0.05), (near, 0.0)]) {
      final path = Path()..moveTo(0, top + offset);
      for (var x = 0.0; x <= w; x += w / 4) {
        path.quadraticBezierTo(
            x + w / 8, top + offset - amp, x + w / 4, top + offset);
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  void flowers(int count, double size0) {
    final petal = Paint();
    final heart = Paint()..color = const Color(0xFFFFF3B0);
    for (var i = 0; i < count; i++) {
      final fx = random.nextDouble() * w;
      final fy = top + 10 + random.nextDouble() * (h - top - 16);
      petal.color = easterEggColors[i % easterEggColors.length];
      for (var p = 0; p < 5; p++) {
        final a = p / 5 * pi * 2;
        canvas.drawCircle(Offset(fx + cos(a) * size0, fy + sin(a) * size0),
            size0 * 0.8, petal);
      }
      canvas.drawCircle(Offset(fx, fy), size0 * 0.6, heart);
    }
  }

  switch (chapter) {
    case GameStoryChapter.one:
      hills(const Color(0xFF9BE37E), const Color(0xFF6CCB6A), 8);
      flowers(12, 3);
    case GameStoryChapter.two:
      hills(const Color(0xFFB6E8A0), const Color(0xFF7BD389), 22);
      flowers(20, 4.5);
    case GameStoryChapter.three:
      hills(const Color(0xFF7BC67E), const Color(0xFF3FA05A), 16);
      final trunk = Paint()..color = const Color(0xFF8B5E34);
      for (var i = 0; i < 5; i++) {
        final x = (i + 0.5) / 5 * w;
        canvas.drawRect(Rect.fromLTWH(x - 3, top - 26, 6, 26), trunk);
        canvas.drawCircle(
            Offset(x, top - 34), 18, Paint()..color = const Color(0xFF2F8F4E));
        canvas.drawCircle(Offset(x - 9, top - 28), 12,
            Paint()..color = const Color(0xFF3FA05A));
      }
      flowers(10, 3.5);
    case GameStoryChapter.four:
      hills(const Color(0xFFFFC2DA), const Color(0xFFFF8FAB), 26);
      for (var i = 0; i < 4; i++) {
        final x = (i + 0.5) / 4 * w;
        canvas.drawLine(
            Offset(x, top + 6),
            Offset(x, top - 30),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 3);
        canvas.drawCircle(Offset(x, top - 38), 12,
            Paint()..color = easterEggColors[i * 2 % 8]);
        canvas.drawArc(
            Rect.fromCircle(center: Offset(x, top - 38), radius: 8),
            0,
            pi * 1.5,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.white);
      }
    case GameStoryChapter.five:
      // Castle silhouette with lit windows and fireflies.
      final castle = Paint()..color = const Color(0xFF16133A);
      canvas.drawRect(
          Rect.fromLTWH(w * 0.25, top - h * 0.12, w * 0.5, h * 0.12 + 4),
          castle);
      for (final (x, tw, th) in [
        (0.22, 0.09, 0.2),
        (0.455, 0.09, 0.26),
        (0.69, 0.09, 0.2)
      ]) {
        canvas.drawRect(
            Rect.fromLTWH(w * x, top - h * th, w * tw, h * th), castle);
        final roof = Path()
          ..moveTo(w * x - 4, top - h * th)
          ..lineTo(w * (x + tw / 2), top - h * th - h * 0.07)
          ..lineTo(w * (x + tw) + 4, top - h * th)
          ..close();
        canvas.drawPath(roof, castle);
        canvas.drawRect(
            Rect.fromLTWH(w * (x + tw / 2) - 3, top - h * th * 0.7, 6, 9),
            Paint()..color = const Color(0xFFFDE68A));
      }
      hills(const Color(0xFF2D2560), const Color(0xFF1E1A48), 10);
      for (var i = 0; i < 18; i++) {
        _glowBlob(
            canvas,
            Offset(
                random.nextDouble() * w, top - random.nextDouble() * h * 0.3),
            6,
            const Color(0xFFFDE68A),
            0.8);
      }
  }
}

/// Widget-side scenery (math games): sky + ground in one cached layer.
class StoryScenePainter extends CustomPainter {
  StoryScenePainter(this.theme, this.chapter, {this.groundY = 0.9});

  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final double groundY;

  @override
  void paint(Canvas canvas, Size size) {
    paintStorySky(canvas, size, theme, chapter);
    paintStoryGround(canvas, size, theme, chapter, groundY: groundY);
  }

  @override
  bool shouldRepaint(StoryScenePainter old) =>
      old.theme != theme || old.chapter != chapter || old.groundY != groundY;
}

// ─── projectiles ────────────────────────────────────────────────────────────

/// Draws a projectile travelling from [from] to [to] (progress [t] 0..1)
/// in the chapter's [style]; [time] animates sparkles. [paint] is reused by
/// the caller across frames.
void paintStoryShot(Canvas canvas, Offset from, Offset to, double t,
    ShotStyle style, double screenWidth, double time, Paint paint) {
  final head = Offset.lerp(from, to, t.clamp(0.0, 1.0))!;
  final dir = to - from;
  final len = dir.distance == 0 ? 1.0 : dir.distance;
  final normal = Offset(-dir.dy / len, dir.dx / len);
  final core = style.width * screenWidth;
  final outer = style.colors.last;
  final offsets =
      style.twin ? [normal * core * 1.6, -normal * core * 1.6] : [Offset.zero];

  for (final o in offsets) {
    if (style.beam) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = core * style.glow
        ..shader = null
        ..color = outer.withValues(alpha: 0.35);
      canvas.drawLine(from + o, head + o, paint);
      paint
        ..strokeWidth = core
        ..color =
            style.colors.length > 1 ? style.colors[1] : style.colors.first;
      canvas.drawLine(from + o, head + o, paint);
      paint
        ..strokeWidth = core * 0.35
        ..color = style.colors.first;
      canvas.drawLine(from + o, head + o, paint);
    }
    paint
      ..style = PaintingStyle.fill
      ..shader = null;
    for (var i = style.trail; i >= 1; i--) {
      final p = Offset.lerp(from, to, (t - i * 0.035).clamp(0.0, 1.0))! + o;
      paint.color = style.colors[i % style.colors.length]
          .withValues(alpha: 0.5 * (1 - i / (style.trail + 1)));
      canvas.drawCircle(p, core * (1 - i / (style.trail + 2)), paint);
    }
    paint.color = outer.withValues(alpha: 0.3);
    canvas.drawCircle(head + o, core * style.glow, paint);
    paint.color =
        style.colors.length > 1 ? style.colors[1] : style.colors.first;
    canvas.drawCircle(head + o, core, paint);
    paint.color = style.colors.first;
    canvas.drawCircle(head + o, core * 0.5, paint);
  }
  for (var i = 0; i < style.sparkles; i++) {
    final a = time * 9 + i * 2 * pi / style.sparkles;
    final p = head + Offset(cos(a), sin(a)) * core * 2.4;
    paint.color = style.colors[(i + 1) % style.colors.length];
    _star(canvas, p, core * 0.7, paint);
  }
}

void _star(Canvas canvas, Offset c, double r, Paint paint) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final rr = i.isEven ? r : r * 0.4;
    final a = i * pi / 4;
    final p = c + Offset(cos(a), sin(a)) * rr;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, paint);
}

// ─── UI pieces ──────────────────────────────────────────────────────────────

/// Small "Chapter n · Title" chip for in-game HUDs.
class GameStoryBadge extends StatelessWidget {
  const GameStoryBadge({required this.theme, required this.chapter, super.key});

  final GameVisualTheme theme;
  final GameStoryChapter chapter;

  @override
  Widget build(BuildContext context) {
    final stage = GameStory.stage(theme, chapter);
    final text = stage.dark ? Colors.white : const Color(0xFF3B2A7A);
    return DecoratedBox(
      key: const ValueKey('story-badge'),
      decoration: BoxDecoration(
        color: stage.accent.withValues(alpha: 0.2),
        border: Border.all(color: stage.accent.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          '${chapter.level} · ${stage.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Celebration shown when a new chapter opens; fades out by itself.
class StoryLevelUpBanner extends StatefulWidget {
  const StoryLevelUpBanner(
      {required this.theme, required this.chapter, super.key});

  final GameVisualTheme theme;
  final GameStoryChapter chapter;

  static const visibleFor = Duration(milliseconds: 2800);

  @override
  State<StoryLevelUpBanner> createState() => _StoryLevelUpBannerState();
}

class _StoryLevelUpBannerState extends State<StoryLevelUpBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: StoryLevelUpBanner.visibleFor)
        ..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = GameStory.stage(widget.theme, widget.chapter);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;
          final opacity = t < 0.12 ? t / 0.12 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
          final scale = t < 0.12 ? 0.8 + t / 0.12 * 0.2 : 1.0;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Center(
          child: Container(
            key: const ValueKey('story-level-up'),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [stage.skyTop, stage.skyBottom]),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: stage.accent, width: 2),
              boxShadow: [
                BoxShadow(
                    color: stage.accent.withValues(alpha: 0.5), blurRadius: 24)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CHAPTER ${widget.chapter.level}',
                    style: TextStyle(
                        color: stage.accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(stage.title,
                    style: TextStyle(
                        color:
                            stage.dark ? Colors.white : const Color(0xFF3B2A7A),
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('${GameStory.guide(widget.theme)}: "${stage.guideLine}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: stage.dark
                            ? Colors.white70
                            : const Color(0xFF5B4B8A))),
                const SizedBox(height: 4),
                Text('New weapon: ${stage.shot.name}',
                    style: TextStyle(
                        color: stage.accent, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Journey map for game home screens: the guide, the story and the five
/// chapters, with the furthest one reached highlighted.
class StoryJourneyCard extends StatelessWidget {
  const StoryJourneyCard({required this.theme, required this.best, super.key});

  final GameVisualTheme theme;
  final GameStoryChapter best;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('story-journey'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 92,
            child: RepaintBoundary(
              child: CustomPaint(
                  painter: StoryScenePainter(theme, best, groundY: 0.75)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(GameStory.journey(theme), style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${GameStory.guide(theme)}: ${GameStory.intro(theme)}',
                    style: textTheme.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in GameStoryChapter.values)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          c.index <= best.index
                              ? Icons.star_rounded
                              : Icons.lock_outline,
                          size: 16,
                          color: c.index <= best.index
                              ? GameStory.stage(theme, c).accent
                              : null,
                        ),
                        label: Text(
                            '${c.level}. ${GameStory.stage(theme, c).title}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── effects ────────────────────────────────────────────────────────────────

class _Shot {
  _Shot(this.from, this.to, this.style, this.seconds);

  final Offset from;
  final Offset to;
  final ShotStyle style;
  final double seconds;
  double t = 0;
}

class _Spark {
  _Spark(this.at, this.velocity, this.color, this.radius);

  Offset at;
  final Offset velocity;
  final Color color;
  final double radius;
  double age = 0;
}

/// Projectiles and impact bursts for widget-based games, in pixels of the
/// layer they are painted on. Bursts grow with the chapter's [ShotStyle].
class StoryEffects {
  StoryEffects({Random? random}) : _random = random ?? Random();

  static const sparkSeconds = 0.6;

  final Random _random;
  final List<_Shot> _shots = [];
  final List<_Spark> _sparks = [];
  double _time = 0;

  bool get isIdle => _shots.isEmpty && _sparks.isEmpty;

  /// A projectile that bursts on arrival.
  void fire(Offset from, Offset to, ShotStyle style, {double seconds = 0.2}) =>
      _shots.add(_Shot(from, to, style, seconds));

  void burst(Offset at, ShotStyle style, {double speed = 160}) {
    for (var i = 0; i < style.impactParticles; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final v = speed * (0.4 + _random.nextDouble());
      _sparks.add(_Spark(
          at,
          Offset(cos(angle), sin(angle)) * v,
          style.colors[i % style.colors.length],
          1.5 + _random.nextDouble() * 2.5));
    }
  }

  void update(double dt) {
    _time += dt;
    for (final shot in List.of(_shots)) {
      shot.t += dt / shot.seconds;
      if (shot.t >= 1) {
        _shots.remove(shot);
        burst(shot.to, shot.style);
      }
    }
    for (final spark in _sparks) {
      spark
        ..age += dt
        ..at += spark.velocity * dt * (1 - spark.age / sparkSeconds);
    }
    _sparks.removeWhere((s) => s.age >= sparkSeconds);
  }

  void paint(Canvas canvas, Size size, Paint paint) {
    for (final shot in _shots) {
      paintStoryShot(canvas, shot.from, shot.to, shot.t, shot.style, size.width,
          _time, paint);
    }
    paint
      ..style = PaintingStyle.fill
      ..shader = null;
    for (final spark in _sparks) {
      final life = 1 - spark.age / sparkSeconds;
      paint.color = spark.color.withValues(alpha: life);
      canvas.drawCircle(spark.at, spark.radius * life + 0.5, paint);
    }
  }
}

/// Paints [effects]; repaints only when [repaint] ticks.
class StoryEffectsPainter extends CustomPainter {
  StoryEffectsPainter(this.effects, {required Listenable repaint})
      : super(repaint: repaint);

  final StoryEffects effects;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) => effects.paint(canvas, size, _paint);

  @override
  bool shouldRepaint(StoryEffectsPainter old) => old.effects != effects;
}

/// The player's cannon for widget-based shooters; its look follows the
/// chapter (bigger, brighter barrel as weapons upgrade).
class StoryCannon extends StatelessWidget {
  const StoryCannon(
      {required this.theme, required this.chapter, this.size = 56, super.key});

  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size(size, size),
          painter: _CannonPainter(GameStory.stage(theme, chapter), chapter),
        ),
      );
}

class _CannonPainter extends CustomPainter {
  _CannonPainter(this.stage, this.chapter);

  final StoryStage stage;
  final GameStoryChapter chapter;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.78);
    final r = size.width * 0.32;
    final colors = stage.shot.colors;
    _glowBlob(
        canvas, base, r * (1.6 + chapter.index * 0.25), stage.accent, 0.35);
    final barrelW = r * (0.42 + chapter.index * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            base.dx - barrelW / 2, base.dy - r * 1.9, barrelW, r * 1.9),
        Radius.circular(barrelW / 2),
      ),
      Paint()
        ..shader = ui.Gradient.linear(Offset(base.dx, base.dy - r * 1.9), base,
            [colors.first, colors.length > 1 ? colors[1] : stage.accent]),
    );
    canvas.drawCircle(
      base,
      r,
      Paint()
        ..shader = ui.Gradient.radial(base - Offset(r * 0.3, r * 0.3), r * 1.3,
            [Colors.white, stage.accent, stage.horizon], const [0, 0.5, 1]),
    );
  }

  @override
  bool shouldRepaint(_CannonPainter old) =>
      old.chapter != chapter || old.stage != stage;
}

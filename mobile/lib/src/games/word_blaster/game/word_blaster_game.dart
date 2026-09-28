import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/material.dart' show ColorScheme, Icons, IconData;
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextStyle, FontWeight, TextDirection, TextAlign;

import '../../common/game_audio.dart';
import '../word_blaster_session.dart';

/// Colours for the space scene; accents follow the app's colour scheme.
class WordBlasterPalette {
  WordBlasterPalette.fromScheme(ColorScheme scheme, {this.fontFamily})
      : accent = scheme.primaryContainer,
        accentStrong = scheme.primary,
        secondary = scheme.tertiaryContainer;

  final Color accent;
  final Color accentStrong;
  final Color secondary;
  final String? fontFamily;

  static const skyTop = Color(0xFF0B1026);
  static const skyBottom = Color(0xFF1C2B4F);
  static const rock = Color(0xFF5A6480);
  static const rockDark = Color(0xFF3E4660);
  static const rockLight = Color(0xFF7C87A6);
  static const text = Color(0xFFFFFFFF);
  static const correct = Color(0xFF4ADE80);
  static const wrong = Color(0xFFFF5C7A);
  static const gold = Color(0xFFFFC857);
  static const shield = Color(0xFF7DD3FC);
}

/// Flame scene for a Word Blaster round. Rules live in [WordBlasterSession];
/// the game advances the session every frame and renders its state.
class WordBlasterGame extends FlameGame {
  WordBlasterGame({
    required this.session,
    required this.palette,
    required this.audio,
    this.reducedMotion = false,
  });

  final WordBlasterSession session;
  WordBlasterPalette palette;
  final GameAudio audio;
  final bool reducedMotion;

  final Map<int, MeteorComponent> _meteors = {};
  PowerUpComponent? _powerUp;
  late final CannonComponent cannon;
  late final BossComponent boss;
  late final ShieldComponent shield;
  StreamSubscription<WordBlasterEvent>? _events;
  final Random _random = Random();
  double _shake = 0;

  /// Top of the play field and the ground line, in game coordinates.
  double get fieldTop => size.y * 0.04;
  double get groundY => size.y * 0.84;

  @override
  Color backgroundColor() => WordBlasterPalette.skyTop;

  @override
  Future<void> onLoad() async {
    await add(StarfieldComponent(layers: reducedMotion ? 2 : 3));
    cannon = CannonComponent();
    boss = BossComponent();
    shield = ShieldComponent();
    await addAll([boss, shield, cannon]);
    _events = session.events.listen(_onEvent);
  }

  @override
  void onRemove() {
    _events?.cancel();
    super.onRemove();
  }

  @override
  void update(double dt) {
    // Clamp long frames (app resume, debugger) so meteors do not teleport.
    session.update(min(dt, 0.1));
    _syncMeteors();
    _syncPowerUp();
    if (_shake > 0) _shake = max(0, _shake - dt);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_shake > 0 && !reducedMotion) {
      final s = _shake * 14;
      canvas.save();
      canvas.translate(
          (_random.nextDouble() - 0.5) * s, (_random.nextDouble() - 0.5) * s);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }

  /// Screen position of a meteor's centre (for tests and tutorials).
  Vector2? meteorCenter(int id) => _meteors[id]?.position.clone();

  Vector2 positionFor(MeteorState m) => Vector2(
        m.x * size.x,
        fieldTop + m.progress.clamp(0.0, 1.0) * (groundY - fieldTop),
      );

  void _syncMeteors() {
    final live = <int>{};
    for (final state in session.meteors) {
      if (!state.destroyed) live.add(state.id);
      final existing = _meteors[state.id];
      if (existing == null) {
        if (!state.visible) continue;
        final component = MeteorComponent(state);
        _meteors[state.id] = component;
        add(component);
      }
    }
    for (final id in _meteors.keys.toList()) {
      final component = _meteors[id]!;
      if (!live.contains(id) && !component.awaitingImpact) {
        component.vanish();
        _meteors.remove(id);
      }
    }
  }

  void _syncPowerUp() {
    final state = session.powerUp;
    if (state == null) {
      _powerUp?.removeFromParent();
      _powerUp = null;
      return;
    }
    if (_powerUp?.state.id != state.id) {
      _powerUp?.removeFromParent();
      _powerUp = PowerUpComponent(state);
      add(_powerUp!);
    }
  }

  void onMeteorTapped(MeteorComponent meteor) {
    if (session.phase != WordBlasterPhase.playing || session.isOverheated) {
      if (session.isOverheated) cannon.flashOverheat();
      return;
    }
    cannon.aimAt(meteor.position);
    meteor.awaitingImpact = true;
    final fired = session.shoot(meteor.state.id);
    if (!fired) {
      meteor.awaitingImpact = false;
      return;
    }
    audio.play(GameSound.shoot, volume: 0.5);
    add(ProjectileComponent(
      from: cannon.muzzle,
      target: meteor,
      onImpact: () => _impact(meteor),
    ));
  }

  void onPowerUpTapped() {
    final state = session.powerUp;
    if (state == null) return;
    final at = _powerUp?.position.clone();
    if (session.collectPowerUp() && at != null) {
      _burst(at, [palette.accent, WordBlasterPalette.gold], count: 18);
    }
  }

  void _impact(MeteorComponent meteor) {
    meteor.awaitingImpact = false;
    final correct = meteor.state.isCorrect;
    _burst(
      meteor.position,
      correct
          ? [
              WordBlasterPalette.correct,
              palette.accent,
              WordBlasterPalette.gold
            ]
          : [WordBlasterPalette.wrong, WordBlasterPalette.rockLight],
      count: reducedMotion ? 10 : 26,
    );
    meteor.explode();
    _meteors.remove(meteor.state.id);
  }

  void _onEvent(WordBlasterEvent event) {
    switch (event.kind) {
      case WordBlasterEventKind.correct:
        audio.play(GameSound.hit);
        audio.haptic(GameHaptic.light);
        final m = _meteors[event.meteorId];
        if (m != null) {
          add(FloatingTextComponent('+${event.points}',
              position: m.position - Vector2(0, m.size.y * 0.9),
              color: WordBlasterPalette.gold));
        }
      case WordBlasterEventKind.wrong:
      case WordBlasterEventKind.missed:
        audio.play(GameSound.wrong);
        audio.haptic(GameHaptic.medium);
        for (final m in _meteors.values) {
          if (m.state.isCorrect) m.reveal();
        }
      case WordBlasterEventKind.lifeLost:
        _shake = 0.35;
        audio.haptic(GameHaptic.heavy);
      case WordBlasterEventKind.shieldBlocked:
        shield.pop();
      case WordBlasterEventKind.comboUp:
        audio.play(GameSound.combo);
        add(FloatingTextComponent('COMBO x${event.value}',
            position: Vector2(size.x / 2, size.y * 0.45),
            color: palette.accent,
            fontScale: 1.6));
      case WordBlasterEventKind.powerUpCollected:
        audio.play(GameSound.powerUp);
      case WordBlasterEventKind.bossAppeared:
        audio.play(GameSound.boss);
        boss.appear();
      case WordBlasterEventKind.bossHit:
        boss.hit();
      case WordBlasterEventKind.bossDefeated:
        boss.defeat();
        _burst(boss.position,
            [WordBlasterPalette.gold, palette.accent, WordBlasterPalette.wrong],
            count: reducedMotion ? 20 : 70, speed: 2.2);
        add(FloatingTextComponent('+1000',
            position: boss.position.clone(),
            color: WordBlasterPalette.gold,
            fontScale: 1.8));
      case WordBlasterEventKind.overheated:
        cannon.flashOverheat();
      case WordBlasterEventKind.gameOver:
        audio.play(GameSound.gameOver);
      case WordBlasterEventKind.questionStarted:
      case WordBlasterEventKind.powerUpSpawned:
      case WordBlasterEventKind.waveCleared:
        break;
    }
  }

  void _burst(Vector2 at, List<Color> colors,
      {int count = 24, double speed = 1}) {
    final base = size.x * 0.55 * speed;
    add(ParticleSystemComponent(
      position: at.clone(),
      particle: Particle.generate(
        count: count,
        lifespan: 0.7,
        generator: (i) {
          final angle = _random.nextDouble() * pi * 2;
          final v = base * (0.4 + _random.nextDouble());
          final color = colors[i % colors.length];
          return AcceleratedParticle(
            speed: Vector2(cos(angle), sin(angle)) * v,
            acceleration: Vector2(cos(angle), sin(angle)) * -v * 1.1,
            child: ComputedParticle(
              renderer: (canvas, p) {
                final r = size.x * 0.012 * (1 - p.progress);
                canvas.drawCircle(
                  Offset.zero,
                  max(0.5, r),
                  Paint()..color = color.withValues(alpha: 1 - p.progress),
                );
              },
            ),
          );
        },
      ),
    ));
  }
}

// ─── text helper ────────────────────────────────────────────────────────────

TextPainter layoutText(
  String text, {
  required double fontSize,
  required Color color,
  String? fontFamily,
  FontWeight weight = FontWeight.w700,
  double? maxWidth,
  int maxLines = 2,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: weight,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  return painter;
}

// ─── background ─────────────────────────────────────────────────────────────

class StarfieldComponent extends Component
    with HasGameReference<WordBlasterGame> {
  StarfieldComponent({required this.layers});

  final int layers;
  final List<_Star> _stars = [];
  final Random _random = Random(42);

  @override
  Future<void> onLoad() async {
    for (var layer = 0; layer < layers; layer++) {
      for (var i = 0; i < 26 + layer * 14; i++) {
        _stars.add(_Star(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          layer: layer,
          twinkle: _random.nextDouble() * pi * 2,
        ));
      }
    }
  }

  @override
  void update(double dt) {
    for (final star in _stars) {
      star.y += dt * (0.008 + star.layer * 0.012);
      if (star.y > 1) star.y -= 1;
      star.twinkle += dt * 2;
    }
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(0, size.y),
          [WordBlasterPalette.skyTop, WordBlasterPalette.skyBottom],
        ),
    );
    for (final star in _stars) {
      final alpha = 0.35 + 0.25 * star.layer + 0.2 * sin(star.twinkle);
      canvas.drawCircle(
        Offset(star.x * size.x, star.y * size.y),
        0.6 + star.layer * 0.6,
        Paint()
          ..color =
              const Color(0xFFFFFFFF).withValues(alpha: alpha.clamp(0.1, 1.0)),
      );
    }
    // Ground glow.
    canvas.drawRect(
      Rect.fromLTWH(0, game.groundY, size.x, size.y - game.groundY),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, game.groundY),
          Offset(0, size.y),
          [
            game.palette.accentStrong.withValues(alpha: 0.28),
            WordBlasterPalette.skyBottom
          ],
        ),
    );
    canvas.drawLine(
      Offset(0, game.groundY),
      Offset(size.x, game.groundY),
      Paint()
        ..color = game.palette.accent.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
  }
}

class _Star {
  _Star(
      {required this.x,
      required this.y,
      required this.layer,
      required this.twinkle});

  double x;
  double y;
  final int layer;
  double twinkle;
}

// ─── meteors ────────────────────────────────────────────────────────────────

class MeteorComponent extends PositionComponent
    with TapCallbacks, HasGameReference<WordBlasterGame> {
  MeteorComponent(this.state) : super(anchor: Anchor.center, priority: 10);

  final MeteorState state;
  bool awaitingImpact = false;
  bool _revealed = false;
  double _fade = 1;
  bool _vanishing = false;
  bool _exploding = false;
  double _spin = 0;
  late final List<Offset> _shape;
  late final List<(Offset, double)> _craters;
  TextPainter? _text;
  double _textFontSize = 0;

  static final Random _random = Random();

  void reveal() => _revealed = true;

  void vanish() {
    _vanishing = true;
  }

  void explode() {
    _exploding = true;
  }

  @override
  Future<void> onLoad() async {
    _spin = (_random.nextDouble() - 0.5) * 0.3;
    _shape = List.generate(11, (i) {
      final a = i / 11 * pi * 2;
      final r = 0.86 + _random.nextDouble() * 0.14;
      return Offset(cos(a) * r, sin(a) * r);
    });
    _craters = List.generate(3, (i) {
      final a = _random.nextDouble() * pi * 2;
      final d = 0.35 + _random.nextDouble() * 0.35;
      return (
        Offset(cos(a) * d, sin(a) * d),
        0.08 + _random.nextDouble() * 0.08
      );
    });
    _layout();
    position = game.positionFor(state);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout();
  }

  void _layout() {
    final w = game.size.x;
    final fontSize = max(16.0, w * 0.042);
    final maxWidth = w * 0.36;
    _textFontSize = fontSize;
    _text = layoutText(
      state.label,
      fontSize: fontSize,
      color: WordBlasterPalette.text,
      fontFamily: game.palette.fontFamily,
      maxWidth: maxWidth,
    );
    final width = max(w * 0.2, _text!.width + fontSize * 1.6);
    final height = max(w * 0.13, _text!.height + fontSize * 1.1);
    size = Vector2(width, height);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // Generous hit box for thumbs.
    final pad = size.x * 0.12;
    return point.x >= -pad &&
        point.y >= -pad &&
        point.x <= size.x + pad &&
        point.y <= size.y + pad;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!_vanishing && !_exploding) game.onMeteorTapped(this);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_exploding) {
      _fade -= dt * 6;
      scale = Vector2.all(1 + (1 - _fade) * 0.4);
    } else if (_vanishing) {
      _fade -= dt * 4;
    }
    if (_fade <= 0) {
      removeFromParent();
      return;
    }
    if (!awaitingImpact && !_exploding) {
      position = game.positionFor(state);
    }
    angle += _spin * dt * (game.reducedMotion ? 0 : 1);
    angle = angle.clamp(-0.18, 0.18);
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final center = rect.center;
    final radiusX = size.x / 2;
    final radiusY = size.y / 2;
    final path = Path();
    for (var i = 0; i < _shape.length; i++) {
      final p = Offset(center.dx + _shape[i].dx * radiusX,
          center.dy + _shape[i].dy * radiusY);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    final alpha = _fade.clamp(0.0, 1.0);

    if (_revealed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = WordBlasterPalette.correct.withValues(alpha: 0.55 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            WordBlasterPalette.rockLight.withValues(alpha: alpha),
            WordBlasterPalette.rock.withValues(alpha: alpha),
            WordBlasterPalette.rockDark.withValues(alpha: alpha),
          ],
          [0, 0.55, 1],
        ),
    );
    for (final (offset, r) in _craters) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
              center.dx + offset.dx * radiusX, center.dy + offset.dy * radiusY),
          width: r * radiusX * 2,
          height: r * radiusY * 2,
        ),
        Paint()
          ..color = WordBlasterPalette.rockDark.withValues(alpha: 0.45 * alpha),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = (_revealed ? WordBlasterPalette.correct : game.palette.accent)
            .withValues(alpha: 0.9 * alpha),
    );
    final text = _text;
    if (text != null) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-angle);
      // Dark plate behind the label for contrast.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: text.width + _textFontSize * 0.7,
            height: text.height + _textFontSize * 0.3,
          ),
          Radius.circular(_textFontSize * 0.4),
        ),
        Paint()
          ..color = const Color(0xFF0B1026).withValues(alpha: 0.45 * alpha),
      );
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
    }
    if (_revealed) {
      canvas.drawCircle(
        Offset(rect.right - 6, rect.top + 6),
        _textFontSize * 0.45,
        Paint()..color = WordBlasterPalette.correct,
      );
      final check = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.check_rounded.codePoint),
          style: TextStyle(
            fontFamily: Icons.check_rounded.fontFamily,
            package: Icons.check_rounded.fontPackage,
            fontSize: _textFontSize * 0.7,
            color: WordBlasterPalette.skyTop,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      check.paint(
          canvas,
          Offset(rect.right - 6 - check.width / 2,
              rect.top + 6 - check.height / 2));
    }
  }
}

// ─── cannon, projectile, shield ─────────────────────────────────────────────

class CannonComponent extends PositionComponent
    with HasGameReference<WordBlasterGame> {
  CannonComponent() : super(anchor: Anchor.center, priority: 20);

  double _aim = -pi / 2;
  double _targetAim = -pi / 2;
  double _recoil = 0;
  double _overheat = 0;

  Vector2 get muzzle =>
      position + Vector2(cos(_aim), sin(_aim)) * (game.size.x * 0.1);

  void aimAt(Vector2 target) {
    final d = target - position;
    _targetAim = atan2(d.y, d.x).clamp(-pi + 0.25, -0.25);
    _aim = _targetAim;
    _recoil = 1;
  }

  void flashOverheat() => _overheat = 1;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x / 2, size.y * 0.93);
  }

  @override
  void update(double dt) {
    _recoil = max(0, _recoil - dt * 6);
    _overheat = max(0, _overheat - dt * 1.2);
    if (game.session.isOverheated) _overheat = max(_overheat, 0.6);
    _aim += (-pi / 2 - _aim) * (1 - exp(-dt * 1.5)) * (_recoil > 0 ? 0 : 1);
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final baseR = w * 0.075;
    final barrelLength = w * 0.1 * (1 - 0.18 * _recoil);
    final barrelWidth = w * 0.035;
    final heat =
        Color.lerp(game.palette.accent, WordBlasterPalette.wrong, _overheat)!;

    canvas.save();
    canvas.rotate(_aim + pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            -barrelWidth / 2, -barrelLength, barrelWidth, barrelLength),
        Radius.circular(barrelWidth / 2),
      ),
      Paint()..color = heat,
    );
    canvas.restore();
    canvas.drawCircle(
      Offset.zero,
      baseR,
      Paint()
        ..shader = Gradient.radial(
          Offset(-baseR * 0.3, -baseR * 0.3),
          baseR * 1.2,
          [game.palette.accent, game.palette.accentStrong],
        ),
    );
    canvas.drawCircle(
      Offset.zero,
      baseR * 0.45,
      Paint()..color = WordBlasterPalette.skyTop.withValues(alpha: 0.5),
    );
  }
}

class ProjectileComponent extends Component
    with HasGameReference<WordBlasterGame> {
  ProjectileComponent(
      {required this.from, required this.target, required this.onImpact})
      : super(priority: 15);

  static const flightSeconds = 0.14;

  final Vector2 from;
  final MeteorComponent target;
  final void Function() onImpact;
  double _t = 0;
  final List<Offset> _trail = [];

  Vector2 get _to => target.position;

  @override
  void update(double dt) {
    _t += dt / flightSeconds;
    final p = Vector2(
      from.x + (_to.x - from.x) * min(1, _t),
      from.y + (_to.y - from.y) * min(1, _t),
    );
    _trail.add(Offset(p.x, p.y));
    if (_trail.length > 6) _trail.removeAt(0);
    if (_t >= 1) {
      onImpact();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < _trail.length; i++) {
      final a = (i + 1) / _trail.length;
      canvas.drawCircle(
        _trail[i],
        game.size.x * 0.012 * a,
        Paint()..color = WordBlasterPalette.gold.withValues(alpha: a),
      );
    }
  }
}

class ShieldComponent extends PositionComponent
    with HasGameReference<WordBlasterGame> {
  ShieldComponent() : super(anchor: Anchor.center, priority: 19);

  double _pulse = 0;
  double _pop = 0;

  void pop() => _pop = 1;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x / 2, size.y * 0.93);
  }

  @override
  void update(double dt) {
    _pulse += dt * 3;
    _pop = max(0, _pop - dt * 2);
  }

  @override
  void render(Canvas canvas) {
    final active = game.session.shieldCharges > 0;
    if (!active && _pop <= 0) return;
    final r = game.size.x * (0.14 + 0.01 * sin(_pulse) + 0.08 * _pop);
    final alpha = active ? 0.35 : 0.5 * _pop;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = WordBlasterPalette.shield.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = WordBlasterPalette.shield.withValues(alpha: alpha * 0.25),
    );
  }
}

// ─── power-ups ──────────────────────────────────────────────────────────────

class PowerUpComponent extends PositionComponent
    with TapCallbacks, HasGameReference<WordBlasterGame> {
  PowerUpComponent(this.state) : super(anchor: Anchor.center, priority: 12);

  final PowerUpState state;
  double _pulse = 0;

  static IconData iconFor(PowerUpKind kind) => switch (kind) {
        PowerUpKind.slowMotion => Icons.ac_unit_rounded,
        PowerUpKind.bomb => Icons.flare_rounded,
        PowerUpKind.shield => Icons.shield_rounded,
        PowerUpKind.heart => Icons.favorite_rounded,
      };

  static Color colorFor(PowerUpKind kind) => switch (kind) {
        PowerUpKind.slowMotion => WordBlasterPalette.shield,
        PowerUpKind.bomb => const Color(0xFFFF9F43),
        PowerUpKind.shield => const Color(0xFF60A5FA),
        PowerUpKind.heart => WordBlasterPalette.wrong,
      };

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2.all(size.x * 0.13);
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      (point - size / 2).length <= size.x * 0.75;

  @override
  void onTapDown(TapDownEvent event) => game.onPowerUpTapped();

  @override
  void update(double dt) {
    _pulse += dt * 4;
    position = Vector2(
      state.x * game.size.x,
      game.fieldTop + state.progress * (game.groundY - game.fieldTop),
    );
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2 * (1 + 0.06 * sin(_pulse));
    final c = Offset(size.x / 2, size.y / 2);
    final color = colorFor(state.kind);
    canvas.drawCircle(
        c, r * 1.25, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(c, r, Paint()..color = color);
    final icon = iconFor(state.kind);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: r * 1.1,
          color: WordBlasterPalette.skyTop,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, c - Offset(painter.width / 2, painter.height / 2));
  }
}

// ─── boss ───────────────────────────────────────────────────────────────────

class BossComponent extends PositionComponent
    with HasGameReference<WordBlasterGame> {
  BossComponent() : super(anchor: Anchor.center, priority: 5);

  double _visible = 0;
  double _target = 0;
  double _hit = 0;
  double _time = 0;

  void appear() => _target = 1;
  void hit() => _hit = 1;
  void defeat() {
    _target = 0;
    _hit = 1;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2(size.x * 0.62, size.x * 0.2);
  }

  @override
  void update(double dt) {
    _time += dt;
    _visible += (_target - _visible) * (1 - exp(-dt * 4));
    _hit = max(0, _hit - dt * 3);
    final sway = game.reducedMotion ? 0 : sin(_time * 0.9) * game.size.x * 0.08;
    position = Vector2(
      game.size.x / 2 + sway + (_hit > 0 ? sin(_time * 60) * 6 * _hit : 0),
      game.size.y * 0.1 * _visible - size.y * (1 - _visible),
    );
  }

  @override
  void render(Canvas canvas) {
    if (_visible < 0.02) return;
    final rect = size.toRect();
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, rect.height * 0.25, rect.width, rect.height * 0.55),
      Radius.circular(rect.height * 0.3),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.width / 2, rect.height * 0.3),
        width: rect.width * 0.36,
        height: rect.height * 0.5,
      ),
      Paint()..color = game.palette.accent.withValues(alpha: 0.85),
    );
    for (var i = 0; i < 5; i++) {
      final x = rect.width * (0.15 + i * 0.175);
      canvas.drawCircle(
        Offset(x, rect.height * 0.6),
        rect.height * 0.06,
        Paint()
          ..color = (i + (_time * 4).floor()) % 2 == 0
              ? WordBlasterPalette.gold
              : WordBlasterPalette.wrong,
      );
    }
    if (_hit > 0) {
      canvas.drawRRect(
        body,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6 * _hit),
      );
    }
    // Health bar.
    final health = game.session.bossHealthLeft / WordBlasterSession.bossHealth;
    final barRect = Rect.fromLTWH(
        rect.width * 0.2, rect.height * 0.92, rect.width * 0.6, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
      Paint()..color = const Color(0x55FFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barRect.left, barRect.top,
            barRect.width * health.clamp(0.0, 1.0), 6),
        const Radius.circular(3),
      ),
      Paint()..color = WordBlasterPalette.wrong,
    );
  }
}

// ─── floating text ──────────────────────────────────────────────────────────

class FloatingTextComponent extends PositionComponent
    with HasGameReference<WordBlasterGame> {
  FloatingTextComponent(
    this.text, {
    required Vector2 position,
    required this.color,
    this.fontScale = 1,
  }) : super(position: position, anchor: Anchor.center, priority: 30);

  final String text;
  final Color color;
  final double fontScale;
  double _t = 0;
  TextPainter? _painter;

  @override
  void update(double dt) {
    _t += dt / 0.9;
    position.y -= dt * game.size.y * 0.08;
    if (_t >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = 1 - Curves.easeIn.transform(_t.clamp(0.0, 1.0));
    _painter ??= layoutText(
      text,
      fontSize: game.size.x * 0.05 * fontScale,
      color: color,
      fontFamily: game.palette.fontFamily,
      weight: FontWeight.w800,
    );
    canvas.saveLayer(null,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha));
    _painter!
        .paint(canvas, Offset(-_painter!.width / 2, -_painter!.height / 2));
    canvas.restore();
  }
}

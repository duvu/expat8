import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart'
    show ColorScheme, Icons, IconData, HSLColor;
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextStyle, FontWeight, TextDirection, TextAlign;

import '../../common/game_audio.dart';
import '../word_blaster_session.dart';
import '../word_blaster_theme.dart';
import '../../common/game_story.dart';
import '../../common/game_story_scene.dart';
import 'shot_ray.dart';

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
    this.theme = WordBlasterTheme.space,
  });

  final WordBlasterSession session;
  WordBlasterPalette palette;
  final GameAudio audio;
  final bool reducedMotion;
  final WordBlasterTheme theme;

  bool get isEaster => theme == WordBlasterTheme.easter;

  /// Current story chapter: scenery, cannon and projectiles follow it.
  GameStoryChapter chapter = GameStoryChapter.one;
  StoryStage get stage => GameStory.stage(theme, chapter);

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
  Color backgroundColor() => stage.skyTop;

  @override
  Future<void> onLoad() async {
    await add(StarfieldComponent(layers: reducedMotion ? 2 : 3));
    await add(AimSurface());
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

  /// The learner touched [tap]: shoot along the straight line from the cannon
  /// through that point. The shot hits the first meteor on the line; with
  /// none there, it flies off the field and costs nothing.
  void fireToward(Vector2 tap) {
    if (session.phase != WordBlasterPhase.playing) return;
    if (session.isOverheated) {
      cannon.flashOverheat();
      return;
    }
    final pivot = Offset(cannon.position.x, cannon.position.y);
    // Touching the cannon itself gives no direction.
    if ((Offset(tap.x, tap.y) - pivot).distance < size.x * 0.06) return;
    final angle = aimAngle(pivot, Offset(tap.x, tap.y));
    cannon.aimAt(angle);
    final muzzle = Offset(cannon.muzzle.x, cannon.muzzle.y);
    final first = _firstMeteorOnLine(muzzle, angle);
    final hit = first?.item;
    final hitDistance = first?.distance ?? 0;

    audio.play(GameSound.shotFor(chapter), volume: 0.5);
    final from = Vector2(muzzle.dx, muzzle.dy);
    if (hit != null && session.shoot(hit.state.id)) {
      final target = hit;
      target.awaitingImpact = true;
      final end = muzzle + Offset(cos(angle), sin(angle)) * hitDistance;
      add(ProjectileComponent(
        from: from,
        to: Vector2(end.dx, end.dy),
        onImpact: () => _impact(target),
      ));
      return;
    }
    final end = shotExit(muzzle, angle, Size(size.x, size.y));
    add(ProjectileComponent(from: from, to: Vector2(end.dx, end.dy)));
  }

  ({MeteorComponent item, double distance})? _firstMeteorOnLine(
          Offset muzzle, double angle) =>
      firstHit(muzzle, angle, [
        for (final m in _meteors.values)
          if (m.targetable) (m, m.hitBox),
      ]);

  /// Which meteor a touch at [tap] would hit, without shooting (tests).
  @visibleForTesting
  int? meteorIdAlong(Vector2 tap) {
    final pivot = Offset(cannon.position.x, cannon.position.y);
    final angle = aimAngle(pivot, Offset(tap.x, tap.y));
    final muzzle = cannon.muzzleAt(angle);
    return _firstMeteorOnLine(Offset(muzzle.x, muzzle.y), angle)?.item.state.id;
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
          ? stage.shot.colors
          : [WordBlasterPalette.wrong, WordBlasterPalette.rockLight],
      count: reducedMotion ? 10 : stage.shot.impactParticles,
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
          final paint = Paint(); // one per particle, recoloured each frame
          return AcceleratedParticle(
            speed: Vector2(cos(angle), sin(angle)) * v,
            acceleration: Vector2(cos(angle), sin(angle)) * -v * 1.1,
            child: ComputedParticle(
              renderer: (canvas, p) {
                final r = size.x * 0.012 * (1 - p.progress);
                paint.color = color.withValues(alpha: 1 - p.progress);
                canvas.drawCircle(Offset.zero, max(0.5, r), paint);
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
  final Paint _dotPaint = Paint();
  final Paint _streakPaint = Paint()..strokeCap = StrokeCap.round;

  // The chapter's sky and landscape never move: record them once per
  // (chapter, size) instead of rebuilding shaders and paths every frame.
  Picture? _sky;
  Picture? _ground;
  (GameStoryChapter, Vector2)? _recordedFor;

  // Shooting stars appear from chapter 3 on, more often in later chapters.
  Offset? _streak;
  double _streakAge = 0;
  double _nextStreak = 2;

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
  void onRemove() {
    _sky?.dispose();
    _ground?.dispose();
    _sky = _ground = null;
    super.onRemove();
  }

  @override
  void update(double dt) {
    for (final star in _stars) {
      star.y += dt * (0.008 + star.layer * 0.012);
      if (star.y > 1) star.y -= 1;
      star.twinkle += dt * 2;
    }
    final level = game.chapter.level;
    if (_streak != null) {
      _streakAge += dt;
      if (_streakAge > 0.8) _streak = null;
    } else if (level >= 3 && !game.reducedMotion) {
      _nextStreak -= dt;
      if (_nextStreak <= 0) {
        _streak = Offset(
            _random.nextDouble() * 0.8 + 0.1, _random.nextDouble() * 0.4);
        _streakAge = 0;
        _nextStreak = (7 - level) * (0.8 + _random.nextDouble());
      }
    }
  }

  void _record() {
    final key = (game.chapter, game.size.clone());
    if (_recordedFor == key && _sky != null) return;
    _sky?.dispose();
    _ground?.dispose();
    final size = Size(game.size.x, game.size.y);
    var recorder = PictureRecorder();
    paintStorySky(Canvas(recorder), size, game.theme, game.chapter);
    _sky = recorder.endRecording();
    recorder = PictureRecorder();
    paintStoryGround(Canvas(recorder), size, game.theme, game.chapter,
        groundY: game.groundY / game.size.y);
    _ground = recorder.endRecording();
    _recordedFor = key;
  }

  @override
  void render(Canvas canvas) {
    _record();
    final size = game.size;
    canvas.drawPicture(_sky!);
    final dark = game.stage.dark;
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      if (dark) {
        final alpha = 0.35 + 0.25 * star.layer + 0.2 * sin(star.twinkle);
        _dotPaint.color =
            const Color(0xFFFFFFFF).withValues(alpha: alpha.clamp(0.1, 1.0));
        canvas.drawCircle(Offset(star.x * size.x, star.y * size.y),
            0.6 + star.layer * 0.6, _dotPaint);
      } else {
        final alpha = (0.45 + 0.3 * sin(star.twinkle)).clamp(0.15, 0.9);
        _dotPaint.color = easterEggColors[i % easterEggColors.length]
            .withValues(alpha: alpha);
        canvas.drawCircle(Offset(star.x * size.x, star.y * size.y),
            1.6 + star.layer * 1.2, _dotPaint);
      }
    }
    final streak = _streak;
    if (streak != null) {
      final head = Offset(streak.dx * size.x, streak.dy * size.y) +
          const Offset(1, 0.45) * (_streakAge * size.x * 0.9);
      _streakPaint
        ..strokeWidth = 2
        ..shader = Gradient.linear(head, head - const Offset(60, 27), [
          const Color(0xFFFFFFFF).withValues(alpha: 1 - _streakAge / 0.8),
          const Color(0x00FFFFFF),
        ]);
      canvas.drawLine(head, head - const Offset(60, 27), _streakPaint);
    }
    canvas.drawPicture(_ground!);
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
    with HasGameReference<WordBlasterGame> {
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
  late final Color _eggColor;
  late final int _eggPattern;

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
    _eggColor = easterEggColors[_random.nextInt(easterEggColors.length)];
    _eggPattern = _random.nextInt(4);
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
    _text?.dispose();
    _text = layoutText(
      state.label,
      fontSize: fontSize,
      color: game.isEaster ? const Color(0xFF3B2A7A) : WordBlasterPalette.text,
      fontFamily: game.palette.fontFamily,
      maxWidth: maxWidth,
    );
    if (game.isEaster) {
      // Egg size follows the word: short words give small eggs, long words big ones.
      final scale = eggScaleForLength(state.label.runes.length);
      final width = max(w * 0.14 * scale, _text!.width + fontSize * 1.5);
      size = Vector2(width, width * 1.22);
      return;
    }
    final width = max(w * 0.2, _text!.width + fontSize * 1.6);
    final height = max(w * 0.13, _text!.height + fontSize * 1.1);
    size = Vector2(width, height);
  }

  /// Can still be hit: not already shot, vanishing or exploding.
  bool get targetable =>
      !_vanishing && !_exploding && !awaitingImpact && !state.destroyed;

  /// What a shot must cross to hit; generous, for thumbs.
  Rect get hitBox {
    final pad = size.x * 0.12;
    return Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.x + pad * 2,
      height: size.y + pad * 2,
    );
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

  // The body (shell/rock, pattern, outline, reveal glow and tick) is recorded
  // once into a Picture and replayed every frame; only the upright label is
  // drawn live. Re-recorded when the size or reveal state changes.
  Picture? _body;
  Vector2? _bodySize;
  bool _bodyRevealed = false;
  final Paint _platePaint = Paint();
  final Paint _fadePaint = Paint();

  @override
  void onRemove() {
    _body?.dispose();
    _body = null;
    _text?.dispose();
    super.onRemove();
  }

  Picture _ensureBody() {
    final cached = _body;
    if (cached != null && _bodyRevealed == _revealed && _bodySize == size) {
      return cached;
    }
    cached?.dispose();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    if (game.isEaster) {
      _paintEggBody(canvas);
    } else {
      _paintRockBody(canvas);
    }
    if (_revealed) _paintTick(canvas);
    _bodyRevealed = _revealed;
    _bodySize = size.clone();
    return _body = recorder.endRecording();
  }

  Path _eggPath(Rect rect) {
    final cx = rect.center.dx;
    final w = rect.width;
    final h = rect.height;
    final top = rect.top;
    final bottom = rect.bottom;
    return Path()
      ..moveTo(cx, top)
      ..cubicTo(cx + 0.30 * w, top, cx + 0.5 * w, top + 0.30 * h, cx + 0.5 * w,
          top + 0.62 * h)
      ..cubicTo(cx + 0.5 * w, top + 0.85 * h, cx + 0.28 * w, bottom, cx, bottom)
      ..cubicTo(cx - 0.28 * w, bottom, cx - 0.5 * w, top + 0.85 * h,
          cx - 0.5 * w, top + 0.62 * h)
      ..cubicTo(cx - 0.5 * w, top + 0.30 * h, cx - 0.30 * w, top, cx, top)
      ..close();
  }

  void _paintEggBody(Canvas canvas) {
    final rect = size.toRect();
    final path = _eggPath(rect);
    final hsl = HSLColor.fromColor(_eggColor);
    final deep =
        hsl.withLightness((hsl.lightness - 0.22).clamp(0.2, 0.8)).toColor();

    if (_revealed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = WordBlasterPalette.correct.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    // Soft drop shadow, then the shell.
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()..color = const Color(0x14000000),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [Color.lerp(_eggColor, const Color(0xFFFFFFFF), 0.35)!, _eggColor],
        ),
    );
    // Pattern, clipped to the shell.
    canvas.save();
    canvas.clipPath(path);
    final band = Paint()..color = deep.withValues(alpha: 0.75);
    final white = Paint()..color = const Color(0xD9FFFFFF);
    switch (_eggPattern) {
      case 0: // stripes
        canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top + rect.height * 0.62, rect.width,
                rect.height * 0.1),
            band);
        canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top + rect.height * 0.78, rect.width,
                rect.height * 0.06),
            white);
      case 1: // zigzag
        final zig = Path()..moveTo(rect.left, rect.top + rect.height * 0.7);
        final step = rect.width / 6;
        for (var i = 0; i < 6; i++) {
          zig.lineTo(rect.left + step * (i + 0.5),
              rect.top + rect.height * (i.isEven ? 0.78 : 0.66));
          zig.lineTo(rect.left + step * (i + 1), rect.top + rect.height * 0.7);
        }
        canvas.drawPath(
            zig,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = rect.height * 0.045
              ..color = deep.withValues(alpha: 0.85));
      case 2: // dots
        for (var i = 0; i < 7; i++) {
          final dx = rect.left + rect.width * (0.18 + (i % 4) * 0.21);
          final dy = rect.top + rect.height * (i < 4 ? 0.24 : 0.82);
          canvas.drawCircle(Offset(dx, dy), rect.width * 0.045, white);
        }
      default: // wave band
        final wave = Path()..moveTo(rect.left, rect.top + rect.height * 0.28);
        for (var i = 0; i < 4; i++) {
          wave.quadraticBezierTo(
              rect.left + rect.width * (i + 0.5) / 4,
              rect.top + rect.height * (i.isEven ? 0.2 : 0.36),
              rect.left + rect.width * (i + 1) / 4,
              rect.top + rect.height * 0.28);
        }
        canvas.drawPath(
            wave,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = rect.height * 0.05
              ..color = white.color);
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _revealed ? WordBlasterPalette.correct : deep,
    );
    // Shine.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(
              rect.left + rect.width * 0.3, rect.top + rect.height * 0.28),
          width: rect.width * 0.14,
          height: rect.height * 0.22),
      Paint()..color = const Color(0x8CFFFFFF),
    );
  }

  void _paintRockBody(Canvas canvas) {
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

    if (_revealed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = WordBlasterPalette.correct.withValues(alpha: 0.55)
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
            WordBlasterPalette.rockLight,
            WordBlasterPalette.rock,
            WordBlasterPalette.rockDark,
          ],
          [0, 0.55, 1],
        ),
    );
    final crater = Paint()
      ..color = WordBlasterPalette.rockDark.withValues(alpha: 0.45);
    for (final (offset, r) in _craters) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
              center.dx + offset.dx * radiusX, center.dy + offset.dy * radiusY),
          width: r * radiusX * 2,
          height: r * radiusY * 2,
        ),
        crater,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = (_revealed ? WordBlasterPalette.correct : game.palette.accent)
            .withValues(alpha: 0.9),
    );
  }

  void _paintTick(Canvas canvas) {
    final rect = size.toRect();
    final at = game.isEaster
        ? Offset(rect.right - 4, rect.top + rect.height * 0.12)
        : Offset(rect.right - 6, rect.top + 6);
    canvas.drawCircle(
        at, _textFontSize * 0.45, Paint()..color = WordBlasterPalette.correct);
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
    check.paint(canvas, at - Offset(check.width / 2, check.height / 2));
    check.dispose();
  }

  @override
  void render(Canvas canvas) {
    final alpha = _fade.clamp(0.0, 1.0);
    final fading = alpha < 1;
    if (fading) {
      // Only during the short vanish/explode animation.
      _fadePaint.color = Color.fromRGBO(0, 0, 0, alpha);
      canvas.saveLayer(null, _fadePaint);
    }
    canvas.drawPicture(_ensureBody());
    final text = _text;
    if (text != null) {
      final rect = size.toRect();
      canvas.save();
      canvas.translate(rect.center.dx,
          rect.center.dy + (game.isEaster ? rect.height * 0.04 : 0));
      canvas.rotate(-angle);
      // Plate behind the label for contrast.
      _platePaint.color =
          game.isEaster ? const Color(0xE0FFFFFF) : const Color(0x730B1026);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: text.width + _textFontSize * 0.7,
            height: text.height + _textFontSize * 0.3,
          ),
          Radius.circular(_textFontSize * 0.4),
        ),
        _platePaint,
      );
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
    }
    if (fading) canvas.restore();
  }
}

// ─── cannon, projectile, shield ─────────────────────────────────────────────

class CannonComponent extends PositionComponent
    with HasGameReference<WordBlasterGame> {
  CannonComponent() : super(anchor: Anchor.center, priority: 20);

  double _aim = -pi / 2;
  double _recoil = 0;
  double _overheat = 0;

  Vector2 get muzzle => muzzleAt(_aim);

  /// Where the barrel's tip is when pointing along [angle].
  Vector2 muzzleAt(double angle) =>
      position + Vector2(cos(angle), sin(angle)) * (game.size.x * 0.1);

  /// Points the barrel along [angle] (see aimAngle) with a recoil kick.
  void aimAt(double angle) {
    _aim = angle;
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
    final stage = game.stage;
    final heat = Color.lerp(stage.accent, WordBlasterPalette.wrong, _overheat)!;

    canvas.save();
    canvas.rotate(_aim + pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            -barrelWidth / 2, -barrelLength, barrelWidth, barrelLength),
        Radius.circular(barrelWidth / 2),
      ),
      _barrelPaint..color = heat,
    );
    canvas.restore();
    if (_baseShaderRadius != baseR || _shaderChapter != game.chapter) {
      _baseShaderRadius = baseR;
      _shaderChapter = game.chapter;
      _basePaint.shader = Gradient.radial(
        Offset(-baseR * 0.3, -baseR * 0.3),
        baseR * 1.2,
        [stage.shot.colors.first, stage.accent, stage.horizon],
        const [0, 0.5, 1],
      );
    }
    canvas.drawCircle(Offset.zero, baseR, _basePaint);
    canvas.drawCircle(Offset.zero, baseR * 0.45, _hubPaint);
  }

  final Paint _barrelPaint = Paint();
  final Paint _basePaint = Paint();
  final Paint _hubPaint = Paint()
    ..color = WordBlasterPalette.skyTop.withValues(alpha: 0.5);
  double? _baseShaderRadius;
  GameStoryChapter? _shaderChapter;
}

class ProjectileComponent extends Component
    with HasGameReference<WordBlasterGame> {
  ProjectileComponent({required this.from, required this.to, this.onImpact})
      : super(priority: 15);

  static const flightSeconds = 0.16;

  final Vector2 from;

  /// Where the shot ends: the point it hit a meteor, or the field's edge.
  final Vector2 to;
  final void Function()? onImpact;
  final Paint _paint = Paint();
  double _t = 0;
  double _time = 0;

  @override
  void update(double dt) {
    _t += dt / flightSeconds;
    _time += dt;
    if (_t >= 1) {
      onImpact?.call();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    paintStoryShot(canvas, Offset(from.x, from.y), Offset(to.x, to.y),
        min(1, _t), game.stage.shot, game.size.x, _time, _paint);
  }
}

/// The whole play field as one touch target: where the learner touches sets
/// the direction of the shot. Below every other component, so a power-up
/// under the finger is still collected instead.
class AimSurface extends PositionComponent
    with TapCallbacks, HasGameReference<WordBlasterGame> {
  AimSurface() : super(priority: -1);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void onTapDown(TapDownEvent event) => game.fireToward(event.canvasPosition);
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
    _paint.color = color.withValues(alpha: 0.25);
    canvas.drawCircle(c, r * 1.25, _paint);
    _paint.color = color;
    canvas.drawCircle(c, r, _paint);
    // Laid out once at the base radius; the pulse just scales it.
    final baseR = size.x / 2;
    final icon = iconFor(state.kind);
    final painter = _icon ??= TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: baseR * 1.1,
          color: WordBlasterPalette.skyTop,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r / baseR);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  final Paint _paint = Paint();
  TextPainter? _icon;

  @override
  void onRemove() {
    _icon?.dispose();
    _icon = null;
    super.onRemove();
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
    _layerPaint.color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
    canvas.saveLayer(null, _layerPaint);
    _painter!
        .paint(canvas, Offset(-_painter!.width / 2, -_painter!.height / 2));
    canvas.restore();
  }

  final Paint _layerPaint = Paint();

  @override
  void onRemove() {
    _painter?.dispose();
    _painter = null;
    super.onRemove();
  }
}

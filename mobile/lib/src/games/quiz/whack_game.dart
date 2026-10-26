import 'dart:math';

import 'package:flutter/material.dart';

import '../common/game_audio.dart';
import '../common/game_story.dart';
import '../common/game_story_scene.dart';
import '../common/game_theme.dart';
import 'quiz_game_context.dart';
import 'quiz_core.dart';
import 'quiz_round.dart';
import 'quiz_screens.dart';
import 'quiz_ui.dart';
import '../common/game_activity.dart';

class Mole {
  Mole({required this.value, required this.upFor, required this.id});

  final int id;
  final String value;
  final double upFor;
  double age = 0;
  bool hit = false;

  static const popSeconds = 0.15;

  bool get gone => age >= upFor + popSeconds * 2;

  /// 0 = hidden in the hole, 1 = fully up.
  double get raised {
    if (age < popSeconds) return age / popSeconds;
    final down = age - upFor - popSeconds;
    if (down > 0) return max(0, 1 - down / popSeconds);
    return 1;
  }
}

enum WhackOutcome { correct, wrong, none }

/// Whack-a-Number rules: a problem is shown; moles pop up holding numbers and
/// the child whacks the one with the answer. Wrong whacks cost 2 seconds. A
/// 60-second round; moles stay up for less time as the streak grows.
class WhackSession {
  WhackSession({required this.log, Random? random})
      : random = random ?? Random() {
    _nextProblem();
  }

  static const holeCount = 9;
  static const roundSeconds = 60.0;
  static const wrongPenaltySeconds = 2.0;

  final QuizRoundLog log;
  final Random random;
  final List<Mole?> holes = List.filled(holeCount, null);
  late QuizItem problem;
  late List<String> _options;
  double timeLeft = roundSeconds;
  double clock = 0;
  double _askedAt = 0;
  double _spawnTimer = 0;
  int _nextId = 0;

  bool get isOver => timeLeft <= 0;

  /// Every 5 answers whacked opens the next story chapter.
  GameStoryChapter get chapter =>
      GameStoryChapter.forProgress(log.correctCount, 5);

  /// How long a mole stays up: shorter as the child streaks.
  double get upSeconds {
    final base = 1.2 + log.level.targetSeconds * 0.35;
    return max(0.9, base - log.combo * 0.08);
  }

  void update(double dt) {
    if (isOver) return;
    clock += dt;
    timeLeft = max(0, timeLeft - dt);
    for (var i = 0; i < holes.length; i++) {
      final mole = holes[i];
      if (mole == null) continue;
      mole.age += dt;
      if (mole.gone) holes[i] = null;
    }
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) _spawn();
  }

  WhackOutcome whack(int hole) {
    final mole = holes[hole];
    if (isOver || mole == null || mole.hit || mole.raised < 0.5) {
      return WhackOutcome.none;
    }
    mole.hit = true;
    mole.age = max(mole.age, mole.upFor + Mole.popSeconds); // duck down
    final elapsed = Duration(milliseconds: ((clock - _askedAt) * 1000).round());
    final correct = mole.value == problem.answerText;
    log.submit(problem, correct: correct, elapsed: elapsed, given: mole.value);
    if (!correct) {
      timeLeft = max(0, timeLeft - wrongPenaltySeconds);
      return WhackOutcome.wrong;
    }
    _nextProblem();
    return WhackOutcome.correct;
  }

  void _nextProblem() {
    problem = log.generator.next();
    _options = log.generator.choicesFor(problem, count: 5);
    _askedAt = clock;
    // Clear the field so old numbers cannot be whacked for the new problem.
    for (var i = 0; i < holes.length; i++) {
      final mole = holes[i];
      if (mole != null && !mole.hit) {
        mole.age = max(mole.age, mole.upFor + Mole.popSeconds);
      }
    }
    _spawnTimer = 0.25;
  }

  void _spawn() {
    _spawnTimer = 0.35 + random.nextDouble() * 0.3;
    final up = holes.where((m) => m != null && !m.hit).toList();
    if (up.length >= 4) return;
    final free = [
      for (var i = 0; i < holes.length; i++)
        if (holes[i] == null) i,
    ];
    if (free.isEmpty) return;
    final answerUp = up.any((m) => m!.value == problem.answerText);
    final value = !answerUp && random.nextDouble() < 0.45
        ? problem.answerText
        : _options[random.nextInt(_options.length)];
    if (value == problem.answerText && answerUp) return;
    holes[free[random.nextInt(free.length)]] =
        Mole(id: _nextId++, value: value, upFor: upSeconds);
  }
}

class WhackScreen extends StatefulWidget {
  const WhackScreen({
    required this.context,
    required this.game,
    required this.level,
    required this.theme,
    super.key,
  });

  final QuizGameContext context;
  final QuizGameKind game;
  final QuizLevel level;
  final GameVisualTheme theme;

  @override
  State<WhackScreen> createState() => _WhackScreenState();
}

class _WhackScreenState extends State<WhackScreen>
    with SingleTickerProviderStateMixin, GameActivityScope<WhackScreen> {
  late final GameLoop _loop = GameLoop(this, _tick);
  late final WhackSession _session;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  int _secondsShown = WhackSession.roundSeconds.ceil();
  bool _finished = false;
  bool? _flash;

  QuizGameContext get _ctx => widget.context;
  late final GameStoryDriver _story = _ctx.storyDriver(widget.theme);
  final StoryEffects _fx = StoryEffects();
  double _gridWidth = 0;

  /// Centre of [hole] in the grid (3 square cells, 8 px apart).
  Offset _holeCenter(int hole) {
    final cell = (_gridWidth - 16) / 3;
    return Offset((hole % 3) * (cell + 8) + cell / 2,
        (hole ~/ 3) * (cell + 8) + cell * 0.55);
  }

  @override
  void initState() {
    super.initState();
    _session = WhackSession(
      log: _ctx.roundLog(widget.level),
      random: _ctx.randomFactory(),
    );
    _story.start();
    _loop.start();
  }

  @override
  void dispose() {
    _loop.dispose();
    _frame.dispose();
    _ctx.audio.stopMusic();
    super.dispose();
  }

  void _tick(double dt) {
    _session.update(dt);
    _fx.update(dt);
    if (_session.isOver) {
      _finish();
      return;
    }
    if (_session.timeLeft.ceil() != _secondsShown) {
      setState(() => _secondsShown = _session.timeLeft.ceil());
    }
    _frame.value++;
  }

  void _whack(int hole) {
    final outcome = _session.whack(hole);
    if (outcome == WhackOutcome.none) return;
    if (outcome == WhackOutcome.correct) {
      _ctx.audio.play(GameSound.shotFor(_story.chapter));
      _ctx.audio.haptic(GameHaptic.light);
      _fx.burst(_holeCenter(hole), _story.stage.shot);
      _story.reach(_session.chapter);
    } else {
      _ctx.audio.play(GameSound.wrong);
      _ctx.audio.haptic(GameHaptic.medium);
    }
    setState(() {
      _flash = outcome == WhackOutcome.correct;
      _secondsShown = _session.timeLeft.ceil();
    });
  }

  Future<void> _pause() async {
    _loop.stop();
    final quit = await showGamePause(context);
    if (!mounted) return;
    quit ? _finish() : _loop.start();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _loop.stop();
    _ctx.audio.play(GameSound.gameOver);
    final log = _session.log;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => QuizResultScreen(
        context: _ctx,
        game: widget.game,
        level: widget.level,
        headline: 'Time\'s up!',
        detail: '${log.correctCount} answers whacked',
        logs: [log],
        replay: (_) => WhackScreen(
            context: _ctx,
            game: widget.game,
            level: widget.level,
            theme: widget.theme),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(widget.theme, chapter: _story.chapter);
    final flash = _flash;
    return Scaffold(
      backgroundColor: palette.skyTop,
      body: SafeArea(
        child: QuizBackdrop(
          theme: widget.theme,
          chapter: _story.chapter,
          child: Column(
            children: [
              QuizHud(
                theme: widget.theme,
                chapter: _story.chapter,
                score: _session.log.score,
                secondsLeft: _secondsShown,
                combo: _session.log.combo,
                onPause: _pause,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: 3,
                    color: flash == null
                        ? palette.accent
                        : flash
                            ? palette.good
                            : palette.bad,
                  ),
                ),
                child: QuizPromptText(_session.problem.text,
                    key: const ValueKey('whack-problem'),
                    color: palette.onPanel),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 0.9,
                      child: LayoutBuilder(builder: (context, box) {
                        _gridWidth = box.maxWidth;
                        return Stack(children: [
                          GridView.count(
                            crossAxisCount: 3,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: [
                              for (var i = 0; i < WhackSession.holeCount; i++)
                                GestureDetector(
                                  key: ValueKey('whack-hole-$i'),
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (_) => _whack(i),
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _frame,
                                    builder: (context, _, __) => _Hole(
                                      mole: _session.holes[i],
                                      theme: widget.theme,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                  painter: StoryEffectsPainter(_fx,
                                      repaint: _frame)),
                            ),
                          ),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hole extends StatelessWidget {
  const _Hole({required this.mole, required this.theme});

  final Mole? mole;
  final GameVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    final easter = theme == GameVisualTheme.easter;
    final palette = QuizPalette.of(theme);
    final m = mole;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final holeH = w * 0.32;
      final moleW = w * 0.74;
      final moleH = easter ? moleW * 1.2 : moleW;
      final raised = m?.raised ?? 0;
      return Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.bottomCenter,
        children: [
          // The mole rises out of the hole (clipped by the bottom area).
          if (m != null)
            Positioned(
              bottom: holeH * 0.45 - moleH * (1 - raised),
              child: Opacity(
                opacity: m.hit ? 0.5 : 1,
                child: SizedBox(
                  width: moleW,
                  height: moleH,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _MolePainter(theme, m.id),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: moleH * 0.2),
                          child: FittedBox(
                            child: Text(
                              '${m.value}',
                              key: ValueKey('whack-value-${m.value}'),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: easter ? palette.text : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Front lip of the hole/nest covers the mole's lower part.
          IgnorePointer(
            child: SizedBox(
              width: w,
              height: holeH,
              child: CustomPaint(painter: _HolePainter(theme)),
            ),
          ),
        ],
      );
    });
  }
}

class _HolePainter extends CustomPainter {
  _HolePainter(this.theme);

  final GameVisualTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final easter = theme == GameVisualTheme.easter;
    final rect =
        Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.8);
    canvas.drawOval(
        rect,
        Paint()
          ..color = easter ? const Color(0xFF8B5E34) : const Color(0xFF0F172A));
    canvas.drawOval(
        rect.deflate(size.height * 0.12),
        Paint()
          ..color = easter ? const Color(0xFFC08A4A) : const Color(0xFF334155));
    if (easter) {
      final straw = Paint()
        ..color = const Color(0xFFE9C46A)
        ..strokeWidth = 2;
      for (var i = 0; i < 9; i++) {
        final x = rect.left + rect.width * (0.1 + i * 0.1);
        canvas.drawLine(
            Offset(x, rect.top + 4), Offset(x + 8, rect.bottom - 6), straw);
      }
    }
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.theme != theme;
}

class _MolePainter extends CustomPainter {
  _MolePainter(this.theme, this.seed);

  final GameVisualTheme theme;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (theme == GameVisualTheme.easter) {
      final base = easterEggColors[seed % easterEggColors.length];
      canvas.drawPath(
          eggPath(rect),
          Paint()
            ..shader = LinearGradient(
              colors: [Color.lerp(base, Colors.white, 0.4)!, base],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect));
      canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.25),
          size.width * 0.06, Paint()..color = Colors.white70);
      return;
    }
    // Friendly green alien with two eyes.
    final body =
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.45));
    canvas.drawRRect(body, Paint()..color = const Color(0xFF22C55E));
    final eye = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF0B1026);
    for (final dx in [0.32, 0.68]) {
      final c = Offset(size.width * dx, size.height * 0.24);
      canvas.drawCircle(c, size.width * 0.11, eye);
      canvas.drawCircle(c, size.width * 0.05, pupil);
    }
  }

  @override
  bool shouldRepaint(_MolePainter old) =>
      old.theme != theme || old.seed != seed;
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../common/game_audio.dart';
import '../common/game_story.dart';
import '../common/game_theme.dart';
import '../quiz/quiz_game_context.dart';
import 'math_problem.dart';
import 'math_round.dart';
import '../quiz/quiz_screens.dart';
import '../quiz/quiz_ui.dart';
import '../common/game_activity.dart';

enum RaceAnswer { correct, nitro, wrong }

/// Math Race rules: the child types each result (no options to guess from).
/// A correct answer moves the car forward (further when fast); three fast
/// answers in a row fire a nitro. Two computer cars drive at a steady pace
/// tuned to the level, so winning means computing quickly and accurately.
class RaceSession {
  RaceSession({required this.log}) {
    problem = log.generator.next();
  }

  /// Correct answers needed to finish at the base step.
  static const answersToFinish = 12;

  final MathRoundLog log;
  late MathProblem problem;
  double player = 0;
  final List<double> bots = [0, 0];
  final List<double> botFinishTimes = [];
  double clock = 0;
  double _askedAt = 0;
  int _fastStreak = 0;
  double nitroLeft = 0;

  bool get finished => player >= 1;

  /// The track crosses the five story chapters; each fifth opens the next.
  GameStoryChapter get chapter =>
      GameStoryChapter.forLevel(1 + (player * 5).floor());

  /// Seconds each computer car needs for the whole track: one a bit slower
  /// and one right at the level's fluent pace.
  List<double> get botLapSeconds {
    final pace = answersToFinish * log.level.targetSeconds.toDouble();
    return [pace * 1.35, pace * 1.0];
  }

  /// 1-based finishing position (call after [finished]).
  int get position => 1 + botFinishTimes.length;

  void update(double dt) {
    if (finished) return;
    clock += dt;
    for (var i = 0; i < bots.length; i++) {
      if (bots[i] >= 1) continue;
      bots[i] += dt / botLapSeconds[i];
      if (bots[i] >= 1) {
        bots[i] = 1;
        botFinishTimes.add(clock);
      }
    }
    if (nitroLeft > 0) {
      final burn = min(nitroLeft, dt);
      nitroLeft -= burn;
      player = min(1, player + burn * 0.6 / answersToFinish);
    }
  }

  RaceAnswer submit(int value) {
    final elapsed = Duration(milliseconds: ((clock - _askedAt) * 1000).round());
    final correct = value == problem.answer;
    log.submit(problem, correct: correct, elapsed: elapsed, given: '$value');
    if (!correct) {
      _fastStreak = 0;
      return RaceAnswer.wrong;
    }
    final fast = elapsed.inMilliseconds < log.level.targetSeconds * 1000;
    final speedBonus =
        (1 - elapsed.inMilliseconds / (log.level.targetSeconds * 2000))
            .clamp(0.0, 1.0);
    player = min(1, player + (1 + 0.5 * speedBonus) / answersToFinish);
    _fastStreak = fast ? _fastStreak + 1 : 0;
    var result = RaceAnswer.correct;
    if (_fastStreak >= 3) {
      _fastStreak = 0;
      nitroLeft = 2;
      result = RaceAnswer.nitro;
    }
    problem = log.generator.next();
    _askedAt = clock;
    return result;
  }

  /// Bonus for the finishing place, added to the answer points.
  int get placeBonus => switch (position) { 1 => 100, 2 => 50, _ => 0 };
}

class MathRaceScreen extends StatefulWidget {
  const MathRaceScreen({
    required this.context,
    required this.level,
    required this.theme,
    super.key,
  });

  final QuizGameContext context;
  final MathLevel level;
  final GameVisualTheme theme;

  @override
  State<MathRaceScreen> createState() => _MathRaceScreenState();
}

class _MathRaceScreenState extends State<MathRaceScreen>
    with SingleTickerProviderStateMixin, GameActivityScope<MathRaceScreen> {
  late final GameLoop _loop = GameLoop(this, _tick);
  late final RaceSession _race;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  String _input = '';
  bool? _lastCorrect;
  bool _finished = false;

  QuizGameContext get _ctx => widget.context;
  late final GameStoryDriver _story = _ctx.storyDriver(widget.theme);

  @override
  void initState() {
    super.initState();
    _race = RaceSession(
      log: _ctx.mathRoundLog(widget.level),
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
    final botsDone = _race.botFinishTimes.length;
    _race.update(dt);
    if (_race.botFinishTimes.length != botsDone) setState(() {});
    _frame.value++;
  }

  void _digit(int d) {
    if (_input.replaceFirst('-', '').length >= 6) return;
    _ctx.audio.haptic(GameHaptic.selection);
    setState(() => _input = _input == '0'
        ? '$d'
        : _input == '-0'
            ? '-$d'
            : '$_input$d');
  }

  void _toggleSign() {
    _ctx.audio.haptic(GameHaptic.selection);
    setState(() =>
        _input = _input.startsWith('-') ? _input.substring(1) : '-$_input');
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    final value = int.tryParse(_input);
    if (value == null || _finished) return;
    final result = _race.submit(value);
    _story.reach(_race.chapter);
    switch (result) {
      case RaceAnswer.correct:
        _ctx.audio.play(GameSound.hit);
      case RaceAnswer.nitro:
        _ctx.audio.play(GameSound.powerUp);
        _ctx.audio.haptic(GameHaptic.medium);
      case RaceAnswer.wrong:
        _ctx.audio.play(GameSound.wrong);
        _ctx.audio.haptic(GameHaptic.medium);
    }
    setState(() {
      _lastCorrect = result != RaceAnswer.wrong;
      // Keep a wrong answer visible so the child can fix it.
      if (result != RaceAnswer.wrong) _input = '';
    });
    if (_race.finished) _finish();
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
    final log = _race.log;
    if (_race.finished) {
      log.score += _race.placeBonus;
      _ctx.audio
          .play(_race.position == 1 ? GameSound.solved : GameSound.gameOver);
    }
    final place = _race.position;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => QuizResultScreen(
        context: _ctx,
        game: QuizGameKind.race,
        level: widget.level,
        headline: !_race.finished
            ? 'Race stopped'
            : place == 1
                ? 'You won the race!'
                : 'You finished #$place',
        detail: _race.finished ? 'Place bonus +${_race.placeBonus}' : null,
        logs: [log],
        replay: (_) => MathRaceScreen(
            context: _ctx, level: widget.level, theme: widget.theme),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(widget.theme, chapter: _story.chapter);
    final feedback = _lastCorrect;
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
                score: _race.log.score,
                combo: _race.log.combo,
                onPause: _pause,
                extra: '${_race.log.correctCount} ✓',
              ),
              SizedBox(
                height: 190,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _TrackPainter(
                        _race, widget.theme, _story.stage, _frame),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                key: const ValueKey('race-problem'),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: 3,
                    color: feedback == null
                        ? palette.accent
                        : feedback
                            ? palette.good
                            : palette.bad,
                  ),
                ),
                child: FittedBox(
                  child: Text(
                    _raceLine(_race.problem.text,
                        _input.isEmpty ? '?' : _input.replaceFirst('-', '−')),
                    style: TextStyle(
                      color: palette.onPanel,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (feedback == false)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Not quite, try again!',
                      style: TextStyle(
                          color: palette.bad, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: MathKeypad(
                  theme: widget.theme,
                  chapter: _story.chapter,
                  onDigit: _digit,
                  onBackspace: _backspace,
                  onSubmit: _submit,
                  onToggleSign: _toggleSign,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three lanes, a chequered finish and the cars. Repaints from [repaint]
/// without rebuilding any widget; paints are created once.
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.race, this.theme, this.stage, Listenable repaint)
      : super(repaint: repaint) {
    final easter = theme == GameVisualTheme.easter;
    // Nitro burns in the chapter's weapon colours.
    _flame.color = stage.shot.colors.length > 1
        ? stage.shot.colors[1]
        : stage.shot.colors.first;
    _road.color = easter ? const Color(0xFFFFE8A3) : const Color(0xFF26304F);
    _lane.color = easter ? Colors.white : const Color(0x66FFFFFF);
    _carColors = easter
        ? const [Color(0xFFFF8FAB), Color(0xFF9AD0F5), Color(0xFFC4A7F5)]
        : const [Color(0xFFFFC857), Color(0xFF7DD3FC), Color(0xFFFF5C7A)];
  }

  final RaceSession race;
  final GameVisualTheme theme;
  final StoryStage stage;
  final Paint _road = Paint();
  final Paint _lane = Paint()..strokeWidth = 2;
  final Paint _car = Paint();
  final Paint _wheel = Paint()..color = const Color(0xFF111827);
  final Paint _flame = Paint();
  final Paint _check = Paint();
  late final List<Color> _carColors;

  @override
  void paint(Canvas canvas, Size size) {
    final laneH = (size.height - 20) / 3;
    final left = 12.0, right = size.width - 28;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(4, 6, size.width - 8, laneH * 3 + 8),
            const Radius.circular(16)),
        _road);
    for (var i = 1; i < 3; i++) {
      final y = 10 + laneH * i;
      for (var x = left; x < right; x += 22) {
        canvas.drawLine(Offset(x, y), Offset(x + 11, y), _lane);
      }
    }
    // Chequered finish line.
    for (var row = 0; row < (laneH * 3 / 8).floor(); row++) {
      for (var col = 0; col < 2; col++) {
        _check.color = (row + col).isEven ? Colors.white : Colors.black;
        canvas.drawRect(
            Rect.fromLTWH(right + 4 + col * 8, 10 + row * 8.0, 8, 8), _check);
      }
    }
    final positions = [race.player, ...race.bots];
    for (var i = 0; i < positions.length; i++) {
      final x = left + positions[i].clamp(0.0, 1.0) * (right - left - 44);
      final y = 10 + laneH * i + laneH / 2;
      _drawCar(canvas, Offset(x, y), _carColors[i], laneH,
          boosting: i == 0 && race.nitroLeft > 0, isPlayer: i == 0);
    }
  }

  void _drawCar(Canvas canvas, Offset at, Color color, double laneH,
      {required bool boosting, required bool isPlayer}) {
    final h = min(28.0, laneH * 0.55), w = h * 1.7;
    if (boosting) {
      canvas.drawOval(
          Rect.fromCenter(
              center: at + const Offset(-6, 0),
              width: w * 0.6,
              height: h * 0.5),
          _flame);
    }
    _car.color = color;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx, at.dy - h / 2, w, h * 0.75),
        Radius.circular(h * 0.35));
    canvas.drawRRect(body, _car);
    if (isPlayer) {
      _car.color = Colors.white;
      canvas.drawCircle(at + Offset(w * 0.62, -h * 0.12), h * 0.16, _car);
    }
    canvas.drawCircle(at + Offset(w * 0.25, h * 0.3), h * 0.18, _wheel);
    canvas.drawCircle(at + Offset(w * 0.78, h * 0.3), h * 0.18, _wheel);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.race != race || old.theme != theme || old.stage != stage;
}

/// "7 + 8 = 15", or the answer on its own line when the problem already
/// asks a question ("3x − 5 = 16, x = ?").
String _raceLine(String problem, String answer) =>
    problem.contains('?') ? '$problem\n$answer' : '$problem = $answer';

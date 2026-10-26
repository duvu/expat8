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

class FallingProblem {
  FallingProblem({
    required this.id,
    required this.problem,
    required this.choices,
    required this.x,
    required this.spawnedAt,
  });

  final int id;
  final QuizItem problem;
  final List<String> choices;
  final double x;
  final double spawnedAt;
  double y = 0;
}

enum BlasterOutcome { correct, wrong, landed, gameOver }

/// Number Blaster rules: problems fall; the lowest one is the target and its
/// answer options are shown. Correct answers score (faster = more), a wrong
/// pick pushes the target down, a landed problem costs a life. Speed and the
/// number of problems on screen grow as the child gets them right.
class BlasterSession {
  BlasterSession({required this.log, Random? random})
      : random = random ?? Random();

  static const startingLives = 3;

  final QuizRoundLog log;
  final Random random;
  final List<FallingProblem> falling = [];
  int lives = startingLives;
  double clock = 0;
  double _spawnTimer = 0;
  int _nextId = 0;
  bool get isOver => lives <= 0;

  /// Seconds for a problem to fall the whole field.
  double get fallSeconds {
    final base = log.level.targetSeconds * 2.6;
    final speedUp = pow(0.95, log.correctCount ~/ 4).toDouble();
    return max(log.level.targetSeconds * 1.3, base * speedUp);
  }

  int get maxOnScreen => min(3, 1 + log.correctCount ~/ 6);

  /// Every 6 problems blasted opens the next story chapter.
  GameStoryChapter get chapter =>
      GameStoryChapter.forProgress(log.correctCount, 6);

  FallingProblem? get target =>
      falling.isEmpty ? null : falling.reduce((a, b) => a.y >= b.y ? a : b);

  void start() => _spawn();

  /// Advances time; returns problems that landed this frame.
  List<BlasterOutcome> update(double dt) {
    if (isOver) return const [];
    clock += dt;
    final outcomes = <BlasterOutcome>[];
    for (final item in List.of(falling)) {
      item.y += dt / fallSeconds;
      if (item.y >= 1) {
        falling.remove(item);
        lives--;
        log.submit(item.problem, correct: false, elapsed: _elapsedFor(item));
        outcomes
            .add(lives <= 0 ? BlasterOutcome.gameOver : BlasterOutcome.landed);
        if (lives <= 0) return outcomes;
      }
    }
    _spawnTimer -= dt;
    if (falling.isEmpty || (falling.length < maxOnScreen && _spawnTimer <= 0)) {
      _spawn();
    }
    return outcomes;
  }

  /// The child picked [value] for the current target.
  (BlasterOutcome, int points) answer(String value) {
    final item = target;
    if (item == null || isOver) return (BlasterOutcome.wrong, 0);
    final correct = value == item.problem.answerText;
    final points = log.submit(item.problem,
        correct: correct, elapsed: _elapsedFor(item), given: value);
    if (correct) {
      falling.remove(item);
      if (falling.isEmpty) _spawn();
      return (BlasterOutcome.correct, points);
    }
    item.y = min(0.97, item.y + 0.12);
    return (BlasterOutcome.wrong, 0);
  }

  Duration _elapsedFor(FallingProblem item) =>
      Duration(milliseconds: ((clock - item.spawnedAt) * 1000).round());

  void _spawn() {
    final problem = log.generator.next();
    final usedLanes = falling.map((f) => f.x).toSet();
    var x = 0.2 + random.nextDouble() * 0.6;
    for (var attempt = 0;
        attempt < 6 && usedLanes.any((u) => (u - x).abs() < 0.25);
        attempt++) {
      x = 0.15 + random.nextDouble() * 0.7;
    }
    falling.add(FallingProblem(
      id: _nextId++,
      problem: problem,
      choices: log.generator.choicesFor(problem),
      x: x,
      spawnedAt: clock,
    ));
    _spawnTimer = fallSeconds / (maxOnScreen + 0.5);
  }
}

class BlasterScreen extends StatefulWidget {
  const BlasterScreen({
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
  State<BlasterScreen> createState() => _BlasterScreenState();
}

class _BlasterScreenState extends State<BlasterScreen>
    with SingleTickerProviderStateMixin, GameActivityScope<BlasterScreen> {
  late final GameLoop _loop = GameLoop(this, _tick);
  late final BlasterSession _session;
  final List<_Pop> _pops = [];
  late final GameStoryDriver _story = _ctx.storyDriver(widget.theme);
  final StoryEffects _fx = StoryEffects();
  BoxConstraints _fieldBox = const BoxConstraints();
  bool _finished = false;

  /// Bumped every frame; only the falling layer listens to it, so the HUD and
  /// answer buttons rebuild only when something they show changes.
  final ValueNotifier<int> _frame = ValueNotifier(0);

  QuizGameContext get _ctx => widget.context;

  @override
  void initState() {
    super.initState();
    _session = BlasterSession(
      log: _ctx.roundLog(widget.level),
      random: _ctx.randomFactory(),
    )..start();
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
    final outcomes = _session.update(dt);
    _fx.update(dt);
    _pops.removeWhere((p) => (p.age += dt) > 0.7);
    for (final o in outcomes) {
      _ctx.audio.play(GameSound.wrong);
      _ctx.audio.haptic(GameHaptic.heavy);
      if (o == BlasterOutcome.gameOver) {
        _finish();
        return;
      }
    }
    if (outcomes.isNotEmpty || _targetId != _session.target?.id) {
      _targetId = _session.target?.id;
      setState(() {});
    }
    _frame.value++;
  }

  int? _targetId;

  void _answer(String value) {
    final target = _session.target;
    if (target == null || _finished) return;
    final (outcome, points) = _session.answer(value);
    if (outcome == BlasterOutcome.correct) {
      _ctx.audio.play(GameSound.shotFor(_story.chapter));
      _ctx.audio.haptic(GameHaptic.light);
      _fx.fire(_cannonMuzzle(), _centerOf(target), _story.stage.shot);
      _pops.add(_Pop('+$points', target.x, target.y));
      _story.reach(_session.chapter);
    } else {
      _ctx.audio.play(GameSound.wrong);
      _ctx.audio.haptic(GameHaptic.medium);
    }
    setState(() {});
  }

  double get _tokenWidth => min(150.0, _fieldBox.maxWidth * 0.34);

  Offset _cannonMuzzle() =>
      Offset(_fieldBox.maxWidth / 2, _fieldBox.maxHeight - 40);

  Offset _centerOf(FallingProblem item) {
    final w = _tokenWidth;
    final left = (item.x * _fieldBox.maxWidth - w / 2)
        .clamp(0.0, max(0.0, _fieldBox.maxWidth - w));
    final top = item.y * (_fieldBox.maxHeight - w * 0.9);
    final height = QuizToken(theme: widget.theme, label: '', width: w).height;
    return Offset(left + w / 2, top + height / 2);
  }

  Future<void> _pause() async {
    _loop.stop();
    final quit = await showGamePause(context);
    if (!mounted) return;
    if (quit) {
      _finish();
    } else {
      _loop.start();
    }
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
        headline: 'Game over',
        detail: '${log.correctCount} problems blasted',
        logs: [log],
        replay: (_) => BlasterScreen(
            context: _ctx,
            game: widget.game,
            level: widget.level,
            theme: widget.theme),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _story.chapter;
    final palette = QuizPalette.of(widget.theme, chapter: chapter);
    final target = _session.target;
    return Scaffold(
      backgroundColor: palette.skyTop,
      body: SafeArea(
        child: QuizBackdrop(
          theme: widget.theme,
          chapter: chapter,
          child: Column(
            children: [
              QuizHud(
                theme: widget.theme,
                chapter: chapter,
                score: _session.log.score,
                lives: _session.lives,
                combo: _session.log.combo,
                onPause: _pause,
              ),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, __) => _field(palette),
                ),
              ),
              // Sentences are too long for a token: the target's full text
              // is read here (math facts already fit on the token).
              if (target != null && target.problem.text != target.problem.cue)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.accent, width: 2),
                  ),
                  child: QuizPromptText(target.problem.text,
                      key: const ValueKey('blaster-prompt'),
                      color: palette.onPanel),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: QuizChoiceButtons(
                  theme: widget.theme,
                  chapter: chapter,
                  choices: target?.choices ?? const [],
                  onPick: _answer,
                  keyPrefix: 'blaster-choice',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(QuizPalette palette) {
    final target = _session.target;
    return LayoutBuilder(builder: (context, box) {
      _fieldBox = box;
      final tokenWidth = _tokenWidth;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            left: box.maxWidth / 2 - 28,
            child: StoryCannon(theme: widget.theme, chapter: _story.chapter),
          ),
          for (final item in _session.falling)
            _place(
              box,
              item.x,
              item.y,
              tokenWidth,
              QuizToken(
                key: ValueKey('blaster-item-${item.id}'),
                theme: widget.theme,
                label: item.problem.cue,
                width: tokenWidth,
                seed: item.id,
                highlight: identical(item, target),
              ),
            ),
          for (final pop in _pops)
            _place(
              box,
              pop.x,
              pop.y - pop.age * 0.15,
              80,
              Opacity(
                opacity: (1 - pop.age / 0.7).clamp(0.0, 1.0),
                child: Text(pop.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: palette.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                  painter: StoryEffectsPainter(_fx, repaint: _frame)),
            ),
          ),
        ],
      );
    });
  }

  Widget _place(
          BoxConstraints box, double x, double y, double width, Widget child) =>
      Positioned(
        left: (x * box.maxWidth - width / 2).clamp(0.0, box.maxWidth - width),
        top: y * (box.maxHeight - width * 0.9),
        width: width,
        child: child,
      );
}

class _Pop {
  _Pop(this.text, this.x, this.y);

  final String text;
  final double x;
  final double y;
  double age = 0;
}

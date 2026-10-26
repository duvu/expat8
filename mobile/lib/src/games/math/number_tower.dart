import 'dart:math';

import 'package:flutter/material.dart';

import '../common/game_audio.dart';
import '../common/game_story.dart';
import '../common/game_story_scene.dart';
import '../common/game_theme.dart';
import '../quiz/quiz_game_context.dart';
import 'math_problem.dart';
import 'math_secondary.dart';
import 'math_round.dart';
import '../quiz/quiz_screens.dart';
import '../quiz/quiz_ui.dart';
import '../common/game_activity.dart';

/// How a level builds its targets.
class TowerRules {
  const TowerRules({
    required this.product,
    required this.minBlock,
    required this.maxBlock,
    required this.minTarget,
    required this.maxTarget,
    this.signed = false,
  });

  factory TowerRules.of(MathLevel level) => switch (level) {
        // Number bonds to 10 and beyond.
        MathLevel.grade1 => const TowerRules(
            product: false,
            minBlock: 1,
            maxBlock: 9,
            minTarget: 5,
            maxTarget: 18),
        MathLevel.grade2 => const TowerRules(
            product: false,
            minBlock: 3,
            maxBlock: 45,
            minTarget: 20,
            maxTarget: 90),
        // Times tables: pick two factors of the target.
        MathLevel.grade3 => const TowerRules(
            product: true,
            minBlock: 2,
            maxBlock: 9,
            minTarget: 4,
            maxTarget: 81),
        // Complements to 100 and bigger sums.
        MathLevel.grade4 => const TowerRules(
            product: false,
            minBlock: 5,
            maxBlock: 95,
            minTarget: 50,
            maxTarget: 100),
        MathLevel.grade5 => const TowerRules(
            product: true,
            minBlock: 2,
            maxBlock: 25,
            minTarget: 12,
            maxTarget: 400),

        // Times tables to 12 × 12.
        MathLevel.grade6 => const TowerRules(
            product: true,
            minBlock: 2,
            maxBlock: 12,
            minTarget: 4,
            maxTarget: 144),
        // Adding negative numbers.
        MathLevel.grade7 => const TowerRules(
            product: false,
            signed: true,
            minBlock: -12,
            maxBlock: 12,
            minTarget: -20,
            maxTarget: 20),
        // Sign rules for multiplication.
        MathLevel.grade8 => const TowerRules(
            product: true,
            signed: true,
            minBlock: -9,
            maxBlock: 9,
            minTarget: -81,
            maxTarget: 81),
        MathLevel.grade9 => const TowerRules(
            product: false,
            signed: true,
            minBlock: -50,
            maxBlock: 50,
            minTarget: -80,
            maxTarget: 80),
      };

  /// true: choose two blocks whose product is the target; false: blocks that
  /// add up to it (two or more).
  final bool product;
  final int minBlock;
  final int maxBlock;
  final int minTarget;
  final int maxTarget;

  /// Blocks and targets may be negative (grades 7-9).
  final bool signed;

  /// Exactly two blocks: products, and sums once negatives make "going over"
  /// meaningless.
  bool get pairsOnly => product || signed;

  String get symbol => product ? '×' : '+';
}

class TowerBlock {
  TowerBlock(this.id, this.value);

  final int id;
  final int value;

  /// 0 when it starts dropping in, 1 once it has landed (animation only).
  double landed = 0;
}

enum TowerOutcome { selected, deselected, cleared, wrong, none }

/// Number Tower rules: blocks keep dropping into five columns; the child taps
/// blocks to make the target (sum, or product of two). Overshooting or a
/// wrong product clears the selection and counts as a miss. A column reaching
/// the top ends the game. The target is always makeable from the board.
class TowerSession {
  TowerSession({required this.log, Random? random})
      : random = random ?? Random(),
        rules = TowerRules.of(log.level) {
    for (var i = 0; i < 8; i++) {
      _drop(_randomValue(), instant: true);
    }
    _newTarget();
  }

  static const columnsCount = 5;
  static const rows = 8;

  final MathRoundLog log;
  final Random random;
  final TowerRules rules;
  final List<List<TowerBlock>> columns =
      List.generate(columnsCount, (_) => <TowerBlock>[]);
  final List<TowerBlock> selected = [];
  int target = 0;
  double clock = 0;
  double _askedAt = 0;
  double _spawnTimer = 0;
  int _nextId = 0;
  bool isOver = false;

  int get selectionValue => rules.product
      ? selected.fold(1, (p, b) => p * b.value)
      : selected.fold(0, (s, b) => s + b.value);

  double get spawnSeconds =>
      max(1.6, log.level.targetSeconds * 1.1 - log.correctCount * 0.08);

  Iterable<TowerBlock> get blocks => columns.expand((c) => c);

  /// Every 4 targets made opens the next story chapter.
  GameStoryChapter get chapter =>
      GameStoryChapter.forProgress(log.correctCount, 4);

  void update(double dt) {
    if (isOver) return;
    clock += dt;
    for (final b in blocks) {
      if (b.landed < 1) b.landed = min(1, b.landed + dt / 0.25);
    }
    _spawnTimer += dt;
    if (_spawnTimer >= spawnSeconds) {
      _spawnTimer = 0;
      _drop(_randomValue());
    }
  }

  TowerOutcome tap(TowerBlock block) {
    if (isOver || !blocks.contains(block)) return TowerOutcome.none;
    if (selected.remove(block)) return TowerOutcome.deselected;
    selected.add(block);
    final value = selectionValue;
    if (value == target && (!rules.pairsOnly || selected.length == 2)) {
      _submit(correct: true);
      for (final b in selected) {
        for (final c in columns) {
          c.remove(b);
        }
      }
      selected.clear();
      _newTarget();
      return TowerOutcome.cleared;
    }
    final wrong = rules.pairsOnly ? selected.length >= 2 : value > target;
    if (wrong) {
      _submit(correct: false);
      selected.clear();
      return TowerOutcome.wrong;
    }
    return TowerOutcome.selected;
  }

  void _submit({required bool correct}) {
    // The fact the child actually computed with the chosen blocks.
    final values = selected.map((b) => b.value).toList();
    final MathProblem problem;
    if (rules.signed) {
      problem =
          integerProblem(values[0], rules.symbol == '×' ? '×' : '+', values[1]);
    } else if (rules.product) {
      problem = multiplicationProblem(values[0], values[1]);
    } else {
      final last = values.removeLast();
      problem = additionProblem(values.fold(0, (s, v) => s + v), last);
    }
    log.submit(problem,
        correct: correct,
        elapsed: Duration(milliseconds: ((clock - _askedAt) * 1000).round()),
        given: '$target');
  }

  int _randomValue() {
    while (true) {
      final v =
          rules.minBlock + random.nextInt(rules.maxBlock - rules.minBlock + 1);
      // 0 (and ±1 in products) make trivial or ambiguous targets.
      if (v != 0 && !(rules.product && v.abs() == 1)) return v;
    }
  }

  void _drop(int value, {bool instant = false}) {
    final open = [
      for (var i = 0; i < columnsCount; i++)
        if (columns[i].length < rows) i,
    ];
    final shortest = columns.map((c) => c.length).reduce(min);
    // Prefer lower columns so the tower grows evenly.
    final candidates =
        open.where((i) => columns[i].length <= shortest + 1).toList();
    if (candidates.isEmpty) {
      isOver = true;
      return;
    }
    final block = TowerBlock(_nextId++, value)..landed = instant ? 1 : 0;
    columns[candidates[random.nextInt(candidates.length)]].add(block);
    if (columns.every((c) => c.length >= rows)) isOver = true;
  }

  /// Picks a target makeable from two blocks on the board.
  void _newTarget() {
    _askedAt = clock;
    final all = blocks.toList();
    for (var attempt = 0; attempt < 30 && all.length >= 2; attempt++) {
      all.shuffle(random);
      final a = all[0].value, b = all[1].value;
      final t = rules.product ? a * b : a + b;
      if (t >= rules.minTarget && t <= rules.maxTarget) {
        target = t;
        return;
      }
    }
    // Board too sparse or no pair in range: add a matching pair.
    final a = _randomValue();
    var b = _randomValue();
    if (!rules.product) {
      b = max(rules.minBlock,
          min(rules.maxBlock, rules.minTarget - a + random.nextInt(5)));
    }
    _drop(a);
    _drop(b);
    target = rules.product ? a * b : a + b;
  }
}

class NumberTowerScreen extends StatefulWidget {
  const NumberTowerScreen({
    required this.context,
    required this.level,
    required this.theme,
    super.key,
  });

  final QuizGameContext context;
  final MathLevel level;
  final GameVisualTheme theme;

  @override
  State<NumberTowerScreen> createState() => _NumberTowerScreenState();
}

class _NumberTowerScreenState extends State<NumberTowerScreen>
    with SingleTickerProviderStateMixin, GameActivityScope<NumberTowerScreen> {
  late final GameLoop _loop = GameLoop(this, _tick);
  late final TowerSession _session;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  bool _finished = false;
  bool? _flash;
  int _blockCount = 0;

  QuizGameContext get _ctx => widget.context;
  late final GameStoryDriver _story = _ctx.storyDriver(widget.theme);
  final StoryEffects _fx = StoryEffects();
  Size _board = Size.zero;

  /// Centre of [block] on the board (resting position).
  Offset? _blockCenter(TowerBlock block) {
    for (var c = 0; c < _session.columns.length; c++) {
      final r = _session.columns[c].indexOf(block);
      if (r < 0) continue;
      final w = _board.width / TowerSession.columnsCount;
      final h = _board.height / TowerSession.rows;
      return Offset(c * w + w / 2, _board.height - (r + 0.5) * h);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _session = TowerSession(
      log: _ctx.mathRoundLog(widget.level),
      random: _ctx.randomFactory(),
    );
    _blockCount = _session.blocks.length;
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
    final count = _session.blocks.length;
    if (count != _blockCount) {
      _blockCount = count;
      setState(() {});
    }
    _frame.value++;
  }

  void _tap(TowerBlock block) {
    // Where the picked blocks sit, captured before a clear removes them.
    final picked = [
      for (final b in [..._session.selected, block]) _blockCenter(b),
    ].whereType<Offset>().toList();
    final outcome = _session.tap(block);
    switch (outcome) {
      case TowerOutcome.cleared:
        _ctx.audio.play(GameSound.shotFor(_story.chapter));
        _ctx.audio.haptic(GameHaptic.light);
        for (final at in picked) {
          _fx.burst(at, _story.stage.shot);
        }
        _story.reach(_session.chapter);
      case TowerOutcome.wrong:
        _ctx.audio.play(GameSound.wrong);
        _ctx.audio.haptic(GameHaptic.medium);
      case TowerOutcome.selected:
      case TowerOutcome.deselected:
        _ctx.audio.play(GameSound.select, volume: 0.4);
      case TowerOutcome.none:
        return;
    }
    setState(() {
      _blockCount = _session.blocks.length;
      if (outcome == TowerOutcome.cleared) _flash = true;
      if (outcome == TowerOutcome.wrong) _flash = false;
      if (outcome == TowerOutcome.selected) _flash = null;
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
        game: QuizGameKind.tower,
        level: widget.level,
        headline: 'Tower full!',
        detail: '${log.correctCount} targets made',
        logs: [log],
        replay: (_) => NumberTowerScreen(
            context: _ctx, level: widget.level, theme: widget.theme),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(widget.theme, chapter: _story.chapter);
    final rules = _session.rules;
    final picked = _session.selected
        .map((b) => formatInt(b.value))
        .join(' ${rules.symbol} ');
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
                combo: _session.log.combo,
                onPause: _pause,
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                child: Column(
                  children: [
                    Text(
                      rules.product
                          ? 'Two blocks that multiply to'
                          : rules.pairsOnly
                              ? 'Two blocks that add up to'
                              : 'Blocks that add up to',
                      style: TextStyle(color: palette.onPanel),
                    ),
                    Text(
                      formatInt(_session.target),
                      key: const ValueKey('tower-target'),
                      style: TextStyle(
                          color: palette.onPanel,
                          fontSize: 40,
                          fontWeight: FontWeight.w900),
                    ),
                    Text(
                      picked.isEmpty
                          ? ' '
                          : '$picked = ${formatInt(_session.selectionValue)}',
                      key: const ValueKey('tower-selection'),
                      style: TextStyle(
                          color: palette.onPanel,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  child: LayoutBuilder(builder: (context, box) {
                    final cellW = box.maxWidth / TowerSession.columnsCount;
                    final cellH = box.maxHeight / TowerSession.rows;
                    _board = Size(box.maxWidth, box.maxHeight);
                    return ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (context, _, __) => Stack(
                        children: [
                          // Danger line at the top row.
                          Positioned(
                            top: cellH - 1,
                            left: 0,
                            right: 0,
                            child: Container(
                                height: 2,
                                color: palette.bad.withValues(alpha: 0.6)),
                          ),
                          for (var c = 0; c < TowerSession.columnsCount; c++)
                            for (var r = 0; r < _session.columns[c].length; r++)
                              _block(_session.columns[c][r], c, r, cellW, cellH,
                                  box.maxHeight, palette),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                  painter: StoryEffectsPainter(_fx,
                                      repaint: _frame)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(TowerBlock block, int column, int row, double w, double h,
      double fieldHeight, QuizPalette palette) {
    final restingTop = fieldHeight - (row + 1) * h;
    final top =
        restingTop * (0.3 + 0.7 * Curves.easeIn.transform(block.landed));
    final isSelected = _session.selected.contains(block);
    final easter = widget.theme == GameVisualTheme.easter;
    final color = easter
        ? easterEggColors[block.value % easterEggColors.length]
        : const Color(0xFF334155);
    return Positioned(
      left: column * w + 3,
      top: top + 3,
      width: w - 6,
      height: h - 6,
      child: GestureDetector(
        key: ValueKey('tower-block-${block.id}'),
        onTap: () => _tap(block),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: isSelected ? palette.accent : color,
            borderRadius: BorderRadius.circular(easter ? 22 : 10),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : easter
                      ? Colors.white
                      : const Color(0xFF64748B),
              width: isSelected ? 3 : 2,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                formatInt(block.value),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: easter || isSelected ? palette.text : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

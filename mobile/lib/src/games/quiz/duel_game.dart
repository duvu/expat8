import 'dart:math';

import 'package:flutter/material.dart';

import '../common/game_audio.dart';
import '../common/game_story.dart';
import '../common/game_theme.dart';
import 'quiz_game_context.dart';
import 'quiz_core.dart';
import 'quiz_round.dart';
import 'quiz_screens.dart';
import 'quiz_ui.dart';
import '../common/game_activity.dart';

class DuelPlayer {
  DuelPlayer(this.log) {
    next(0);
  }

  final QuizRoundLog log;
  late QuizItem problem;
  late List<String> choices;
  int points = 0;
  double lockedFor = 0;
  double _askedAt = 0;

  QuizLevel get level => log.level;
  bool get locked => lockedFor > 0;

  void next(double clock) {
    problem = log.generator.next();
    choices = log.generator.choicesFor(problem);
    _askedAt = clock;
  }
}

enum DuelAnswer { correct, wrong, locked }

/// Math Duel rules: two players on one device, each with their own level and
/// problems. A correct answer scores a point and brings the next problem; a
/// wrong one locks that player for 1.5 s. First to [pointsToWin] wins, so
/// speed matters but guessing does not pay.
class DuelSession {
  DuelSession(List<QuizRoundLog> logs)
      : players = [for (final log in logs) DuelPlayer(log)];

  static const pointsToWin = 10;
  static const lockSeconds = 1.5;

  final List<DuelPlayer> players;
  double clock = 0;

  /// The leader's score drives the story: every 2 points opens a chapter.
  GameStoryChapter get chapter =>
      GameStoryChapter.forProgress(players.map((p) => p.points).reduce(max), 2);

  int? get winner {
    for (var i = 0; i < players.length; i++) {
      if (players[i].points >= pointsToWin) return i;
    }
    return null;
  }

  void update(double dt) {
    clock += dt;
    for (final p in players) {
      if (p.lockedFor > 0) p.lockedFor = max(0, p.lockedFor - dt);
    }
  }

  DuelAnswer answer(int playerIndex, String value) {
    final p = players[playerIndex];
    if (winner != null || p.locked) return DuelAnswer.locked;
    final correct = value == p.problem.answerText;
    p.log.submit(
      p.problem,
      correct: correct,
      elapsed: Duration(milliseconds: ((clock - p._askedAt) * 1000).round()),
      given: value,
    );
    if (!correct) {
      p.lockedFor = lockSeconds;
      return DuelAnswer.wrong;
    }
    p.points++;
    p.next(clock);
    return DuelAnswer.correct;
  }
}

class DuelScreen extends StatefulWidget {
  const DuelScreen({
    required this.context,
    required this.game,
    required this.level,
    required this.theme,
    this.playerTwoLevel,
    super.key,
  });

  final QuizGameContext context;

  /// Player 1's level.
  final QuizGameKind game;
  final QuizLevel level;
  final GameVisualTheme theme;

  /// Set when replaying; otherwise Player 2 chooses before the start.
  final QuizLevel? playerTwoLevel;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen>
    with SingleTickerProviderStateMixin, GameActivityScope<DuelScreen> {
  late final GameLoop _loop = GameLoop(this, _tick);
  DuelSession? _session;
  late QuizLevel _playerTwoLevel = widget.playerTwoLevel ?? widget.level;
  final List<bool> _wasLocked = [false, false];
  bool _finished = false;

  QuizGameContext get _ctx => widget.context;
  late final GameStoryDriver _story = _ctx.storyDriver(widget.theme);

  @override
  void initState() {
    super.initState();
    if (widget.playerTwoLevel != null) _start();
  }

  @override
  void dispose() {
    _loop.dispose();
    _ctx.audio.stopMusic();
    super.dispose();
  }

  void _start() {
    setState(() {
      _session = DuelSession(
          [_ctx.roundLog(widget.level), _ctx.roundLog(_playerTwoLevel)]);
    });
    _story.start();
    _loop.start();
  }

  void _tick(double dt) {
    final session = _session!;
    session.update(dt);
    final locks = session.players.map((p) => p.locked).toList();
    if (locks[0] != _wasLocked[0] || locks[1] != _wasLocked[1]) {
      _wasLocked
        ..[0] = locks[0]
        ..[1] = locks[1];
      setState(() {});
    }
  }

  void _answer(int player, String value) {
    final session = _session!;
    final result = session.answer(player, value);
    if (result == DuelAnswer.locked) return;
    if (result == DuelAnswer.correct) {
      _ctx.audio.play(GameSound.shotFor(_story.chapter));
      _story.reach(session.chapter);
      _ctx.audio.haptic(GameHaptic.light);
    } else {
      _ctx.audio.play(GameSound.wrong);
      _ctx.audio.haptic(GameHaptic.medium);
      _wasLocked[player] = true;
    }
    setState(() {});
    if (session.winner != null) _finish();
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
    final session = _session!;
    final winner = session.winner;
    _ctx.audio.play(GameSound.solved);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => QuizResultScreen(
        context: _ctx,
        game: widget.game,
        level: widget.level,
        headline:
            winner == null ? 'Duel stopped' : 'Player ${winner + 1} wins!',
        detail: '${session.players[0].points} – ${session.players[1].points}',
        logs: [for (final p in session.players) p.log],
        saveScore: false,
        replay: (_) => DuelScreen(
          context: _ctx,
          game: widget.game,
          level: widget.level,
          theme: widget.theme,
          playerTwoLevel: _playerTwoLevel,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(widget.theme, chapter: _story.chapter);
    final session = _session;
    return Scaffold(
      backgroundColor: palette.skyTop,
      body: SafeArea(
        child: QuizBackdrop(
          theme: widget.theme,
          chapter: _story.chapter,
          child: session == null ? _setup(palette) : _arena(session, palette),
        ),
      ),
    );
  }

  Widget _setup(QuizPalette palette) => Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Player 1: ${widget.level.label}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text('Player 2 level',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final level in widget.game.subject.levels)
                      ChoiceChip(
                        key: ValueKey('duel-p2-${level.id}'),
                        label: Text(level.label),
                        selected: _playerTwoLevel == level,
                        onSelected: (_) =>
                            setState(() => _playerTwoLevel = level),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('duel-start'),
                  onPressed: _start,
                  icon: const Icon(Icons.sports_score),
                  label: const Text('Start duel'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _arena(DuelSession session, QuizPalette palette) => Column(
        children: [
          Expanded(
            child: RotatedBox(
              quarterTurns: 2,
              child: _PlayerSide(
                index: 1,
                player: session.players[1],
                opponentPoints: session.players[0].points,
                theme: widget.theme,
                chapter: _story.chapter,
                palette: palette,
                onPick: (v) => _answer(1, v),
              ),
            ),
          ),
          Container(
            height: 44,
            color: palette.panel.withValues(alpha: 0.9),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: session.players[0].points / DuelSession.pointsToWin,
                    color: palette.good,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                IconButton(
                  tooltip: 'Pause',
                  onPressed: _pause,
                  icon:
                      Icon(Icons.pause_circle_outline, color: palette.onPanel),
                ),
                Expanded(
                  child: Transform.flip(
                    flipX: true,
                    child: LinearProgressIndicator(
                      value:
                          session.players[1].points / DuelSession.pointsToWin,
                      color: palette.accent,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(
            child: _PlayerSide(
              index: 0,
              player: session.players[0],
              opponentPoints: session.players[1].points,
              theme: widget.theme,
              chapter: _story.chapter,
              palette: palette,
              onPick: (v) => _answer(0, v),
            ),
          ),
        ],
      );
}

class _PlayerSide extends StatelessWidget {
  const _PlayerSide({
    required this.index,
    required this.player,
    required this.opponentPoints,
    required this.theme,
    required this.chapter,
    required this.palette,
    required this.onPick,
  });

  final int index;
  final DuelPlayer player;
  final int opponentPoints;
  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final QuizPalette palette;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Player ${index + 1} · ${player.level.label} · '
            '${player.points}/${DuelSession.pointsToWin}',
            key: ValueKey('duel-score-$index'),
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  width: 3,
                  color: player.locked ? palette.bad : palette.accent),
            ),
            child: QuizPromptText(player.problem.text,
                key: ValueKey('duel-problem-$index'), color: palette.onPanel),
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              QuizChoiceButtons(
                theme: theme,
                chapter: chapter,
                choices: player.choices,
                onPick: onPick,
                enabled: !player.locked,
                keyPrefix: 'duel-$index-choice',
              ),
              if (player.locked)
                Positioned.fill(
                  child: Center(
                    child: Text('Frozen!',
                        style: TextStyle(
                            color: palette.bad,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

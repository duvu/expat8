import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game_storage.dart';
import 'sudoku_champion_board_screen.dart';
import 'sudoku_champion_store.dart';
import 'sudoku_difficulty.dart';
import 'sudoku_game_controller.dart';
import 'sudoku_game_screen.dart';
import 'sudoku_generator.dart';

typedef SudokuPuzzleFactory = Future<SudokuPuzzle> Function(
    SudokuDifficulty difficulty);

SudokuPuzzle _generateInIsolate(String difficultyName) =>
    SudokuGenerator().generate(SudokuDifficulty.fromName(difficultyName));

/// Generates off the UI thread so hard puzzles never stall a frame.
Future<SudokuPuzzle> generateSudokuPuzzle(SudokuDifficulty difficulty) =>
    compute(_generateInIsolate, difficulty.name);

/// Difficulty picker, resume and champion-board entry for Sudoku.
class SudokuHomeScreen extends StatefulWidget {
  const SudokuHomeScreen({
    required this.storage,
    this.puzzleFactory = generateSudokuPuzzle,
    super.key,
  });

  final GameStorage storage;
  final SudokuPuzzleFactory puzzleFactory;

  @override
  State<SudokuHomeScreen> createState() => _SudokuHomeScreenState();
}

class _SudokuHomeScreenState extends State<SudokuHomeScreen> {
  late final SudokuChampionStore _store = SudokuChampionStore(widget.storage);
  SudokuDifficulty? _savedDifficulty;
  Map<SudokuDifficulty, List<SudokuRecord>> _board = const {};
  Map<SudokuDifficulty, SudokuStats> _stats = const {};
  SudokuDifficulty? _generating;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final saved = await SudokuGameController.savedDifficulty(widget.storage);
    final board = await _store.loadBoard();
    final stats = await _store.loadStats();
    if (!mounted) return;
    setState(() {
      _savedDifficulty = saved;
      _board = board;
      _stats = stats;
    });
  }

  Future<void> _startNew(SudokuDifficulty difficulty) async {
    if (_generating != null) return;
    if (_savedDifficulty != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new game?'),
          content: const Text('Your unfinished game will be discarded.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('New game'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    setState(() => _generating = difficulty);
    final SudokuPuzzle puzzle;
    try {
      puzzle = await widget.puzzleFactory(difficulty);
    } finally {
      if (mounted) setState(() => _generating = null);
    }
    await _store.recordStarted(difficulty);
    final game =
        SudokuGameController.fromPuzzle(puzzle, storage: widget.storage);
    await game.save();
    await _play(game);
  }

  Future<void> _resume() async {
    final game = await SudokuGameController.restore(storage: widget.storage);
    if (game == null) {
      await _refresh();
      return;
    }
    await _play(game);
  }

  Future<void> _play(SudokuGameController game) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SudokuGameScreen(controller: game, championStore: _store),
      ),
    );
    // The route future completes before the screen is disposed, so persist
    // the paused state here; SudokuGameScreen disposes the controller.
    if (!game.isSolved) {
      game.pause();
      await game.save();
    }
    await _refresh();
  }

  void _openBoard([SudokuDifficulty? difficulty]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SudokuChampionBoardScreen(
          store: _store,
          initialDifficulty: difficulty ?? SudokuDifficulty.beginner,
        ),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = _savedDifficulty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Champion board',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: _openBoard,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (saved != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Continue game'),
                subtitle: Text(saved.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: _resume,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('New game', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final d in SudokuDifficulty.values)
            Card(
              child: ListTile(
                key: ValueKey('sudoku-difficulty-${d.name}'),
                title: Text(d.label),
                subtitle: Text(_subtitle(d)),
                trailing: _generating == d
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _DifficultyDots(level: d.index + 1),
                onTap: _generating == null ? () => _startNew(d) : null,
                onLongPress: () => _openBoard(d),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Works offline. Records are saved on this device. '
            'Each hint adds ${SudokuRecord.hintPenalty.inSeconds}s to your time.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _subtitle(SudokuDifficulty d) {
    final best = _board[d]?.firstOrNull;
    final stats = _stats[d];
    final parts = <String>[
      best == null
          ? 'No record yet'
          : 'Best ${formatDuration(Duration(milliseconds: best.scoreMs))} · ${best.playerName}',
      if (stats != null && stats.completed > 0) 'Solved ${stats.completed}',
    ];
    return parts.join(' · ');
  }
}

class _DifficultyDots extends StatelessWidget {
  const _DifficultyDots({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Icon(
              Icons.circle,
              size: 10,
              color: i <= level ? scheme.primary : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

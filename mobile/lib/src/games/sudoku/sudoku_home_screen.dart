import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common/game_audio.dart';
import '../common/game_settings.dart';
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
    this.settings,
    this.audio,
    super.key,
  });

  final GameStorage storage;
  final SudokuPuzzleFactory puzzleFactory;

  /// Shared game settings/audio; created from [storage] when not provided.
  final GameSettings? settings;
  final GameAudio? audio;

  @override
  State<SudokuHomeScreen> createState() => _SudokuHomeScreenState();
}

class _SudokuHomeScreenState extends State<SudokuHomeScreen> {
  late final SudokuChampionStore _store = SudokuChampionStore(widget.storage);
  late final GameSettings _settings =
      widget.settings ?? GameSettings(widget.storage);
  late final GameAudio _audio = widget.audio ?? GameAudio(_settings);
  SudokuDifficulty? _savedDifficulty;
  Map<SudokuDifficulty, List<SudokuRecord>> _board = const {};
  Map<SudokuDifficulty, SudokuStats> _stats = const {};
  SudokuDifficulty? _generating;

  @override
  void initState() {
    super.initState();
    _settings.load();
    _audio.preload();
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
        builder: (_) => SudokuGameScreen(
          controller: game,
          championStore: _store,
          audio: _audio,
          reducedMotion: _settings.reducedMotion,
        ),
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
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => SudokuChampionBoardScreen(
              store: _store,
              initialDifficulty: difficulty ?? SudokuDifficulty.beginner,
            ),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = _savedDifficulty;
    final solved =
        _stats.values.fold<int>(0, (sum, stats) => sum + stats.completed);
    final champions =
        _board.values.where((records) => records.isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Champion board',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: _openBoard,
          ),
          IconButton(
            tooltip: 'Game settings',
            icon: const Icon(Icons.tune),
            onPressed: () => showGameSettingsSheet(context, _settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _HeroCard(solved: solved, levelsWithRecords: champions),
          const SizedBox(height: 16),
          if (saved != null) ...[
            _ContinueCard(difficulty: saved, onTap: _resume),
            const SizedBox(height: 16),
          ],
          Text('Choose a level', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final d in SudokuDifficulty.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LevelCard(
                key: ValueKey('sudoku-difficulty-${d.name}'),
                difficulty: d,
                subtitle: _subtitle(d),
                generating: _generating == d,
                onTap: _generating == null ? () => _startNew(d) : null,
                onLongPress: () => _openBoard(d),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Works offline. Records are saved on this device. Each hint adds '
            '${SudokuRecord.hintPenalty.inSeconds}s to your time. '
            'Long-press a level to see its champions.',
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

/// Accent color per level, from calm to intense.
Color levelColor(SudokuDifficulty d) => switch (d) {
      SudokuDifficulty.beginner => const Color(0xFF43A047),
      SudokuDifficulty.easy => const Color(0xFF00897B),
      SudokuDifficulty.medium => const Color(0xFF1E88E5),
      SudokuDifficulty.hard => const Color(0xFF8E24AA),
      SudokuDifficulty.expert => const Color(0xFFE53935),
    };

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.solved, required this.levelsWithRecords});

  final int solved;
  final int levelsWithRecords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child:
                Icon(Icons.grid_on_rounded, size: 36, color: scheme.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Train your brain',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$solved solved · $levelsWithRecords/5 levels on the board',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.difficulty, required this.onTap});

  final SudokuDifficulty difficulty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.play_circle_fill_rounded,
            size: 36, color: scheme.onSecondaryContainer),
        title: const Text('Continue game'),
        subtitle: Text(difficulty.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.difficulty,
    required this.subtitle,
    required this.generating,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final SudokuDifficulty difficulty;
  final String subtitle;
  final bool generating;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = levelColor(difficulty);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Text(
                          '${difficulty.index + 1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              difficulty.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(subtitle, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      generating
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _DifficultyDots(
                              level: difficulty.index + 1, color: accent),
                    ],
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

class _DifficultyDots extends StatelessWidget {
  const _DifficultyDots({required this.level, required this.color});

  final int level;
  final Color color;

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
              color: i <= level ? color : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

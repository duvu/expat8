import 'dart:async';

import 'package:flutter/material.dart';

import 'sudoku_board_view.dart';
import 'sudoku_champion_store.dart';
import 'sudoku_game_controller.dart';

/// Plays one Sudoku game. Pauses when the app goes to the background and
/// saves progress when the screen closes. Takes ownership of [controller]
/// and disposes it.
class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({
    required this.controller,
    required this.championStore,
    super.key,
  });

  final SudokuGameController controller;
  final SudokuChampionStore championStore;

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _completionHandled = false;

  SudokuGameController get _game => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.addListener(_onGameChanged);
    _game.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _game.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _game.removeListener(_onGameChanged);
    _game.pause();
    _game.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Stay paused until the player taps Resume.
      return;
    }
    _game.pause();
  }

  void _onGameChanged() {
    if (!mounted) return;
    setState(() {});
    if (_game.isSolved && !_completionHandled) {
      _completionHandled = true;
      unawaited(_handleCompletion());
    }
  }

  Future<void> _handleCompletion() async {
    final store = widget.championStore;
    final playerName = await store.loadPlayerName();
    final record = SudokuRecord(
      playerName: playerName,
      difficulty: _game.difficulty,
      elapsedMs: _game.elapsed.inMilliseconds,
      hintsUsed: _game.hintsUsed,
      mistakes: _game.mistakes,
      completedAt: DateTime.now().toUtc(),
    );
    await store.recordCompleted(_game.difficulty);
    final rank = await store.rankFor(record);
    if (!mounted) return;

    var name = playerName;
    if (rank != null) {
      name = await _askName(playerName, rank) ?? playerName;
      await store.savePlayerName(name);
      await store.addRecord(record.copyWith(playerName: name));
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(rank == 1 ? Icons.emoji_events : Icons.check_circle_outline),
        title: Text(rank == 1 ? 'New champion!' : 'Puzzle solved'),
        content: Text(
          '${_game.difficulty.label} · ${formatDuration(_game.elapsed)}\n'
          'Mistakes: ${_game.mistakes} · Hints: ${_game.hintsUsed}\n'
          '${rank == null ? 'Not in the top ${SudokuChampionStore.maxEntries} this time.' : 'Rank #$rank on the champion board.'}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<String?> _askName(String current, int rank) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PlayerNameDialog(initialName: current, rank: rank),
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paused = !_game.isRunning && !_game.isSolved;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sudoku · ${_game.difficulty.label}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                formatDuration(_game.elapsed),
                key: const ValueKey('sudoku-timer'),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: paused ? 'Resume' : 'Pause',
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            onPressed: _game.isSolved
                ? null
                : () => paused ? _game.start() : _game.pause(),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = constraints.maxWidth.clamp(0.0, 520.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: boardSize),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mistakes: ${_game.mistakes}',
                              style: theme.textTheme.bodyMedium),
                          Text('Hints: ${_game.hintsUsed}',
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          SudokuBoardView(controller: _game),
                          if (paused)
                            Positioned.fill(
                              child: ColoredBox(
                                color: theme.colorScheme.surface,
                                child: Center(
                                  child: FilledButton.icon(
                                    onPressed: _game.start,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Resume'),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Toolbar(game: _game),
                      const SizedBox(height: 12),
                      _NumberPad(game: _game),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Owns its text controller so it outlives the dialog's exit animation.
class _PlayerNameDialog extends StatefulWidget {
  const _PlayerNameDialog({required this.initialName, required this.rank});

  final String initialName;
  final int rank;

  @override
  State<_PlayerNameDialog> createState() => _PlayerNameDialogState();
}

class _PlayerNameDialogState extends State<_PlayerNameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rank #${widget.rank}!'),
      content: TextField(
        key: const ValueKey('sudoku-player-name'),
        controller: _name,
        autofocus: true,
        maxLength: 20,
        decoration: const InputDecoration(labelText: 'Your name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.game});

  final SudokuGameController game;

  @override
  Widget build(BuildContext context) {
    final enabled = game.isRunning;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolButton(
          icon: Icons.undo,
          label: 'Undo',
          onPressed: enabled && game.canUndo ? game.undo : null,
        ),
        _ToolButton(
          icon: Icons.backspace_outlined,
          label: 'Erase',
          onPressed: enabled ? game.erase : null,
        ),
        _ToolButton(
          icon: game.notesMode ? Icons.edit : Icons.edit_outlined,
          label: game.notesMode ? 'Notes on' : 'Notes',
          selected: game.notesMode,
          onPressed: enabled ? game.toggleNotesMode : null,
        ),
        _ToolButton(
          icon: Icons.lightbulb_outline,
          label: 'Hint',
          onPressed: enabled ? game.hint : null,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: label,
          isSelected: selected,
          style: selected
              ? IconButton.styleFrom(backgroundColor: scheme.primaryContainer)
              : null,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.game});

  final SudokuGameController game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var digit = 1; digit <= 9; digit++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _DigitButton(game: game, digit: digit, theme: theme),
            ),
          ),
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({
    required this.game,
    required this.digit,
    required this.theme,
  });

  final SudokuGameController game;
  final int digit;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final left = game.remaining(digit);
    final enabled = game.isRunning && left > 0;
    return AspectRatio(
      aspectRatio: 0.7,
      child: OutlinedButton(
        key: ValueKey('sudoku-digit-$digit'),
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: enabled ? () => game.enter(digit) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text('$digit', style: theme.textTheme.headlineSmall),
            ),
            FittedBox(
              child: Text(
                left > 0 ? '$left' : '✓',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

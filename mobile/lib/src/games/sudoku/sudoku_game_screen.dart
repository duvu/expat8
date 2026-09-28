import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flame/game.dart';

import 'sudoku_board_game.dart';
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
  SudokuBoardGame? _boardGame;

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
    // Let the board celebration (glow wave + confetti) play first.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final palette = SudokuBoardPalette.fromScheme(
      theme.colorScheme,
      fontFamily: theme.textTheme.bodyLarge?.fontFamily,
    );
    final game = _boardGame;
    if (game == null) {
      _boardGame = SudokuBoardGame(controller: _game, palette: palette);
    } else {
      game.palette = palette;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paused = !_game.isRunning && !_game.isSolved;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sudoku · ${_game.difficulty.label}'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: false,
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.primaryContainer.withValues(alpha: 0.35)
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.clamp(0.0, 520.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width),
                    child: Column(
                      children: [
                        _StatusBar(
                          game: _game,
                          paused: paused,
                          onPauseToggle: _game.isSolved
                              ? null
                              : () => paused ? _game.start() : _game.pause(),
                        ),
                        const SizedBox(height: 14),
                        AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Semantics(
                                  label: _boardSemantics(),
                                  child: GameWidget<SudokuBoardGame>(
                                    key: const ValueKey('sudoku-board'),
                                    game: _boardGame!,
                                  ),
                                ),
                              ),
                              if (paused)
                                Positioned.fill(
                                  child: _PausedCover(onResume: _game.start),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Toolbar(game: _game),
                        const SizedBox(height: 14),
                        _NumberPad(game: _game),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _boardSemantics() {
    final selected = _game.selected;
    if (selected == null) return 'Sudoku board. Tap a cell to select it.';
    final value = _game.valueAt(selected);
    return 'Selected row ${selected ~/ 9 + 1}, column ${selected % 9 + 1}, '
        '${value == 0 ? 'empty' : '$value'}';
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.game,
    required this.paused,
    required this.onPauseToggle,
  });

  final SudokuGameController game;
  final bool paused;
  final VoidCallback? onPauseToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _StatChip(
          icon: Icons.timer_outlined,
          text: formatDuration(game.elapsed),
          textKey: const ValueKey('sudoku-timer'),
          color: scheme.primary,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.close_rounded,
          text: '${game.mistakes}',
          color: game.mistakes == 0 ? scheme.onSurfaceVariant : scheme.error,
          semanticLabel: 'Mistakes: ${game.mistakes}',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.lightbulb_outline,
          text: '${game.hintsUsed}',
          color: scheme.tertiary,
          semanticLabel: 'Hints: ${game.hintsUsed}',
        ),
        const Spacer(),
        IconButton.filledTonal(
          tooltip: paused ? 'Resume' : 'Pause',
          onPressed: onPauseToggle,
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.text,
    required this.color,
    this.textKey,
    this.semanticLabel,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Key? textKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              key: textKey,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PausedCover extends StatelessWidget {
  const _PausedCover({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle_outline, size: 56, color: scheme.primary),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume'),
              ),
            ],
          ),
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
          icon: Icons.undo_rounded,
          label: 'Undo',
          onPressed: enabled && game.canUndo ? game.undo : null,
        ),
        _ToolButton(
          icon: Icons.backspace_outlined,
          label: 'Erase',
          onPressed: enabled ? game.erase : null,
        ),
        _ToolButton(
          icon: Icons.edit_outlined,
          label: 'Notes',
          badge: game.notesMode ? 'ON' : null,
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
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final button = selected
        ? IconButton.filled(
            tooltip: label,
            onPressed: onPressed,
            iconSize: 26,
            icon: Icon(icon),
          )
        : IconButton.filledTonal(
            tooltip: label,
            onPressed: onPressed,
            iconSize: 26,
            icon: Icon(icon),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 56,
          child: Badge(
            isLabelVisible: badge != null,
            label: Text(badge ?? ''),
            backgroundColor: scheme.tertiary,
            child: Center(child: button),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.game});

  final SudokuGameController game;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var digit = 1; digit <= 9; digit++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _DigitButton(game: game, digit: digit),
            ),
          ),
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({required this.game, required this.digit});

  final SudokuGameController game;
  final int digit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = game.remaining(digit);
    final enabled = game.isRunning && left > 0;
    final notes = game.notesMode;
    return AspectRatio(
      aspectRatio: 0.72,
      child: Material(
        color: !enabled
            ? scheme.surfaceContainer
            : notes
                ? scheme.tertiaryContainer
                : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('sudoku-digit-$digit'),
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => game.enter(digit) : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    child: Text(
                      '$digit',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? (notes
                                ? scheme.onTertiaryContainer
                                : scheme.onPrimaryContainer)
                            : scheme.outline,
                      ),
                    ),
                  ),
                  FittedBox(
                    child: Text(
                      left > 0 ? '$left' : '✓',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

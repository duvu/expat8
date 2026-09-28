import 'package:flutter/material.dart';

import '../../common/game_score_store.dart';
import '../../common/game_settings.dart';
import '../word_blaster_context.dart';
import '../word_blaster_mode.dart';
import '../word_blaster_stats.dart';
import '../word_pool.dart';
import 'word_blaster_board_screen.dart';
import 'word_blaster_play_screen.dart';
import 'word_blaster_stats_screen.dart';

/// Mode picker and entry to records/stats/settings for Word Blaster.
class WordBlasterHomeScreen extends StatefulWidget {
  const WordBlasterHomeScreen({required this.context, super.key});

  final WordBlasterContext context;

  @override
  State<WordBlasterHomeScreen> createState() => _WordBlasterHomeScreenState();
}

class _WordBlasterHomeScreenState extends State<WordBlasterHomeScreen> {
  WordBlasterContext get _ctx => widget.context;
  Map<String, List<GameScore>> _board = const {};
  WordBlasterStats? _stats;
  WordBlasterMode? _lastMode;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _ctx.settings.load();
    _ctx.audio.preload();
    _refresh();
  }

  Future<void> _refresh() async {
    final board = await _ctx.scores.loadAll();
    final stats = await _ctx.stats.load();
    final last = await _ctx.lastMode();
    if (!mounted) return;
    setState(() {
      _board = board;
      _stats = stats;
      _lastMode = last;
    });
  }

  List<WordBlasterMode> get _orderedModes {
    final last = _lastMode;
    if (last == null) return WordBlasterMode.values;
    return [last, ...WordBlasterMode.values.where((m) => m != last)];
  }

  Future<void> _start(WordBlasterMode mode) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final words = await _ctx.loadWords();
      final result = buildWordPool(
        words: words,
        learnerLevelIndex: _ctx.learnerLevelIndex,
        now: DateTime.now().toUtc(),
        random: _ctx.randomFactory(),
      );
      if (!mounted) return;
      switch (result) {
        case WordPoolInsufficient(:final available, :final required):
          await _showNotEnoughWords(available, required);
        case WordPoolReady(:final pool):
          await _ctx.saveLastMode(mode);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  WordBlasterPlayScreen(context: _ctx, mode: mode, pool: pool),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
      await _refresh();
    }
  }

  Future<void> _showNotEnoughWords(int available, int required) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.menu_book_outlined),
        title: const Text('Learn a few more words'),
        content: Text(
          'Word Blaster needs at least $required words on this device. '
          'You have $available. Study ${required - available} more to unlock it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Go learn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Blaster'),
        actions: [
          IconButton(
            tooltip: 'Stats',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => WordBlasterStatsScreen(context: _ctx)))
                .then((_) => _refresh()),
          ),
          IconButton(
            tooltip: 'Champion board',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => WordBlasterBoardScreen(context: _ctx)))
                .then((_) => _refresh()),
          ),
          IconButton(
            tooltip: 'Game settings',
            icon: const Icon(Icons.tune),
            onPressed: () => showGameSettingsSheet(context, _ctx.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Hero(stats: stats),
          const SizedBox(height: 16),
          Text('Choose a mode', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final mode in _orderedModes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModeCard(
                key: ValueKey('word-blaster-mode-${mode.name}'),
                mode: mode,
                best: (_board[mode.name] ?? const []).firstOrNull,
                locked: !_ctx.isUnlocked(mode),
                unavailable: !_ctx.isAvailable(mode),
                busy: _starting,
                onTap: () => _start(mode),
              ),
            ),
          Text(
            'Every answer counts as a review: correct words come back later, '
            'missed words come back sooner. Works offline.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stats});

  final WordBlasterStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = stats;
    final line = s == null || s.roundsPlayed == 0
        ? 'Shoot the right word before it lands!'
        : '${s.roundsPlayed} rounds · ${(s.totalAnswered == 0 ? 0 : s.totalCorrect * 100 ~/ s.totalAnswered)}% accuracy · best combo ${s.bestCombo}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1026), Color(0xFF3B2A7A)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.rocket_launch_rounded,
                size: 36, color: Color(0xFFFFC857)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Word Blaster',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.best,
    required this.locked,
    required this.unavailable,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final WordBlasterMode mode;
  final GameScore? best;
  final bool locked;
  final bool unavailable;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = !locked && !unavailable && !busy;
    final String status;
    if (locked) {
      status =
          'Unlocks at level ${mode.minLevelIndex == 1 ? 'A2 / HSK2' : '${mode.minLevelIndex + 1}'}';
    } else if (unavailable) {
      status = 'Needs text-to-speech on this device';
    } else if (best != null) {
      status = 'Best ${best!.score} · ${best!.playerName}';
    } else {
      status = 'No record yet';
    }
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: enabled
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                child: Icon(
                  locked ? Icons.lock_outline : mode.icon,
                  color: enabled ? scheme.onPrimaryContainer : scheme.outline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(mode.description, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.primary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded,
                  color: enabled ? scheme.primary : scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

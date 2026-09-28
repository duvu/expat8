import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../api/backend_api_client.dart'
    show GameLeaderboard, GameLeaderboardEntry;
import '../../common/game_score_store.dart';
import '../word_blaster_context.dart';
import '../word_blaster_mode.dart';

enum _BoardScope { device, weekly }

/// Local top 10 per mode, plus the weekly global leaderboard for signed-in
/// learners (cached for offline viewing).
class WordBlasterBoardScreen extends StatefulWidget {
  const WordBlasterBoardScreen({required this.context, super.key});

  final WordBlasterContext context;

  @override
  State<WordBlasterBoardScreen> createState() => _WordBlasterBoardScreenState();
}

class _WordBlasterBoardScreenState extends State<WordBlasterBoardScreen> {
  late Future<Map<String, List<GameScore>>> _board =
      widget.context.scores.loadAll();
  _BoardScope _scope = _BoardScope.device;

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear champion board?'),
        content: const Text(
            'All Word Blaster records on this device will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.context.scores.clear();
    setState(() => _board = widget.context.scores.loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final showWeekly = widget.context.fetchLeaderboard != null;
    return DefaultTabController(
      length: WordBlasterMode.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Champion board'),
          actions: [
            if (_scope == _BoardScope.device)
              IconButton(
                  tooltip: 'Clear board',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clear),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final m in WordBlasterMode.values) Tab(text: m.title)],
          ),
        ),
        body: Column(
          children: [
            if (showWeekly)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<_BoardScope>(
                  segments: const [
                    ButtonSegment(
                      value: _BoardScope.device,
                      icon: Icon(Icons.phone_android),
                      label: Text('This device'),
                    ),
                    ButtonSegment(
                      value: _BoardScope.weekly,
                      icon: Icon(Icons.public),
                      label: Text('This week'),
                    ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) => setState(() => _scope = s.first),
                ),
              ),
            Expanded(
              child: _scope == _BoardScope.device
                  ? FutureBuilder<Map<String, List<GameScore>>>(
                      future: _board,
                      builder: (context, snapshot) {
                        final board = snapshot.data;
                        if (board == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return TabBarView(
                          children: [
                            for (final m in WordBlasterMode.values)
                              _LocalList(records: board[m.name] ?? const []),
                          ],
                        );
                      },
                    )
                  : TabBarView(
                      children: [
                        for (final m in WordBlasterMode.values)
                          _WeeklyList(context: widget.context, mode: m),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalList extends StatelessWidget {
  const _LocalList({required this.records});

  final List<GameScore> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (records.isEmpty) {
      return const _Empty(
          'No records yet. Play a round to claim the top spot!');
    }
    return ListView.separated(
      itemCount: records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = records[i];
        final d = r.completedAt.toLocal();
        return ListTile(
          leading: _RankBadge(rank: i + 1),
          title: Text(r.playerName),
          subtitle: Text(
            'Accuracy ${((r.accuracy ?? 0) * 100).round()}% · Combo ${r.bestCombo ?? 0} · '
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          ),
          trailing: Text('${r.score}', style: theme.textTheme.titleMedium),
        );
      },
    );
  }
}

class _WeeklyList extends StatefulWidget {
  const _WeeklyList({required this.context, required this.mode});

  final WordBlasterContext context;
  final WordBlasterMode mode;

  @override
  State<_WeeklyList> createState() => _WeeklyListState();
}

class _WeeklyListState extends State<_WeeklyList>
    with AutomaticKeepAliveClientMixin {
  GameLeaderboard? _board;
  bool _signedOut = false;
  bool _offline = false;
  bool _loading = true;

  String get _cacheKey =>
      'games.word_blaster.leaderboard_cache.${widget.mode.name}';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final board = await widget.context.fetchLeaderboard!(
          game: 'word_blaster', mode: widget.mode.name);
      if (board == null) {
        _signedOut = true;
      } else {
        _board = board;
        _offline = false;
        await widget.context.storage
            .write(_cacheKey, jsonEncode(board.toJson()));
      }
    } on Object {
      final raw = await widget.context.storage.read(_cacheKey);
      if (raw != null) {
        try {
          _board =
              GameLeaderboard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } on Object {
          _board = null;
        }
      }
      _offline = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_signedOut) {
      return const _Empty(
          'Sign in to join the weekly leaderboard. Your rounds from this device will count.');
    }
    final board = _board;
    final entries = board?.entries ?? const <GameLeaderboardEntry>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_offline)
            const ListTile(
              dense: true,
              leading: Icon(Icons.cloud_off, size: 20),
              title: Text('Offline — showing the last saved leaderboard.'),
            ),
          if (board == null || entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No scores this week yet. Be the first!',
                  textAlign: TextAlign.center),
            )
          else ...[
            for (final e in entries)
              ListTile(
                tileColor: e.isMe
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : null,
                leading: _RankBadge(rank: e.rank),
                title: Text(e.isMe ? '${e.displayName} (you)' : e.displayName),
                subtitle: Text(
                    'Accuracy ${(e.accuracy * 100).round()}% · Combo ${e.bestCombo}'),
                trailing:
                    Text('${e.score}', style: theme.textTheme.titleMedium),
              ),
            if (board.me != null && !entries.any((e) => e.isMe))
              ListTile(
                leading: _RankBadge(rank: board.me!.rank),
                title: const Text('You'),
                trailing: Text('${board.me!.score}',
                    style: theme.textTheme.titleMedium),
              ),
          ],
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor:
          rank == 1 ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
      child: rank == 1 ? const Icon(Icons.emoji_events) : Text('$rank'),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

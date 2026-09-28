import 'package:flutter/material.dart';

import 'sudoku_champion_store.dart';
import 'sudoku_difficulty.dart';
import 'sudoku_game_screen.dart' show formatDuration;

/// Top solves per difficulty, stored on this device.
class SudokuChampionBoardScreen extends StatefulWidget {
  const SudokuChampionBoardScreen({
    required this.store,
    this.initialDifficulty = SudokuDifficulty.beginner,
    super.key,
  });

  final SudokuChampionStore store;
  final SudokuDifficulty initialDifficulty;

  @override
  State<SudokuChampionBoardScreen> createState() =>
      _SudokuChampionBoardScreenState();
}

class _SudokuChampionBoardScreenState extends State<SudokuChampionBoardScreen> {
  late Future<Map<SudokuDifficulty, List<SudokuRecord>>> _board;

  @override
  void initState() {
    super.initState();
    _board = widget.store.loadBoard();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear champion board?'),
        content:
            const Text('All saved records on this device will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.clearBoard();
    setState(() => _board = widget.store.loadBoard());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: SudokuDifficulty.values.length,
      initialIndex: widget.initialDifficulty.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Champion board'),
          actions: [
            IconButton(
              tooltip: 'Clear board',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClear,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final d in SudokuDifficulty.values) Tab(text: d.label),
            ],
          ),
        ),
        body: FutureBuilder<Map<SudokuDifficulty, List<SudokuRecord>>>(
          future: _board,
          builder: (context, snapshot) {
            final board = snapshot.data;
            if (board == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return TabBarView(
              children: [
                for (final d in SudokuDifficulty.values)
                  _RecordList(records: board[d]!),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({required this.records});

  final List<SudokuRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No records yet. Solve a puzzle to claim the top spot!',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final record = records[i];
        final local = record.completedAt.toLocal();
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: i == 0
                ? theme.colorScheme.tertiaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: i == 0 ? const Icon(Icons.emoji_events) : Text('${i + 1}'),
          ),
          title: Text(record.playerName),
          subtitle: Text(
            'Mistakes ${record.mistakes} · Hints ${record.hintsUsed} · '
            '${local.year}-${local.month.toString().padLeft(2, '0')}-'
            '${local.day.toString().padLeft(2, '0')}',
          ),
          trailing: Text(
            formatDuration(Duration(milliseconds: record.scoreMs)),
            style: theme.textTheme.titleMedium,
          ),
        );
      },
    );
  }
}

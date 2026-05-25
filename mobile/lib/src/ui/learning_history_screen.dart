import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models/learning_progress.dart';
import '../widgets/empty_state_view.dart';

class LearningHistoryScreen extends StatefulWidget {
  const LearningHistoryScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends State<LearningHistoryScreen> {
  late Future<List<LearningHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.database.getLearningHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = widget.database.getLearningHistory();
    });
    await _historyFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<LearningHistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <LearningHistoryEntry>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyStateView(
              icon: Icons.error_outline,
              title: 'Could not load history',
              body: 'Pull down to try again.',
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }
          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  EmptyStateView(
                    icon: Icons.history,
                    title: 'No history yet',
                    body: 'Words you study will appear here.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _HistoryCard(entry: entry);
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final LearningHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final snapshot = entry.snapshot;
    // Use theme-driven colors to distinguish vocabulary vs sentence cards.
    final isVocab = snapshot.kind == LearningItemKind.vocabulary;
    final avatarBg = isVocab ? colorScheme.primaryContainer : colorScheme.tertiaryContainer;
    final avatarFg = isVocab ? colorScheme.onPrimaryContainer : colorScheme.onTertiaryContainer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarBg,
                  foregroundColor: avatarFg,
                  child: Text(snapshot.kindLabel.substring(0, 1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snapshot.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 4),
                      Text(snapshot.subtitle,
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  entry.stateLabel,
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            if (snapshot.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final tag in snapshot.tags) Chip(label: Text(tag))],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _formatTimestamp(entry.occurredAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    return local.toString().split('.').first;
  }
}

import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models/learning_progress.dart';
import '../widgets/empty_state_view.dart';

class LearningProgressStatsScreen extends StatefulWidget {
  const LearningProgressStatsScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<LearningProgressStatsScreen> createState() =>
      _LearningProgressStatsScreenState();
}

class _LearningProgressStatsScreenState
    extends State<LearningProgressStatsScreen> {
  late Future<LearningProgressTotals> _totalsFuture;

  @override
  void initState() {
    super.initState();
    _totalsFuture = widget.database.getLearningProgressTotals();
  }

  Future<void> _refresh() async {
    setState(() {
      _totalsFuture = widget.database.getLearningProgressTotals();
    });
    await _totalsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: FutureBuilder<LearningProgressTotals>(
        future: _totalsFuture,
        builder: (context, snapshot) {
          final totals = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              totals == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyStateView(
              icon: Icons.error_outline,
              title: 'Could not load stats',
              body: 'Pull down to try again.',
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }
          final value = totals ??
              const LearningProgressTotals(
                learned: 0,
                remembered: 0,
                difficult: 0,
              );
          final isEmpty = value.learned == 0 &&
              value.remembered == 0 &&
              value.difficult == 0;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: EmptyStateView(
                      icon: Icons.insights_rounded,
                      title: 'No stats yet',
                      body:
                          'Study a few cards and your progress will show up here.',
                    ),
                  )
                else ...[
                  _TotalBanner(
                      total:
                          value.learned + value.remembered + value.difficult),
                  const SizedBox(height: 16),
                  _StatCard(
                    label: 'Learned',
                    hint: 'Cards you moved on from',
                    value: value.learned,
                    icon: Icons.school_rounded,
                    tone: _Tone.primary,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    label: 'Remembered',
                    hint: 'Cards you marked as known',
                    value: value.remembered,
                    icon: Icons.check_circle_rounded,
                    tone: _Tone.secondary,
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    label: 'Difficult',
                    hint: 'Cards that will come back sooner',
                    value: value.difficult,
                    icon: Icons.replay_circle_filled_rounded,
                    tone: _Tone.error,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _Tone { primary, secondary, error }

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: scheme.onPrimary, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'cards studied so far',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.hint,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String hint;
  final int value;
  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg) = switch (tone) {
      _Tone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _Tone.secondary => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer
        ),
      _Tone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
                radius: 22,
                backgroundColor: bg,
                foregroundColor: fg,
                child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(hint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

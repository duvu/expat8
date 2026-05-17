import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models/learning_progress.dart';

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
          final value = totals ?? const LearningProgressTotals(
            learned: 0,
            remembered: 0,
            difficult: 0,
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _StatCard(label: 'Learned', value: value.learned),
                const SizedBox(height: 12),
                _StatCard(label: 'Remembered', value: value.remembered),
                const SizedBox(height: 12),
                _StatCard(label: 'Difficult', value: value.difficult),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../api/models/speaking_models.dart';
import '../speaking/speaking_repository.dart';

/// Weekly speaking summary screen.
///
/// Fetches and displays the learner's weekly speaking activity from the
/// backend. Falls back gracefully when offline or when the API is unavailable.
/// Offers a "Start drill" CTA to continue the daily loop.
class SpeakingSummaryScreen extends StatefulWidget {
  const SpeakingSummaryScreen({required this.repository, super.key});

  final SpeakingRepository repository;

  @override
  State<SpeakingSummaryScreen> createState() => _SpeakingSummaryScreenState();
}

class _SpeakingSummaryScreenState extends State<SpeakingSummaryScreen> {
  SpeakingWeeklySummary? _summary;
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    final result = await widget.repository.getWeeklySummary();
    if (!mounted) return;
    setState(() {
      _summary = result;
      _offline = result == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('This week')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_offline) return _offlineState(theme);
    final s = _summary!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatCard(
            icon: Icons.record_voice_over_outlined,
            label: 'Sentences recorded',
            value: '${s.spokenSentenceCount}',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.timer_outlined,
            label: 'Speaking time',
            value: _formatDuration(s.approximateDurationMs),
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.repeat_outlined,
            label: 'Drill loops completed',
            value: '${s.loopCompletionCount}',
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.mic_outlined),
              label: const Text('Start drill'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Summary unavailable',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _offline = false;
                });
                _fetchSummary();
              },
              child: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.mic_outlined),
              label: const Text('Start drill anyway'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms < 60000) return '${(ms / 1000).round()}s';
    final minutes = (ms / 60000).floor();
    final seconds = ((ms % 60000) / 1000).round();
    return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

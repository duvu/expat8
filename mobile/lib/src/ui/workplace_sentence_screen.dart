import 'package:flutter/material.dart';

import '../models/workplace_sentence.dart';
import '../session/workplace_sentence_session_controller.dart';
import 'learning_gesture_surface.dart';
import 'learning_history_screen.dart';
import 'learning_progress_stats_screen.dart';

class WorkplaceSentenceScreen extends StatefulWidget {
  const WorkplaceSentenceScreen({
    required this.controller,
    super.key,
  });

  final WorkplaceSentenceSessionController controller;

  @override
  State<WorkplaceSentenceScreen> createState() => _WorkplaceSentenceScreenState();
}

class _WorkplaceSentenceScreenState extends State<WorkplaceSentenceScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.loadInitial();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentences'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: controller.isLoading ? null : () => _openHistory(context),
            icon: const Icon(Icons.history_outlined),
          ),
          IconButton(
            tooltip: 'Stats',
            onPressed: controller.isLoading ? null : () => _openStats(context),
            icon: const Icon(Icons.bar_chart_outlined),
          ),
        ],
      ),
      body: LearningCardGestureSurface(
        isEnabled: !controller.isLoading,
        onSwipeRightToLeft: controller.onSwipeRightToLeft,
        onSwipeLeftToRight: () async {
          await controller.onSwipeLeftToRight();
          if (context.mounted) {
            await _openHistory(context);
          }
        },
        onSwipeBottomToTop: controller.onSwipeBottomToTop,
        onSwipeTopToBottom: controller.onSwipeTopToBottom,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Expanded(
                child: controller.currentSentence == null
                    ? Center(
                        child: Text(
                          controller.statusMessage ?? 'No sentence loaded.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _WorkplaceSentenceCard(sentence: controller.currentSentence!),
              ),
              const SizedBox(height: 16),
              Text(
                'Swipe Right->Left: learned. Swipe Left->Right: history. '
                'Swipe Bottom->Top: remembered. Swipe Top->Bottom: difficult.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHistory(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningHistoryScreen(
          database: widget.controller.repository.database,
        ),
      ),
    );
  }

  Future<void> _openStats(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningProgressStatsScreen(
          database: widget.controller.repository.database,
        ),
      ),
    );
  }
}

class _WorkplaceSentenceCard extends StatelessWidget {
  const _WorkplaceSentenceCard({required this.sentence});

  final WorkplaceSentence sentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sentence.text,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              sentence.meaningVi,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sentence.topic != null && sentence.topic!.isNotEmpty)
                  Chip(label: Text(sentence.topic!)),
                if (sentence.sourceTitle != null && sentence.sourceTitle!.isNotEmpty)
                  Chip(label: Text(sentence.sourceTitle!)),
                if (sentence.isBundled)
                  const Chip(label: Text('Bundled starter')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

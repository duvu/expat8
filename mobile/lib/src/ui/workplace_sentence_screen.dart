import 'package:flutter/material.dart';

import '../models/workplace_sentence.dart';
import '../session/workplace_sentence_session_controller.dart';
import 'learning_gesture_surface.dart';
import 'learning_history_screen.dart';
import 'learning_progress_stats_screen.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/study_action_bar.dart';

class WorkplaceSentenceScreen extends StatefulWidget {
  const WorkplaceSentenceScreen({
    required this.controller,
    super.key,
  });

  final WorkplaceSentenceSessionController controller;

  @override
  State<WorkplaceSentenceScreen> createState() =>
      _WorkplaceSentenceScreenState();
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
            onPressed:
                controller.isLoading ? null : () => _openHistory(context),
            icon: const Icon(Icons.history_outlined),
          ),
          IconButton(
            tooltip: 'Stats',
            onPressed: controller.isLoading ? null : () => _openStats(context),
            icon: const Icon(Icons.bar_chart_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (controller.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: LearningCardGestureSurface(
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
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: controller.currentSentence == null
                        ? EmptyStateView(
                            icon: Icons.work_outline,
                            title:
                                controller.statusMessage ?? 'No sentence yet',
                            body: 'Tap Next to load a workplace sentence.',
                          )
                        : _WorkplaceSentenceCard(
                            sentence: controller.currentSentence!),
                  ),
                ),
              ),
            ),
            StudyActionBar(
              enabled: !controller.isLoading,
              onDifficult: controller.onSwipeTopToBottom,
              onRemembered: controller.onSwipeBottomToTop,
              onNext: controller.onSwipeRightToLeft,
              swipeHint:
                  'You can also swipe the card: left for next, up if you remember it, down if it is hard.',
            ),
          ],
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
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sentence.topic != null && sentence.topic!.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sentence.topic!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              sentence.text,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              sentence.meaningVi,
              style:
                  theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

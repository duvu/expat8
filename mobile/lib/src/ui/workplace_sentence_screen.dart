import 'package:flutter/material.dart';

import '../models/workplace_sentence.dart';
import '../session/workplace_sentence_session_controller.dart';

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
      appBar: AppBar(title: const Text('Sentences')),
      body: Padding(
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
            FilledButton.icon(
              onPressed: controller.isLoading ? null : controller.showNextSentence,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next sentence'),
            ),
          ],
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

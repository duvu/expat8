import 'package:flutter/material.dart';

import '../config.dart';
import '../models/vocabulary_word.dart';
import '../speaking/speaking_panel.dart';
import '../speaking/speaking_repository.dart';

class VocabularyCardView extends StatefulWidget {
  const VocabularyCardView({
    required this.word,
    this.speakingRepository,
    this.config,
    super.key,
  });

  final VocabularyWord word;

  /// Provided when [AppConfig.speakingFoundationEnabled] is true.
  final SpeakingRepository? speakingRepository;

  /// Defaults to [AppConfig.fromEnvironment] when null.
  final AppConfig? config;

  @override
  State<VocabularyCardView> createState() => _VocabularyCardViewState();
}

class _VocabularyCardViewState extends State<VocabularyCardView> {
  bool _speakingExpanded = false;

  AppConfig get _config => widget.config ?? AppConfig.fromEnvironment();

  bool get _speakingEnabled =>
      _config.speakingFoundationEnabled &&
      widget.speakingRepository != null &&
      widget.word.speakingPrompt != null;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    widget.word.term,
                    style: textTheme.headlineMedium,
                  ),
                ),
                if (widget.word.partOfSpeech != null)
                  Text(widget.word.partOfSpeech!, style: textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.word.meaningVi, style: textTheme.titleMedium),
            const Divider(height: 32),
            _Detail(
                label: 'Vietnamese reading',
                value: widget.word.vietnamesePronunciation),
            _Detail(label: 'IPA', value: widget.word.ipa),
            const SizedBox(height: 16),
            Text(widget.word.example, style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(widget.word.exampleVi, style: textTheme.bodyMedium),
            if (_speakingEnabled) ...[
              const SizedBox(height: 16),
              _SpeakingToggle(
                expanded: _speakingExpanded,
                onToggle: () =>
                    setState(() => _speakingExpanded = !_speakingExpanded),
              ),
              if (_speakingExpanded) ...[
                const SizedBox(height: 8),
                SpeakingPanel(
                  word: widget.word,
                  repository: widget.speakingRepository!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeakingToggle extends StatelessWidget {
  const _SpeakingToggle(
      {required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onToggle,
      icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.mic_none),
      label: Text(expanded ? 'Hide speaking practice' : 'Practice speaking'),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}


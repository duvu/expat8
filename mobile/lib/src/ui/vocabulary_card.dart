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

  String get _ttsLanguage => switch (widget.word.language) {
        'zh' => 'zh-CN',
        'vi' => 'vi-VN',
        _ => 'en-US',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final word = widget.word;
    final isPhrase = word.entryType == 'phrase' || word.entryType == 'idiom';
    final speaking = widget.speakingRepository;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isPhrase)
                        _Tag(text: word.entryType == 'idiom' ? 'idiom' : 'phrase')
                      else if (word.partOfSpeech != null)
                        _Tag(text: word.partOfSpeech!),
                      if (word.difficulty.trim().isNotEmpty) _Tag(text: word.difficulty, strong: true),
                    ],
                  ),
                ),
                if (speaking != null)
                  IconButton.filledTonal(
                    tooltip: 'Listen',
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => speaking
                        .playSample(word.term, languageCode: _ttsLanguage)
                        .catchError((Object _) {}),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                word.term,
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (!isPhrase) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (word.ipa.trim().isNotEmpty) _Detail(label: 'IPA', value: word.ipa),
                  if (word.vietnamesePronunciation.trim().isNotEmpty)
                    _Detail(label: 'Vietnamese reading', value: word.vietnamesePronunciation),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              word.meaningVi,
              style: textTheme.headlineSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isPhrase && word.explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                word.explanation,
                style: textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (word.example.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.example, style: textTheme.bodyLarge),
                    if (word.exampleVi.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        word.exampleVi,
                        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_speakingEnabled) ...[
              const SizedBox(height: 12),
              _SpeakingToggle(
                expanded: _speakingExpanded,
                onToggle: () => setState(() => _speakingExpanded = !_speakingExpanded),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: strong ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onToggle,
          icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.mic_none),
          label: Text(expanded ? 'Hide speaking practice' : 'Practice speaking'),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/study_card_frame.dart';

import '../config.dart';
import '../models/vocabulary_word.dart';
import '../speaking/speaking_panel.dart';
import '../speaking/speaking_repository.dart';
import '../theme/app_radius.dart';

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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final word = widget.word;
    final isPhrase = word.entryType == 'phrase' || word.entryType == 'idiom';
    final speaking = widget.speakingRepository;
    final levelColor = AppTheme.levelColor(word.difficulty);
    return StudyCardFrame(
      level: word.difficulty,
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
                      if (word.difficulty.trim().isNotEmpty)
                        LevelBadge(level: word.difficulty),
                      if (isPhrase)
                        _Tag(
                            text:
                                word.entryType == 'idiom' ? 'idiom' : 'phrase')
                      else if (word.partOfSpeech != null)
                        _Tag(text: word.partOfSpeech!),
                    ],
                  ),
                ),
                if (speaking != null)
                  IconButton.filledTonal(
                    tooltip: 'Listen',
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => speaking
                        .playSample(word.term,
                            languageCode: ttsLanguageCode(word.language))
                        .catchError((Object _) {}),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                word.term,
                style:
                    textTheme.displaySmall?.copyWith(color: scheme.onSurface),
              ),
            ),
            if (!isPhrase) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (word.ipa.trim().isNotEmpty)
                    _Detail(label: 'IPA', value: word.ipa),
                  if (word.vietnamesePronunciation.trim().isNotEmpty)
                    _Detail(
                        label: 'Vietnamese reading',
                        value: word.vietnamesePronunciation),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // The meaning is the answer the learner checks: make it pop.
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: AppRadius.control,
              ),
              child: Text(
                word.meaningVi,
                style: textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
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
              // Quote style: accent bar + example and its translation.
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                  borderRadius: AppRadius.control,
                  border: Border(left: BorderSide(color: levelColor, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.example,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontStyle: FontStyle.italic)),
                    if (word.exampleVi.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        word.exampleVi,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.control,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SpeakingToggle extends StatelessWidget {
  const _SpeakingToggle({required this.expanded, required this.onToggle});

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
          label:
              Text(expanded ? 'Hide speaking practice' : 'Practice speaking'),
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
      // Text.rich wraps on narrow screens / large text instead of overflowing.
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label  ',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          TextSpan(
            text: value,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}

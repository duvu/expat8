import 'package:flutter/material.dart';

import '../models/vocabulary_word.dart';

/// Fill-in-the-blank card for review mode.
///
/// Displays the example sentence with the target word replaced by `___`.
/// [exampleVi] and [meaningVi] are hidden until the learner taps the card.
class FitbCard extends StatefulWidget {
  const FitbCard({required this.word, super.key});

  final VocabularyWord word;

  @override
  State<FitbCard> createState() => _FitbCardState();
}

class _FitbCardState extends State<FitbCard> {
  bool _revealed = false;

  /// The word that is blanked in the sentence.
  /// For `word` entry_type: the entire [VocabularyWord.term].
  /// For `phrase`/`idiom`: the LLM-chosen [VocabularyWord.blankWord].
  String get _blankTarget => widget.word.blankWord ?? widget.word.term;

  /// Returns the example sentence with [_blankTarget] replaced by `___`
  /// (case-insensitive, first occurrence only).
  String get _blankedSentence {
    final example = widget.word.example;
    final target = _blankTarget;
    final lower = example.toLowerCase();
    final lowerTarget = target.toLowerCase();
    final idx = lower.indexOf(lowerTarget);
    if (idx == -1) return example; // guard: target not found, show original
    return '${example.substring(0, idx)}___${example.substring(idx + target.length)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final word = widget.word;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _revealed ? null : () => setState(() => _revealed = true),
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Term row (same layout as VocabularyCardView)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      word.term,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Meaning — visible only after reveal, fades in
              AnimatedOpacity(
                opacity: _revealed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _revealed
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(word.meaningVi, style: textTheme.titleMedium),
                          const Divider(height: 32),
                        ],
                      )
                    : const Divider(height: 32),
              ),
              // Blanked example sentence — scales up slightly on reveal
              AnimatedScale(
                scale: _revealed ? 1.0 : 0.97,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _BlankedSentence(
                  blankedText: _blankedSentence,
                  blankTarget: _blankTarget,
                  revealed: _revealed,
                  textTheme: textTheme,
                ),
              ),
              const SizedBox(height: 8),
              // Vietnamese example fades in; hint fades out simultaneously
              AnimatedCrossFade(
                firstChild: _TapToRevealHint(textTheme: textTheme),
                secondChild: Text(word.exampleVi, style: textTheme.bodyMedium),
                crossFadeState: _revealed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the example sentence, highlighting the `___` blank before reveal
/// and the actual word (in bold) after reveal.
class _BlankedSentence extends StatelessWidget {
  const _BlankedSentence({
    required this.blankedText,
    required this.blankTarget,
    required this.revealed,
    required this.textTheme,
  });

  final String blankedText;
  final String blankTarget;
  final bool revealed;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return Text(blankedText, style: textTheme.bodyLarge);
    }
    // After reveal: replace ___ with the actual word in bold
    final parts = blankedText.split('___');
    if (parts.length != 2) {
      return Text(blankedText, style: textTheme.bodyLarge);
    }
    return RichText(
      text: TextSpan(
        style: textTheme.bodyLarge,
        children: [
          TextSpan(text: parts[0]),
          TextSpan(
            text: blankTarget,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}

class _TapToRevealHint extends StatelessWidget {
  const _TapToRevealHint({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tap to reveal',
      style: textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

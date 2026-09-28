import 'package:flutter/material.dart';

import '../../../models/vocabulary_word.dart';
import '../word_blaster_context.dart';
import '../word_blaster_learning.dart';

/// Flashcard review of a given word list (missed or most-missed words). Each
/// answer is recorded as a practice review.
class WordReviewScreen extends StatefulWidget {
  const WordReviewScreen({
    required this.context,
    required this.words,
    this.title = 'Review',
    super.key,
  });

  final WordBlasterContext context;
  final List<VocabularyWord> words;
  final String title;

  @override
  State<WordReviewScreen> createState() => _WordReviewScreenState();
}

class _WordReviewScreenState extends State<WordReviewScreen> {
  int _index = 0;
  bool _revealed = false;
  int _known = 0;

  bool get _done => _index >= widget.words.length;

  Future<void> _answer(bool known) async {
    final word = widget.words[_index];
    if (known) _known++;
    await widget.context.repository.recordPracticeAnswer(
      word: word,
      correct: known,
      source: WordBlasterLearning.reviewSource,
    );
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: widget.words.isEmpty ? 1 : _index / widget.words.length,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _done
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text('Review done', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('You knew $_known of ${widget.words.length}.'),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                )
              : _card(theme, widget.words[_index]),
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, VocabularyWord word) {
    final scheme = theme.colorScheme;
    final speak = widget.context.speak;
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            key: const ValueKey('review-card'),
            onTap: () => setState(() => _revealed = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    word.term,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (word.ipa.trim().isNotEmpty)
                    Text(word.ipa, style: theme.textTheme.titleMedium),
                  if (speak != null)
                    IconButton(
                      tooltip: 'Listen',
                      icon: const Icon(Icons.volume_up_rounded),
                      onPressed: () =>
                          speak(word.term, widget.context.ttsLanguageCode)
                              .catchError((Object _) {}),
                    ),
                  const SizedBox(height: 16),
                  if (_revealed) ...[
                    Text(
                      word.meaningVi,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: scheme.primary),
                    ),
                    const SizedBox(height: 12),
                    if (word.example.trim().isNotEmpty)
                      Text(word.example,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge),
                    if (word.exampleVi.trim().isNotEmpty)
                      Text(
                        word.exampleVi,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ] else
                    Text('Tap to see the meaning',
                        style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('review-still-learning'),
                onPressed: _revealed ? () => _answer(false) : null,
                child: const Text('Still learning'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('review-know-it'),
                onPressed: _revealed ? () => _answer(true) : null,
                child: const Text('I know it'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

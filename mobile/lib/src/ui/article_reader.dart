import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/article.dart';
import '../models/vocabulary_word.dart';
import '../widgets/study_card_frame.dart';

/// Adds a word to the learner's reviews (WordRepository.addWordForReview).
typedef AddToReview = Future<void> Function(VocabularyWord word);

/// Where a vocabulary term occurs in an article's text.
class TermMatch {
  const TermMatch(this.start, this.end, this.item);

  final int start;
  final int end;
  final ArticleVocabularyItem item;
}

/// Occurrences of the article's vocabulary in [text]: case-insensitive whole
/// words, longest term first so phrases win over the words inside them,
/// never overlapping, in reading order.
List<TermMatch> findTermMatches(
    String text, List<ArticleVocabularyItem> items) {
  final byLength = [...items.where((i) => i.displayTerm.trim().isNotEmpty)]
    ..sort((a, b) => b.displayTerm.length.compareTo(a.displayTerm.length));
  final taken = List<bool>.filled(text.length, false);
  final matches = <TermMatch>[];
  for (final item in byLength) {
    final pattern = RegExp(
      r'(?<![\p{L}\p{N}])' +
          RegExp.escape(item.displayTerm.trim())
              .replaceAll(RegExp(r'\s+'), r'\s+') +
          r'(?![\p{L}\p{N}])',
      caseSensitive: false,
      unicode: true,
    );
    for (final m in pattern.allMatches(text)) {
      if (taken.sublist(m.start, m.end).any((t) => t)) continue;
      taken.fillRange(m.start, m.end, true);
      matches.add(TermMatch(m.start, m.end, item));
    }
  }
  return matches..sort((a, b) => a.start.compareTo(b.start));
}

/// The article text with its vocabulary highlighted; tapping a term opens
/// its meaning with an "Add to review" action.
class ArticleBody extends StatefulWidget {
  const ArticleBody({
    required this.text,
    required this.vocabulary,
    this.onAddToReview,
    super.key,
  });

  final String text;
  final List<ArticleVocabularyItem> vocabulary;
  final AddToReview? onAddToReview;

  @override
  State<ArticleBody> createState() => _ArticleBodyState();
}

class _ArticleBodyState extends State<ArticleBody> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge?.copyWith(height: 1.6);
    final highlight = base?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: theme.colorScheme.primary,
    );
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in findTermMatches(widget.text, widget.vocabulary)) {
      spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      final recognizer = TapGestureRecognizer()
        ..onTap = () => showArticleWordSheet(context,
            item: match.item, onAddToReview: widget.onAddToReview);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: widget.text.substring(match.start, match.end),
        style: highlight,
        recognizer: recognizer,
      ));
      cursor = match.end;
    }
    spans.add(TextSpan(text: widget.text.substring(cursor)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      key: const Key('article_detail_body'),
    );
  }
}

/// Meaning of an article term, with "Add to review" when it has a study word.
Future<void> showArticleWordSheet(
  BuildContext context, {
  required ArticleVocabularyItem item,
  AddToReview? onAddToReview,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _ArticleWordSheet(item: item, onAddToReview: onAddToReview),
    );

class _ArticleWordSheet extends StatefulWidget {
  const _ArticleWordSheet({required this.item, this.onAddToReview});

  final ArticleVocabularyItem item;
  final AddToReview? onAddToReview;

  @override
  State<_ArticleWordSheet> createState() => _ArticleWordSheetState();
}

class _ArticleWordSheetState extends State<_ArticleWordSheet> {
  bool _busy = false;
  bool _added = false;

  Future<void> _add(VocabularyWord word) async {
    setState(() => _busy = true);
    try {
      await widget.onAddToReview!(word);
      if (mounted) setState(() => _added = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final word = item.word;
    final details = [
      if (item.partOfSpeech != null) item.partOfSpeech!,
      if ((item.ipa ?? '').isNotEmpty) item.ipa!,
    ].join(' · ');
    final example = word?.example.trim() ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.displayTerm,
                      style: theme.textTheme.headlineSmall),
                ),
                if ((item.level ?? '').isNotEmpty)
                  LevelBadge(level: item.level!),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(details,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 12),
            Text(item.meaningVi, style: theme.textTheme.titleLarge),
            if (example.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(example,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (word != null && widget.onAddToReview != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('article_word_add_review'),
                  onPressed: _busy || _added ? null : () => _add(word),
                  icon: Icon(_added ? Icons.check : Icons.add_task),
                  label: Text(_added ? 'Added to review' : 'Add to review'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

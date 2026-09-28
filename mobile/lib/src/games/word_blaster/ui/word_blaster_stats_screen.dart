import 'package:flutter/material.dart';

import '../../../models/vocabulary_word.dart';
import '../word_blaster_context.dart';
import '../word_blaster_stats.dart';
import 'word_review_screen.dart';

/// Rounds, accuracy trend and the words that are missed most often.
class WordBlasterStatsScreen extends StatefulWidget {
  const WordBlasterStatsScreen({required this.context, super.key});

  final WordBlasterContext context;

  @override
  State<WordBlasterStatsScreen> createState() => _WordBlasterStatsScreenState();
}

class _WordBlasterStatsScreenState extends State<WordBlasterStatsScreen> {
  WordBlasterStats? _stats;
  List<VocabularyWord> _words = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await widget.context.stats.load();
    final words = await widget.context.loadWords();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _words = words;
    });
  }

  VocabularyWord? _wordFor(String term) {
    final key = term.toLowerCase();
    for (final w in _words) {
      if (w.term.toLowerCase() == key) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Word Blaster stats')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _Tile(label: 'Rounds', value: '${s.roundsPlayed}'),
                    _Tile(label: 'Correct', value: '${s.totalCorrect}'),
                    _Tile(
                      label: 'Accuracy',
                      value: s.totalAnswered == 0
                          ? '–'
                          : '${s.totalCorrect * 100 ~/ s.totalAnswered}%',
                    ),
                    _Tile(label: 'Best combo', value: '${s.bestCombo}'),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Last 7 days', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in s.daily)
                        Expanded(
                          child: Semantics(
                            label:
                                '${d.day.month}/${d.day.day}: ${d.answered == 0 ? 'no play' : '${(d.accuracy * 100).round()}% of ${d.answered}'}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  d.answered == 0
                                      ? ''
                                      : '${(d.accuracy * 100).round()}%',
                                  style: theme.textTheme.labelSmall,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  height: 8 + 90 * d.accuracy,
                                  decoration: BoxDecoration(
                                    color: d.answered == 0
                                        ? scheme.surfaceContainerHighest
                                        : scheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${d.day.day}/${d.day.month}',
                                    style: theme.textTheme.labelSmall),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: Text('Most missed words',
                            style: theme.textTheme.titleMedium)),
                    if (s.mostMissed.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          final words = s.mostMissed
                              .map((e) => _wordFor(e.key))
                              .whereType<VocabularyWord>()
                              .toList();
                          if (words.isEmpty) return;
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => WordReviewScreen(
                              context: widget.context,
                              words: words,
                              title: 'Review most missed',
                            ),
                          ));
                        },
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Review'),
                      ),
                  ],
                ),
                if (s.mostMissed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                        'Play a few rounds to see which words trip you up.'),
                  )
                else
                  for (final e in s.mostMissed)
                    ListTile(
                      dense: true,
                      title: Text(e.key),
                      subtitle: Text(_wordFor(e.key)?.meaningVi ?? ''),
                      trailing: Text('×${e.value}'),
                    ),
              ],
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

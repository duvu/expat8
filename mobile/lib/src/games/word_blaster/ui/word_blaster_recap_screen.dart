import 'package:flutter/material.dart';

import '../../../models/vocabulary_word.dart';
import '../../common/game_score_store.dart';
import '../word_blaster_context.dart';
import '../word_blaster_session.dart';
import '../word_blaster_stats.dart';
import '../word_pool.dart';
import 'word_blaster_play_screen.dart';
import 'word_review_screen.dart';

/// Post-round summary: result, record, and the words to review.
class WordBlasterRecapScreen extends StatefulWidget {
  const WordBlasterRecapScreen({
    required this.context,
    required this.summary,
    required this.outcomes,
    required this.pool,
    super.key,
  });

  final WordBlasterContext context;
  final WordBlasterRoundSummary summary;
  final List<WordOutcome> outcomes;
  final WordPool pool;

  @override
  State<WordBlasterRecapScreen> createState() => _WordBlasterRecapScreenState();
}

class _WordBlasterRecapScreenState extends State<WordBlasterRecapScreen> {
  WordBlasterContext get _ctx => widget.context;
  int? _rank;
  bool _recordChecked = false;
  final Set<String> _reported = {};

  List<VocabularyWord> get _missed => [
        for (final o in widget.outcomes)
          if (!o.correct) o.word
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveRecord());
  }

  Future<void> _saveRecord() async {
    final s = widget.summary;
    if (s.answered == 0) {
      setState(() => _recordChecked = true);
      return;
    }
    final name = await _ctx.scores.loadPlayerName();
    final score = GameScore(
      playerName: name,
      score: s.score,
      completedAt: s.completedAt,
      accuracy: s.accuracy,
      bestCombo: s.bestCombo,
      data: {'correct': s.correct, 'answered': s.answered, 'wave': s.wave},
    );
    final rank = await _ctx.scores.rankFor(s.mode.name, score);
    if (!mounted) return;
    var finalName = name;
    if (rank != null) {
      finalName = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _NameDialog(initialName: name, rank: rank),
          ) ??
          name;
      await _ctx.scores.savePlayerName(finalName);
      await _ctx.scores.add(s.mode.name, score.copyWith(playerName: finalName));
    }
    if (!mounted) return;
    setState(() {
      _rank = rank;
      _recordChecked = true;
    });
  }

  Future<void> _report(VocabularyWord word) async {
    final outcome =
        widget.outcomes.firstWhere((o) => o.word.localId == word.localId);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReportDialog(term: word.term),
    );
    if (note == null) return;
    await _ctx.learning.reportQuestion(
      term: word.term,
      prompt: outcome.prompt,
      options: outcome.options,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() => _reported.add(word.localId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks! We will check this question.')),
    );
  }

  void _playAgain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WordBlasterPlayScreen(
          context: _ctx,
          mode: widget.summary.mode,
          pool: widget.pool,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = widget.summary;
    return Scaffold(
      appBar: AppBar(title: Text('${s.mode.title} · Results')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B1026), Color(0xFF3B2A7A)],
              ),
            ),
            child: Column(
              children: [
                if (_rank == 1)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'New record!',
                      style: TextStyle(
                        color: Color(0xFFFFC857),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                Text(
                  '${s.score}',
                  key: const ValueKey('recap-score'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text('points', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(
                        label: 'Accuracy',
                        value: '${(s.accuracy * 100).round()}%'),
                    _Stat(label: 'Words', value: '${widget.outcomes.length}'),
                    _Stat(label: 'Best combo', value: '${s.bestCombo}'),
                    _Stat(label: 'Wave', value: '${s.wave}'),
                  ],
                ),
                if (_recordChecked && _rank != null && _rank! > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Rank #$_rank on the ${s.mode.title} board',
                    style: const TextStyle(color: Color(0xFFFFC857)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('recap-review'),
                  onPressed: _missed.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WordReviewScreen(
                                context: _ctx,
                                words: _missed,
                                title: 'Review missed words',
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.school_outlined),
                  label: Text(_missed.isEmpty
                      ? 'No missed words'
                      : 'Review ${_missed.length} missed'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey('recap-play-again'),
                  onPressed: _playAgain,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Play again'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_missed.isNotEmpty) ...[
            Text('Missed words', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final word in _missed)
              Card(
                elevation: 0,
                color: scheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(word.term,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      if (word.ipa.trim().isNotEmpty) word.ipa,
                      word.meaningVi,
                      if (word.example.trim().isNotEmpty) word.example,
                    ].join('\n'),
                  ),
                  isThreeLine: word.example.trim().isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_ctx.speak != null)
                        IconButton(
                          tooltip: 'Listen',
                          icon: const Icon(Icons.volume_up_outlined),
                          onPressed: () => _ctx.speak!
                                  (word.term, _ctx.ttsLanguageCode)
                              .catchError((Object _) {}),
                        ),
                      IconButton(
                        tooltip: 'Report a wrong question',
                        icon: Icon(
                          _reported.contains(word.localId)
                              ? Icons.flag
                              : Icons.outlined_flag,
                        ),
                        onPressed: _reported.contains(word.localId)
                            ? null
                            : () => _report(word),
                      ),
                    ],
                  ),
                ),
              ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Perfect round — no missed words!',
                    style: theme.textTheme.titleMedium),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initialName, required this.rank});

  final String initialName;
  final int rank;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC857)),
      title: Text('Rank #${widget.rank}!'),
      content: TextField(
        key: const ValueKey('word-blaster-player-name'),
        controller: _name,
        autofocus: true,
        maxLength: 20,
        decoration: const InputDecoration(labelText: 'Your name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [FilledButton(onPressed: _submit, child: const Text('Save'))],
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.term});

  final String term;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report "${widget.term}"'),
      content: TextField(
        controller: _note,
        maxLength: 200,
        decoration: const InputDecoration(
          labelText: 'What was wrong? (optional)',
          hintText: 'e.g. two answers were correct',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: const Text('Report'),
        ),
      ],
    );
  }
}

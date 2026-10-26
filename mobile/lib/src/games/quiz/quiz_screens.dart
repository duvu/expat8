import 'package:flutter/material.dart';

import '../common/game_score_store.dart';
import '../common/game_settings.dart';
import '../common/game_story.dart';
import '../common/game_story_scene.dart';
import '../common/game_theme.dart';
import 'quiz_core.dart';
import 'quiz_game_context.dart';
import 'quiz_round.dart';
import 'quiz_skills.dart';
import '../../widgets/brand_backdrop.dart';

typedef QuizPlayBuilder = Widget Function(
    QuizGameContext context, QuizLevel level, GameVisualTheme theme);

/// Shared home screen for every quiz game: level, look, journey, records and
/// the items the player should practise.
class QuizGameHomeScreen extends StatefulWidget {
  const QuizGameHomeScreen({
    required this.context,
    required this.game,
    required this.tagline,
    required this.howTo,
    required this.icon,
    required this.colors,
    required this.play,
    super.key,
  });

  final QuizGameContext context;
  final QuizGameKind game;
  final String tagline;
  final List<String> howTo;
  final IconData icon;
  final List<Color> colors;
  final QuizPlayBuilder play;

  @override
  State<QuizGameHomeScreen> createState() => _QuizGameHomeScreenState();
}

class _QuizGameHomeScreenState extends State<QuizGameHomeScreen> {
  QuizGameContext get _ctx => widget.context;
  late QuizLevel _level = widget.game.subject.levels.first;
  GameVisualTheme _theme = GameVisualTheme.space;
  List<GameScore> _records = const [];
  List<WeakItem> _weak = const [];
  QuizLevelStats? _stats;
  GameStoryChapter _bestChapter = GameStoryChapter.one;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ctx.settings.load();
    _ctx.audio.preload();
    _refresh();
  }

  Future<void> _refresh() async {
    final level = _loaded ? _level : await _ctx.level(widget.game);
    final skills = _ctx.trackerFor(level);
    await skills.load();
    final theme = _loaded ? _theme : await _ctx.theme(widget.game);
    final records = await _ctx.scoresFor(widget.game).load(level.id);
    final best = await _ctx.story.best(theme);
    if (!mounted) return;
    setState(() {
      _bestChapter = best;
      _loaded = true;
      _level = level;
      _theme = theme;
      _records = records;
      _weak = skills.weakItems(level).take(6).toList();
      _stats = skills.statsFor(level);
    });
  }

  Future<void> _setLevel(QuizLevel level) async {
    setState(() => _level = level);
    await _ctx.saveLevel(widget.game, level);
    await _refresh();
  }

  Future<void> _setTheme(GameVisualTheme theme) async {
    setState(() => _theme = theme);
    await _ctx.saveTheme(widget.game, theme);
    await _refresh();
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => widget.play(_ctx, _level, _theme)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = _records.firstOrNull;
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.title),
        actions: [
          IconButton(
            tooltip: 'Game settings',
            icon: const Icon(Icons.tune),
            onPressed: () => showGameSettingsSheet(context, _ctx.settings),
          ),
        ],
      ),
      body: BrandBackdrop(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: widget.colors),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 44, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.tagline,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Level', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final level in widget.game.subject.levels)
                ChoiceChip(
                  key: ValueKey('math-level-${level.id}'),
                  label: Text(level.label),
                  selected: _level == level,
                  onSelected: (_) => _setLevel(level),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_level.summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('Look', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<GameVisualTheme>(
            key: const ValueKey('math-theme'),
            showSelectedIcon: false,
            segments: [
              for (final t in GameVisualTheme.values)
                ButtonSegment(
                    value: t, icon: Icon(t.icon), label: Text(t.title)),
            ],
            selected: {_theme},
            onSelectionChanged: (s) => _setTheme(s.first),
          ),
          const SizedBox(height: 12),
          StoryJourneyCard(theme: _theme, best: _bestChapter),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              key: const ValueKey('math-play'),
              onPressed: _loaded ? _play : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 30),
              label: const Text('Play', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_level.label} record',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(best == null
                      ? 'No record yet'
                      : 'Best ${best.score} · ${best.playerName}'),
                  if (stats != null && stats.answered > 0)
                    Text(
                      '${(stats.accuracy * 100).round()}% correct · '
                      '${stats.averageSeconds.toStringAsFixed(1)}s per answer',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          if (_weak.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Practise these (they come back more often)',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _weak)
                          Chip(
                              label: Text(f.item.cue == f.item.text
                                  ? f.item.text
                                  : f.item.cue)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text('How to play', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final line in widget.howTo)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $line', style: theme.textTheme.bodyMedium),
            ),
        ],
      )),
    );
  }
}

/// End-of-game screen: score, accuracy, speed and the missed facts with a
/// mental-math strategy for each.
class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({
    required this.context,
    required this.game,
    required this.level,
    required this.headline,
    required this.logs,
    required this.replay,
    this.detail,
    this.saveScore = true,
    super.key,
  });

  final QuizGameContext context;
  final QuizGameKind game;
  final QuizLevel level;
  final String headline;
  final String? detail;

  /// One log per player (two in a duel).
  final List<QuizRoundLog> logs;
  final WidgetBuilder replay;
  final bool saveScore;

  @override
  State<QuizResultScreen> createState() => _MathResultScreenState();
}

class _MathResultScreenState extends State<QuizResultScreen> {
  int? _rank;

  @override
  void initState() {
    super.initState();
    _persist();
  }

  Future<void> _persist() async {
    final ctx = widget.context;
    await ctx.trackerFor(widget.level).save();
    if (!widget.saveScore) return;
    final log = widget.logs.first;
    if (log.answered == 0) return;
    final store = ctx.scoresFor(widget.game);
    final rank = await store.add(
      widget.level.id,
      GameScore(
        playerName: await store.loadPlayerName(),
        score: log.score,
        completedAt: DateTime.now().toUtc(),
        accuracy: log.accuracy,
        bestCombo: log.bestCombo,
        data: {'avg_seconds': log.averageSeconds},
      ),
    );
    if (mounted) setState(() => _rank = rank);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missed = <String, QuizItem>{
      for (final log in widget.logs)
        for (final p in log.missed) p.key: p,
    }.values.toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.title)),
      body: BrandBackdrop(
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.headline,
              key: const ValueKey('math-result-headline'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (widget.detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.detail!, textAlign: TextAlign.center),
            ),
          if (_rank != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'New record! #$_rank on the ${widget.level.label} board',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.primary)),
            ),
          const SizedBox(height: 16),
          for (final (i, log) in widget.logs.indexed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.logs.length > 1)
                      Text('Player ${i + 1}',
                          style: theme.textTheme.titleSmall),
                    Text('Score ${log.score}',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('${log.correctCount}/${log.answered} correct '
                        '(${(log.accuracy * 100).round()}%)'),
                    Text(
                        '${log.averageSeconds.toStringAsFixed(1)}s per correct answer'),
                    Text('Best streak ${log.bestCombo}'),
                  ],
                ),
              ),
            ),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Let\'s fix these', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final p in missed)
              Card(
                child: ListTile(
                  title: Text(
                      p.text.contains('___')
                          ? p.text.replaceFirst('___', p.answerText)
                          : '${p.text} = ${p.answerText}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: p.hint == null ? null : Text(p.hint!),
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('math-play-again'),
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: widget.replay)),
            icon: const Icon(Icons.replay),
            label: const Text('Play again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      )),
    );
  }
}

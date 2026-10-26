import 'dart:math';

import 'package:flutter/material.dart';

import '../common/game_activity.dart';
import '../common/game_audio.dart';
import '../common/game_story.dart';
import '../common/game_story_scene.dart';
import '../common/game_theme.dart';
import '../quiz/quiz_game_context.dart';
import '../quiz/quiz_screens.dart';
import '../quiz/quiz_ui.dart';
import 'english_quiz.dart';

class WordChip {
  const WordChip(this.id, this.word);

  final int id;
  final String word;
}

enum SentenceTap { placed, completed, wrong, none }

/// Sentence Builder rules: a correct sentence from the grade's grammar bank
/// is cut into word chips and shuffled; the player taps them in order. A
/// wrong chip counts as a mistake and shows the grammar rule. A sentence
/// built without mistakes counts as correct. 90-second round.
class SentenceSession {
  SentenceSession({required this.log, Random? random})
      : random = random ?? Random() {
    _nextSentence();
  }

  static const roundSeconds = 90.0;

  final EnglishRoundLog log;
  final Random random;
  late EnglishItem item;
  late List<String> words;
  List<WordChip> chips = const [];
  final List<String> placed = [];
  int mistakes = 0;
  double timeLeft = roundSeconds;
  double clock = 0;
  double _startedAt = 0;
  int completed = 0;

  bool get isOver => timeLeft <= 0;

  /// Every 2 sentences built opens the next story chapter.
  GameStoryChapter get chapter => GameStoryChapter.forProgress(completed, 2);

  void update(double dt) {
    if (isOver) return;
    clock += dt;
    timeLeft = max(0, timeLeft - dt);
  }

  SentenceTap tap(WordChip chip) {
    if (isOver || !chips.contains(chip)) return SentenceTap.none;
    if (chip.word != words[placed.length]) {
      mistakes++;
      return SentenceTap.wrong;
    }
    placed.add(chip.word);
    chips = [
      for (final c in chips)
        if (c != chip) c
    ];
    if (placed.length < words.length) return SentenceTap.placed;
    log.submit(
      item,
      correct: mistakes == 0,
      elapsed: Duration(milliseconds: ((clock - _startedAt) * 1000).round()),
      given: placed.join(' '),
    );
    completed++;
    _nextSentence();
    return SentenceTap.completed;
  }

  void _nextSentence() {
    item = log.generator.next();
    words = item.completed.split(' ').where((w) => w.isNotEmpty).toList();
    chips = [for (var i = 0; i < words.length; i++) WordChip(i, words[i])]
      ..shuffle(random);
    placed.clear();
    mistakes = 0;
    _startedAt = clock;
  }
}

class SentenceBuilderScreen extends StatefulWidget {
  const SentenceBuilderScreen({
    required this.context,
    required this.level,
    required this.theme,
    super.key,
  });

  final QuizGameContext context;
  final EnglishLevel level;
  final GameVisualTheme theme;

  @override
  State<SentenceBuilderScreen> createState() => _SentenceBuilderScreenState();
}

class _SentenceBuilderScreenState extends State<SentenceBuilderScreen>
    with
        SingleTickerProviderStateMixin,
        GameActivityScope<SentenceBuilderScreen> {
  late final GameLoop _loop = GameLoop(this, _tick);
  late final SentenceSession _session;
  late final GameStoryDriver _story = _ctx.storyDriver(widget.theme);
  final StoryEffects _fx = StoryEffects();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  int _secondsShown = SentenceSession.roundSeconds.ceil();
  bool _showHint = false;
  Size _panel = Size.zero;
  bool _finished = false;

  QuizGameContext get _ctx => widget.context;

  @override
  void initState() {
    super.initState();
    _session = SentenceSession(
      log: _ctx.englishRoundLog(widget.level),
      random: _ctx.randomFactory(),
    );
    _story.start();
    _loop.start();
  }

  @override
  void dispose() {
    _loop.dispose();
    _frame.dispose();
    _ctx.audio.stopMusic();
    super.dispose();
  }

  void _tick(double dt) {
    _session.update(dt);
    _fx.update(dt);
    if (_session.isOver) {
      _finish();
      return;
    }
    if (_session.timeLeft.ceil() != _secondsShown) {
      setState(() => _secondsShown = _session.timeLeft.ceil());
    }
    _frame.value++;
  }

  void _tap(WordChip chip) {
    final result = _session.tap(chip);
    switch (result) {
      case SentenceTap.placed:
        _ctx.audio.play(GameSound.select, volume: 0.5);
      case SentenceTap.completed:
        _ctx.audio.play(GameSound.shotFor(_story.chapter));
        _ctx.audio.haptic(GameHaptic.light);
        _fx.burst(_panel.center(Offset.zero), _story.stage.shot);
        _story.reach(_session.chapter);
      case SentenceTap.wrong:
        _ctx.audio.play(GameSound.wrong);
        _ctx.audio.haptic(GameHaptic.medium);
      case SentenceTap.none:
        return;
    }
    setState(() => _showHint = result == SentenceTap.wrong ||
        (_showHint && result == SentenceTap.placed));
  }

  Future<void> _pause() async {
    _loop.stop();
    final quit = await showGamePause(context);
    if (!mounted) return;
    quit ? _finish() : _loop.start();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _loop.stop();
    _ctx.audio.play(GameSound.gameOver);
    final log = _session.log;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => QuizResultScreen(
        context: _ctx,
        game: QuizGameKind.sentenceBuilder,
        level: widget.level,
        headline: 'Time\'s up!',
        detail: '${_session.completed} sentences built',
        logs: [log],
        replay: (_) => SentenceBuilderScreen(
            context: _ctx, level: widget.level, theme: widget.theme),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _story.chapter;
    final palette = QuizPalette.of(widget.theme, chapter: chapter);
    final item = _session.item;
    final remaining = _session.words.length - _session.placed.length;
    return Scaffold(
      backgroundColor: palette.skyTop,
      body: SafeArea(
        child: QuizBackdrop(
          theme: widget.theme,
          chapter: chapter,
          child: Column(
            children: [
              QuizHud(
                theme: widget.theme,
                chapter: chapter,
                score: _session.log.score,
                secondsLeft: _secondsShown,
                combo: _session.log.combo,
                onPause: _pause,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: LayoutBuilder(builder: (context, box) {
                  final panel = _panel = Size(box.maxWidth, 150);
                  return Stack(children: [
                    Container(
                      key: const ValueKey('sentence-panel'),
                      width: panel.width,
                      constraints: BoxConstraints(minHeight: panel.height),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(width: 3, color: palette.accent),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.topic,
                              style: TextStyle(
                                  color: palette.accent,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(
                            [
                              ..._session.placed,
                              for (var i = 0; i < remaining; i++) '___',
                            ].join(' '),
                            key: const ValueKey('sentence-built'),
                            style: TextStyle(
                                color: palette.onPanel,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.4),
                          ),
                          if (_showHint && item.hint != null) ...[
                            const SizedBox(height: 8),
                            Text('Tip: ${item.hint}',
                                key: const ValueKey('sentence-hint'),
                                style: TextStyle(color: palette.bad)),
                          ],
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                            painter: StoryEffectsPainter(_fx, repaint: _frame)),
                      ),
                    ),
                  ]);
                }),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in _session.chips)
                      _ChipButton(
                        key: ValueKey('sentence-chip-${chip.id}'),
                        chip: chip,
                        theme: widget.theme,
                        chapter: chapter,
                        onTap: () => _tap(chip),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.chip,
    required this.theme,
    required this.chapter,
    required this.onTap,
    super.key,
  });

  final WordChip chip;
  final GameVisualTheme theme;
  final GameStoryChapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(theme, chapter: chapter);
    final light = !GameStory.stage(theme, chapter).dark;
    return Material(
      color: light
          ? easterEggColors[chip.id % easterEggColors.length]
          : palette.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: light ? Colors.white : palette.accent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(chip.word,
              style: TextStyle(
                  color: palette.onPanel,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../common/game_settings.dart';
import '../game/word_blaster_game.dart';
import '../word_blaster_context.dart';
import '../word_blaster_mode.dart';
import '../word_blaster_session.dart';
import '../word_blaster_stats.dart';
import '../word_pool.dart';
import 'word_blaster_recap_screen.dart';

/// One Word Blaster round: HUD, Flame scene and prompt panel.
class WordBlasterPlayScreen extends StatefulWidget {
  const WordBlasterPlayScreen({
    required this.context,
    required this.mode,
    required this.pool,
    super.key,
  });

  final WordBlasterContext context;
  final WordBlasterMode mode;
  final WordPool pool;

  @override
  State<WordBlasterPlayScreen> createState() => _WordBlasterPlayScreenState();
}

class _WordBlasterPlayScreenState extends State<WordBlasterPlayScreen>
    with WidgetsBindingObserver {
  WordBlasterContext get _ctx => widget.context;
  late final WordBlasterSession _session;
  WordBlasterGame? _game;
  StreamSubscription<WordBlasterEvent>? _events;
  Timer? _countdownTimer;
  int _countdown = 3;
  int _replaysLeft = 2;
  String? _banner;
  Timer? _bannerTimer;
  bool _finishing = false;
  bool _audioFailed = false;
  final DateTime _startedAt = DateTime.now().toUtc();

  static const maxReplays = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = WordBlasterSession(
      mode: widget.mode,
      pool: widget.pool,
      learnerLevelIndex: _ctx.learnerLevelIndex,
      random: _ctx.randomFactory(),
      paceMultiplier: _ctx.settings.reducedMotion ? 0.8 : 1.0,
      onWordOutcome: _ctx.learning.record,
    );
    _events = _session.events.listen(_onEvent);
    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
        _session.start();
        _ctx.audio.startMusic();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final palette = WordBlasterPalette.fromScheme(
      theme.colorScheme,
      fontFamily: theme.textTheme.bodyLarge?.fontFamily,
    );
    final game = _game;
    if (game == null) {
      _game = WordBlasterGame(
        session: _session,
        palette: palette,
        audio: _ctx.audio,
        reducedMotion: _ctx.settings.reducedMotion,
      );
    } else {
      game.palette = palette;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _bannerTimer?.cancel();
    _events?.cancel();
    _ctx.audio.stopMusic();
    _session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _pause() {
    if (_session.phase == WordBlasterPhase.gameOver) return;
    _session.pause();
    _ctx.audio.pauseMusic();
  }

  void _resume() {
    _session.resume();
    _ctx.audio.resumeMusic();
  }

  void _onEvent(WordBlasterEvent event) {
    switch (event.kind) {
      case WordBlasterEventKind.questionStarted:
        _replaysLeft = maxReplays;
        if (_session.mode == WordBlasterMode.listening ||
            _session.question?.audioText != null) {
          _speakPrompt(countReplay: false);
        }
      case WordBlasterEventKind.waveCleared:
        _showBanner(_session.isBossWave
            ? (_session.bossActive
                ? 'Boss incoming!'
                : 'Bonus wave! x1.5 points')
            : 'Wave ${event.value} cleared!');
      case WordBlasterEventKind.overheated:
        _showBanner('Overheated! Aim carefully');
      case WordBlasterEventKind.gameOver:
        unawaited(_finish());
      default:
        break;
    }
  }

  void _showBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _banner = text);
    _bannerTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  Future<void> _speakPrompt({bool countReplay = true}) async {
    final text = _session.question?.audioText;
    final speak = _ctx.speak;
    if (text == null || speak == null) return;
    if (countReplay) {
      if (_replaysLeft <= 0) return;
      setState(() => _replaysLeft--);
    }
    try {
      await speak(text, _ctx.ttsLanguageCode);
    } on Object {
      if (mounted && !_audioFailed) {
        _audioFailed = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Audio is not available on this device right now.')),
        );
      }
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _ctx.audio.stopMusic();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final summary = WordBlasterRoundSummary(
      clientRoundId: const Uuid().v4(),
      mode: widget.mode,
      score: _session.score,
      correct: _session.correctCount,
      answered: _session.answered,
      bestCombo: _session.bestCombo,
      wave: _session.wave,
      durationMs: DateTime.now().toUtc().difference(_startedAt).inMilliseconds,
      language: _ctx.language,
      completedAt: DateTime.now().toUtc(),
      missedTerms: [for (final w in _session.missedWords) w.term],
    );
    await _ctx.learning.finishRound();
    await _ctx.stats.recordRound(summary);
    _ctx.onRoundFinished?.call(summary);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WordBlasterRecapScreen(
          context: _ctx,
          summary: summary,
          outcomes: _session.outcomes,
          pool: widget.pool,
        ),
      ),
    );
  }

  Future<void> _confirmQuit() async {
    _pause();
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this round?'),
        content: const Text('Answers so far are saved as reviews.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End round'),
          ),
        ],
      ),
    );
    if (quit == true) {
      _session.quit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _session.isOver && !_finishing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_session.isOver) _pause();
      },
      child: Scaffold(
        backgroundColor: WordBlasterPalette.skyTop,
        body: SafeArea(
          child: Column(
            children: [
              _Hud(
                session: _session,
                onPause: _pause,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GameWidget<WordBlasterGame>(
                        key: const ValueKey('word-blaster-game'),
                        game: _game!,
                      ),
                    ),
                    if (_banner != null)
                      Positioned(
                        top: 24,
                        left: 0,
                        right: 0,
                        child: Center(child: _BannerChip(text: _banner!)),
                      ),
                    if (_countdown > 0)
                      Positioned.fill(child: _Countdown(value: _countdown)),
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: _session,
                        builder: (context, _) => _session.isPaused
                            ? _PauseOverlay(
                                onResume: _resume,
                                onSettings: () => showGameSettingsSheet(
                                    context, _ctx.settings),
                                onQuit: _confirmQuit,
                              )
                            : const IgnorePointer(child: SizedBox.expand()),
                      ),
                    ),
                  ],
                ),
              ),
              _PromptPanel(
                session: _session,
                replaysLeft: _replaysLeft,
                canSpeak: _ctx.speak != null,
                onReplay: () => _speakPrompt(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.session, required this.onPause});

  final WordBlasterSession session;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final hasLives = session.mode.hasLives;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
          child: Row(
            children: [
              if (hasLives)
                Semantics(
                  label: 'Lives: ${session.lives}',
                  child: Row(
                    children: [
                      for (var i = 0; i < WordBlasterSession.maxLives; i++)
                        if (i < session.lives ||
                            i < WordBlasterSession.startingLives)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              i < session.lives
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 22,
                              color: const Color(0xFFFF5C7A),
                            ),
                          ),
                    ],
                  ),
                )
              else
                _HudChip(
                  key: const ValueKey('word-blaster-timer'),
                  icon: Icons.timer_outlined,
                  text: '${session.timeLeft.ceil()}s',
                  color: session.timeLeft <= 10
                      ? const Color(0xFFFF5C7A)
                      : Colors.white,
                ),
              const SizedBox(width: 8),
              if (session.shieldCharges > 0)
                const Icon(Icons.shield_rounded,
                    size: 20, color: Color(0xFF60A5FA)),
              if (session.slowMotionLeft > 0)
                const Icon(Icons.ac_unit_rounded,
                    size: 20, color: Color(0xFF7DD3FC)),
              const Spacer(),
              if (session.multiplier > 1)
                _HudChip(
                  icon: Icons.local_fire_department_rounded,
                  text: 'x${session.multiplier}',
                  color: const Color(0xFFFFC857),
                ),
              const SizedBox(width: 6),
              _HudChip(
                  icon: Icons.waves_rounded,
                  text: 'W${session.wave}',
                  color: Colors.white70),
              const SizedBox(width: 6),
              Semantics(
                label: 'Score ${session.score}',
                child: Text(
                  '${session.score}',
                  key: const ValueKey('word-blaster-score'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Pause',
                onPressed: session.isOver ? null : onPause,
                icon: const Icon(Icons.pause_rounded, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip(
      {required this.icon, required this.text, required this.color, super.key});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PromptPanel extends StatelessWidget {
  const _PromptPanel({
    required this.session,
    required this.replaysLeft,
    required this.canSpeak,
    required this.onReplay,
  });

  final WordBlasterSession session;
  final int replaysLeft;
  final bool canSpeak;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final q = session.question;
        final listening = q?.audioText != null && q!.prompt.isEmpty;
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: q == null
              ? Center(
                  child: Text('Get ready…', style: theme.textTheme.titleMedium),
                )
              : Semantics(
                  liveRegion: true,
                  label: listening
                      ? 'Listen and shoot the word you hear'
                      : 'Prompt: ${q.prompt}',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (listening)
                        FilledButton.tonalIcon(
                          key: const ValueKey('word-blaster-replay'),
                          onPressed:
                              canSpeak && replaysLeft > 0 ? onReplay : null,
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text('Play again ($replaysLeft left)'),
                        )
                      else
                        Text(
                          q.prompt,
                          key: const ValueKey('word-blaster-prompt'),
                          textAlign: TextAlign.center,
                          style: (q.mode == WordBlasterMode.fillGap
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.headlineSmall)
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      if (q.promptHint != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          q.promptHint!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(value),
          tween: Tween(begin: 1.6, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Text(
            '$value',
            style: const TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFC857),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC3B2A7A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC857)),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onSettings,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onSettings;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xDD0B1026),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_outline,
                size: 64, color: Color(0xFFFFC857)),
            const SizedBox(height: 12),
            const Text(
              'Paused',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSettings,
              icon: const Icon(Icons.tune),
              label: const Text('Settings'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onQuit,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('End round'),
            ),
          ],
        ),
      ),
    );
  }
}

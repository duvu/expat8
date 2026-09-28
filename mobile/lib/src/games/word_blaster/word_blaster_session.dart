import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/vocabulary_word.dart';
import 'question_generator.dart';
import 'word_blaster_mode.dart';
import 'word_pool.dart';

enum WordBlasterPhase { ready, playing, reveal, waveBreak, paused, gameOver }

enum PowerUpKind { slowMotion, bomb, shield, heart }

enum WordBlasterEventKind {
  questionStarted,
  correct,
  wrong,
  missed,
  comboUp,
  lifeLost,
  shieldBlocked,
  overheated,
  powerUpSpawned,
  powerUpCollected,
  waveCleared,
  bossAppeared,
  bossHit,
  bossDefeated,
  gameOver,
}

class WordBlasterEvent {
  const WordBlasterEvent(this.kind,
      {this.meteorId, this.points, this.value, this.powerUp});

  final WordBlasterEventKind kind;
  final int? meteorId;
  final int? points;

  /// Multiplier for comboUp, wave number for waveCleared, etc.
  final int? value;
  final PowerUpKind? powerUp;
}

/// A falling answer. [x] is the lane centre (0..1), [progress] 0 = top,
/// 1 = ground.
class MeteorState {
  MeteorState({
    required this.id,
    required this.label,
    required this.isCorrect,
    required this.x,
    required this.spawnDelay,
  });

  final int id;
  final String label;
  final bool isCorrect;
  final double x;
  double spawnDelay;
  double progress = 0;
  bool destroyed = false;

  bool get visible => spawnDelay <= 0 && !destroyed;
}

class PowerUpState {
  PowerUpState({required this.id, required this.kind, required this.x});

  final int id;
  final PowerUpKind kind;
  final double x;
  double progress = 0;
}

/// Outcome of the first time a word was asked in this round (drives SRS).
class WordOutcome {
  const WordOutcome(
    this.word, {
    required this.correct,
    this.prompt = '',
    this.options = const [],
  });

  final VocabularyWord word;
  final bool correct;

  /// The question as shown, for "report a wrong question".
  final String prompt;
  final List<String> options;
}

/// Rules and state for one Word Blaster round. Time advances only through
/// [update], so the renderer's game loop drives it and tests can step it.
class WordBlasterSession extends ChangeNotifier {
  WordBlasterSession({
    required this.mode,
    required WordPool pool,
    required int learnerLevelIndex,
    Random? random,
    this.paceMultiplier = 1.0,
    this.onWordOutcome,
  })  : _random = random ?? Random(),
        _generator = QuestionGenerator(
            pool: pool, mode: mode, random: random ?? Random()),
        _phrases = pool.allWords
            .where((w) => w.entryType == 'phrase' || w.entryType == 'idiom')
            .toList(),
        _baseFallSeconds = max(minFallSeconds, 9.0 - learnerLevelIndex * 0.6) {
    lives = mode.hasLives ? startingLives : 0;
    timeLeft = mode == WordBlasterMode.timeAttack ? timeAttackSeconds : 0;
  }

  static const startingLives = 3;
  static const maxLives = 5;
  static const questionsPerWave = 8;
  static const bossEvery = 5;
  static const bossHealth = 3;
  static const minFallSeconds = 3.5;
  static const revealSeconds = 1.2;
  static const waveBreakSeconds = 1.6;
  static const timeAttackSeconds = 60.0;
  static const timeAttackPenalty = 3.0;
  static const overheatSeconds = 1.5;

  /// Three wrong answers inside this window overheat the cannon. Each wrong
  /// answer already pauses for [revealSeconds], so the window must cover it.
  static const overheatWindowSeconds = 6.0;
  static const powerUpChance = 0.12;
  static const slowMotionSeconds = 5.0;

  final WordBlasterMode mode;

  /// < 1 slows the game (reduced motion setting).
  final double paceMultiplier;

  /// Called once per word, the first time it is answered in this round, so
  /// the learning record survives even if the app is closed mid-round.
  final void Function(WordOutcome outcome)? onWordOutcome;

  final Random _random;
  final QuestionGenerator _generator;
  final List<VocabularyWord> _phrases;
  final double _baseFallSeconds;
  final StreamController<WordBlasterEvent> _events =
      StreamController<WordBlasterEvent>.broadcast();

  Stream<WordBlasterEvent> get events => _events.stream;

  WordBlasterPhase phase = WordBlasterPhase.ready;
  WordBlasterPhase _phaseBeforePause = WordBlasterPhase.playing;
  WordBlasterQuestion? question;
  final List<MeteorState> meteors = [];
  PowerUpState? powerUp;

  int lives = startingLives;
  double timeLeft = 0;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int wave = 1;
  int questionInWave = 0;
  int correctCount = 0;
  int wrongCount = 0;
  int missedCount = 0;
  double elapsed = 0;

  double speedMultiplier = 1.0;
  int distractorAdjustment = 0;
  double slowMotionLeft = 0;
  int shieldCharges = 0;
  double overheatLeft = 0;

  bool bossActive = false;
  int bossHealthLeft = 0;
  bool fastWave = false;

  int _waveCorrect = 0;
  int _waveAnswered = 0;
  double _phaseTimer = 0;
  final List<double> _recentWrongTaps = [];
  int _nextId = 1;
  final Map<String, WordOutcome> _outcomes = {};

  /// First-encounter outcome per word, in order asked.
  List<WordOutcome> get outcomes => List.unmodifiable(_outcomes.values);
  List<VocabularyWord> get missedWords => [
        for (final o in _outcomes.values)
          if (!o.correct) o.word
      ];

  int get answered => correctCount + wrongCount + missedCount;
  double get accuracy => answered == 0 ? 0 : correctCount / answered;

  int get multiplier => combo >= 20
      ? 4
      : combo >= 10
          ? 3
          : combo >= 5
              ? 2
              : 1;

  bool get isOver => phase == WordBlasterPhase.gameOver;
  bool get isPaused => phase == WordBlasterPhase.paused;
  bool get isOverheated => overheatLeft > 0;

  /// Seconds for a meteor to fall the whole screen right now.
  double get fallSeconds {
    var seconds = _baseFallSeconds / (speedMultiplier * (fastWave ? 1.15 : 1));
    seconds /= paceMultiplier;
    return max(minFallSeconds, seconds);
  }

  int get distractorCount =>
      max(2, QuestionGenerator.distractorsForWave(wave) + distractorAdjustment);

  bool get isBossWave => wave % bossEvery == 0;

  void start() {
    if (phase != WordBlasterPhase.ready) return;
    phase = WordBlasterPhase.playing;
    _beginWave();
    _nextQuestion();
    notifyListeners();
  }

  void pause() {
    if (phase == WordBlasterPhase.paused ||
        phase == WordBlasterPhase.gameOver ||
        phase == WordBlasterPhase.ready) {
      return;
    }
    _phaseBeforePause = phase;
    phase = WordBlasterPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (phase != WordBlasterPhase.paused) return;
    phase = _phaseBeforePause;
    notifyListeners();
  }

  /// Ends the round early (e.g. the learner quits).
  void quit() {
    if (phase == WordBlasterPhase.gameOver) return;
    _endGame();
  }

  void update(double dt) {
    if (dt <= 0) return;
    switch (phase) {
      case WordBlasterPhase.ready:
      case WordBlasterPhase.paused:
      case WordBlasterPhase.gameOver:
        return;
      case WordBlasterPhase.reveal:
        elapsed += dt;
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) _afterQuestion();
        _tickTimers(dt);
      case WordBlasterPhase.waveBreak:
        elapsed += dt;
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) {
          phase = WordBlasterPhase.playing;
          _nextQuestion();
        }
        _tickTimers(dt);
      case WordBlasterPhase.playing:
        elapsed += dt;
        _tickTimers(dt);
        if (isOver) break;
        _advanceMeteors(dt);
    }
    notifyListeners();
  }

  void _tickTimers(double dt) {
    if (overheatLeft > 0) overheatLeft = max(0, overheatLeft - dt);
    if (slowMotionLeft > 0) slowMotionLeft = max(0, slowMotionLeft - dt);
    if (mode == WordBlasterMode.timeAttack &&
        phase != WordBlasterPhase.gameOver) {
      timeLeft -= dt;
      if (timeLeft <= 0) {
        timeLeft = 0;
        _endGame();
      }
    }
  }

  void _advanceMeteors(double dt) {
    final step = dt / fallSeconds * (slowMotionLeft > 0 ? 0.5 : 1);
    for (final m in meteors) {
      if (m.destroyed) continue;
      if (m.spawnDelay > 0) {
        m.spawnDelay -= dt;
        continue;
      }
      m.progress += step;
      if (m.progress >= 1) {
        if (m.isCorrect) {
          _onMissed();
          return;
        }
        m.destroyed = true;
      }
    }
    final p = powerUp;
    if (p != null) {
      p.progress += step * 0.8;
      if (p.progress >= 1) powerUp = null;
    }
  }

  /// The learner shot [meteorId]. Returns false when the shot was ignored
  /// (not playing, overheated, or already destroyed).
  bool shoot(int meteorId) {
    if (phase != WordBlasterPhase.playing || isOverheated) return false;
    final meteor =
        meteors.where((m) => m.id == meteorId && m.visible).firstOrNull;
    if (meteor == null) return false;
    meteor.destroyed = true;
    if (meteor.isCorrect) {
      _onCorrect(meteor);
    } else {
      _onWrong(meteor);
    }
    notifyListeners();
    return true;
  }

  /// The learner tapped the falling power-up.
  bool collectPowerUp() {
    final p = powerUp;
    if (p == null || phase != WordBlasterPhase.playing) return false;
    powerUp = null;
    switch (p.kind) {
      case PowerUpKind.slowMotion:
        slowMotionLeft = slowMotionSeconds;
      case PowerUpKind.bomb:
        for (final m in meteors) {
          if (!m.isCorrect) m.destroyed = true;
        }
      case PowerUpKind.shield:
        shieldCharges = 1;
      case PowerUpKind.heart:
        lives = min(maxLives, lives + 1);
    }
    _emit(WordBlasterEvent(WordBlasterEventKind.powerUpCollected,
        powerUp: p.kind));
    notifyListeners();
    return true;
  }

  void _onCorrect(MeteorState meteor) {
    final previousMultiplier = multiplier;
    combo++;
    bestCombo = max(bestCombo, combo);
    correctCount++;
    _waveCorrect++;
    _waveAnswered++;
    _record(correct: true);
    final speedBonus = 1.5 - 0.5 * meteor.progress.clamp(0.0, 1.0);
    var points = (100 * multiplier * speedBonus).round();
    if (fastWave) points = (points * 1.5).round();
    score += points;
    _emit(WordBlasterEvent(WordBlasterEventKind.correct,
        meteorId: meteor.id, points: points));
    if (multiplier > previousMultiplier) {
      _emit(WordBlasterEvent(WordBlasterEventKind.comboUp, value: multiplier));
    }
    if (bossActive) {
      bossHealthLeft--;
      _emit(WordBlasterEvent(WordBlasterEventKind.bossHit,
          value: bossHealthLeft));
      if (bossHealthLeft <= 0) {
        bossActive = false;
        score += 1000;
        if (mode.hasLives) lives = min(maxLives, lives + 1);
        _emit(const WordBlasterEvent(WordBlasterEventKind.bossDefeated,
            points: 1000));
      }
    }
    _afterQuestion();
  }

  void _onWrong(MeteorState meteor) {
    wrongCount++;
    _waveAnswered++;
    combo = 0;
    _record(correct: false);
    _emit(WordBlasterEvent(WordBlasterEventKind.wrong, meteorId: meteor.id));
    _recentWrongTaps
      ..add(elapsed)
      ..removeWhere((t) => elapsed - t > overheatWindowSeconds);
    if (_recentWrongTaps.length >= 3) {
      overheatLeft = overheatSeconds;
      _recentWrongTaps.clear();
      _emit(const WordBlasterEvent(WordBlasterEventKind.overheated));
    }
    _penalize();
    if (!isOver) _reveal();
  }

  void _onMissed() {
    missedCount++;
    _waveAnswered++;
    combo = 0;
    _record(correct: false);
    _emit(const WordBlasterEvent(WordBlasterEventKind.missed));
    _penalize();
    if (!isOver) _reveal();
  }

  void _penalize() {
    final q = question;
    if (q != null) _generator.requeue(q.word);
    if (mode == WordBlasterMode.timeAttack) {
      timeLeft = max(0, timeLeft - timeAttackPenalty);
      if (timeLeft <= 0) _endGame();
      return;
    }
    if (shieldCharges > 0) {
      shieldCharges--;
      _emit(const WordBlasterEvent(WordBlasterEventKind.shieldBlocked));
      return;
    }
    lives--;
    _emit(WordBlasterEvent(WordBlasterEventKind.lifeLost, value: lives));
    if (lives <= 0) _endGame();
  }

  void _record({required bool correct}) {
    final q = question;
    if (q == null) return;
    final key = '${q.word.language}:${q.word.term.toLowerCase()}';
    if (_outcomes.containsKey(key)) return;
    final outcome = WordOutcome(
      q.word,
      correct: correct,
      prompt: q.prompt.isEmpty ? (q.audioText ?? '') : q.prompt,
      options: q.options,
    );
    _outcomes[key] = outcome;
    onWordOutcome?.call(outcome);
  }

  void _reveal() {
    phase = WordBlasterPhase.reveal;
    _phaseTimer = revealSeconds;
    for (final m in meteors) {
      if (!m.isCorrect) m.destroyed = true;
    }
  }

  void _afterQuestion() {
    if (isOver) return;
    questionInWave++;
    final waveDone = bossActive
        ? false
        : (isBossWave && _bossWasUsed) || questionInWave >= questionsPerWave;
    if (waveDone) {
      _finishWave();
      return;
    }
    phase = WordBlasterPhase.playing;
    _nextQuestion();
  }

  bool _bossWasUsed = false;

  void _beginWave() {
    questionInWave = 0;
    _waveCorrect = 0;
    _waveAnswered = 0;
    fastWave = false;
    _bossWasUsed = false;
    if (isBossWave) {
      if (_phrases.length >= bossHealth) {
        bossActive = true;
        _bossWasUsed = true;
        bossHealthLeft = bossHealth;
        _emit(const WordBlasterEvent(WordBlasterEventKind.bossAppeared));
      } else {
        fastWave = true;
      }
    }
  }

  void _finishWave() {
    final waveAccuracy =
        _waveAnswered == 0 ? 1.0 : _waveCorrect / _waveAnswered;
    if (waveAccuracy >= 0.9) {
      speedMultiplier *= 1.08;
    } else if (waveAccuracy < 0.6) {
      speedMultiplier *= 0.9;
      distractorAdjustment = max(
        2 - QuestionGenerator.distractorsForWave(wave + 1),
        distractorAdjustment - 1,
      );
    }
    _emit(WordBlasterEvent(WordBlasterEventKind.waveCleared, value: wave));
    wave++;
    _beginWave();
    phase = WordBlasterPhase.waveBreak;
    _phaseTimer = waveBreakSeconds;
    meteors.clear();
    powerUp = null;
  }

  void _nextQuestion() {
    WordBlasterQuestion q;
    if (bossActive) {
      final word = _phrases[_random.nextInt(_phrases.length)];
      q = QuestionGenerator(
        pool: WordPool(roundWords: [word], allWords: _generator.pool.allWords),
        mode:
            mode == WordBlasterMode.fillGap || mode == WordBlasterMode.listening
                ? WordBlasterMode.classic
                : mode,
        random: _random,
      ).next(distractors: distractorCount);
    } else {
      q = _generator.next(distractors: distractorCount);
    }
    question = q;
    meteors.clear();
    final lanes = List<int>.generate(q.options.length, (i) => i)
      ..shuffle(_random);
    for (var i = 0; i < q.options.length; i++) {
      meteors.add(MeteorState(
        id: _nextId++,
        label: q.options[i],
        isCorrect: i == q.correctIndex,
        x: (lanes[i] + 0.5) / q.options.length,
        spawnDelay: _random.nextDouble() * 0.6,
      ));
    }
    _maybeSpawnPowerUp();
    _emit(const WordBlasterEvent(WordBlasterEventKind.questionStarted));
  }

  void _maybeSpawnPowerUp() {
    if (powerUp != null || _random.nextDouble() >= powerUpChance) return;
    final kinds = [
      PowerUpKind.slowMotion,
      PowerUpKind.bomb,
      if (mode.hasLives) PowerUpKind.shield,
      if (mode.hasLives && lives == 1) PowerUpKind.heart,
    ];
    powerUp = PowerUpState(
      id: _nextId++,
      kind: kinds[_random.nextInt(kinds.length)],
      x: 0.1 + _random.nextDouble() * 0.8,
    );
    _emit(WordBlasterEvent(WordBlasterEventKind.powerUpSpawned,
        powerUp: powerUp!.kind));
  }

  void _endGame() {
    if (phase == WordBlasterPhase.gameOver) return;
    phase = WordBlasterPhase.gameOver;
    powerUp = null;
    _emit(const WordBlasterEvent(WordBlasterEventKind.gameOver));
    notifyListeners();
  }

  void _emit(WordBlasterEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}

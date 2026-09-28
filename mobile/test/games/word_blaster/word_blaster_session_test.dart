import 'dart:math';

import 'package:expat8_language_app/src/games/word_blaster/word_blaster_mode.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_blaster_session.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_pool.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';

import 'word_blaster_fixtures.dart';

WordBlasterSession session({
  WordBlasterMode mode = WordBlasterMode.classic,
  List<VocabularyWord>? words,
  int seed = 1,
}) {
  final pool = (buildWordPool(
    words: words ?? sampleVocabulary(),
    learnerLevelIndex: 0,
    now: DateTime.utc(2026, 9, 28),
    random: Random(seed),
  ) as WordPoolReady)
      .pool;
  return WordBlasterSession(
    mode: mode,
    pool: pool,
    learnerLevelIndex: 0,
    random: Random(seed),
  )..start();
}

MeteorState correctMeteor(WordBlasterSession s) =>
    s.meteors.firstWhere((m) => m.isCorrect);
MeteorState wrongMeteor(WordBlasterSession s) =>
    s.meteors.firstWhere((m) => !m.isCorrect && !m.destroyed);

/// Lets all meteors spawn so they can be shot.
void spawnAll(WordBlasterSession s) => s.update(0.7);

void answerCorrectly(WordBlasterSession s) {
  spawnAll(s);
  expect(s.shoot(correctMeteor(s).id), isTrue);
}

void main() {
  test('correct shots score, build combo and advance', () {
    final s = session();
    final first = s.question;
    answerCorrectly(s);
    expect(s.correctCount, 1);
    expect(s.combo, 1);
    expect(s.score, greaterThan(100));
    expect(s.question, isNot(same(first)));
  });

  test('early shots earn more than late shots', () {
    final early = session(seed: 3);
    answerCorrectly(early);
    final late = session(seed: 3);
    spawnAll(late);
    late.update(late.fallSeconds * 0.8);
    late.shoot(correctMeteor(late).id);
    expect(early.score, greaterThan(late.score));
  });

  test('combo multiplier steps at 5, 10 and 20', () {
    final s = session();
    final events = <WordBlasterEventKind>[];
    s.events.listen((e) => events.add(e.kind));
    for (var i = 0; i < 4; i++) {
      answerCorrectly(s);
      if (s.phase == WordBlasterPhase.waveBreak) s.update(2);
    }
    expect(s.multiplier, 1);
    answerCorrectly(s);
    expect(s.multiplier, 2);
    for (var i = 0; i < 5; i++) {
      if (s.phase == WordBlasterPhase.waveBreak) s.update(2);
      answerCorrectly(s);
    }
    expect(s.multiplier, 3);
  });

  test('wrong shot costs a life, resets combo and reveals the answer',
      () async {
    final s = session();
    answerCorrectly(s);
    spawnAll(s);
    s.shoot(wrongMeteor(s).id);
    expect(s.lives, 2);
    expect(s.combo, 0);
    expect(s.phase, WordBlasterPhase.reveal);
    expect(s.meteors.where((m) => !m.destroyed).single.isCorrect, isTrue);
    s.update(WordBlasterSession.revealSeconds + 0.01);
    expect(s.phase, WordBlasterPhase.playing);
  });

  test('letting the answer reach the ground is a miss', () {
    final s = session();
    s.update(0.7);
    s.update(s.fallSeconds + 0.1);
    expect(s.missedCount, 1);
    expect(s.lives, 2);
  });

  test('three lives lost ends the round', () {
    final s = session();
    for (var i = 0; i < 3; i++) {
      spawnAll(s);
      s.shoot(wrongMeteor(s).id);
      s.update(WordBlasterSession.revealSeconds + 0.01);
      s.update(WordBlasterSession.overheatSeconds + 0.1);
    }
    expect(s.isOver, isTrue);
    expect(s.lives, 0);
  });

  test('repeated wrong answers overheat the cannon', () {
    final s = session(mode: WordBlasterMode.timeAttack);
    for (var i = 0; i < 3; i++) {
      spawnAll(s);
      s.shoot(wrongMeteor(s).id);
      s.update(WordBlasterSession.revealSeconds + 0.01);
    }
    expect(s.isOverheated, isTrue);
    for (final m in s.meteors) {
      m.spawnDelay = 0;
    }
    expect(s.shoot(correctMeteor(s).id), isFalse);
    s.update(WordBlasterSession.overheatSeconds);
    expect(s.isOverheated, isFalse);
    expect(s.shoot(correctMeteor(s).id), isTrue);
  });

  test('each word records only its first outcome', () {
    final s = session();
    final word = s.question!.word;
    spawnAll(s);
    s.shoot(wrongMeteor(s).id);
    s.update(WordBlasterSession.revealSeconds + 0.01);
    expect(s.outcomes.where((o) => o.word.term == word.term), hasLength(1));
    expect(s.missedWords.map((w) => w.term), contains(word.term));
  });

  test('time attack: no lives, mistakes cost 3 seconds, ends at zero', () {
    final s = session(mode: WordBlasterMode.timeAttack);
    expect(s.lives, 0);
    spawnAll(s);
    final before = s.timeLeft;
    s.shoot(wrongMeteor(s).id);
    expect(s.timeLeft, closeTo(before - 3, 0.001));
    expect(s.isOver, isFalse);
    for (var i = 0; i < 200 && !s.isOver; i++) {
      s.update(0.5);
    }
    expect(s.isOver, isTrue);
  });

  test('pause freezes time and meteors', () {
    final s = session();
    spawnAll(s);
    final progress = correctMeteor(s).progress;
    s.pause();
    s.update(5);
    expect(correctMeteor(s).progress, progress);
    s.resume();
    s.update(0.1);
    expect(correctMeteor(s).progress, greaterThan(progress));
  });

  test('a wave of 8 answers raises speed when accuracy is high', () {
    final s = session();
    final baseline = s.fallSeconds;
    for (var i = 0; i < WordBlasterSession.questionsPerWave; i++) {
      answerCorrectly(s);
    }
    expect(s.phase, WordBlasterPhase.waveBreak);
    expect(s.wave, 2);
    expect(s.fallSeconds, lessThan(baseline));
    s.update(WordBlasterSession.waveBreakSeconds + 0.01);
    expect(s.phase, WordBlasterPhase.playing);
  });

  test('a poor wave slows down and removes a distractor', () {
    final s = session(mode: WordBlasterMode.timeAttack);
    for (var i = 0; i < 8; i++) {
      spawnAll(s);
      if (i < 5) {
        s.shoot(wrongMeteor(s).id);
        s.update(WordBlasterSession.revealSeconds + 0.01);
        s.update(WordBlasterSession.overheatSeconds);
      } else {
        s.shoot(correctMeteor(s).id);
      }
    }
    expect(s.wave, 2);
    expect(s.speedMultiplier, lessThan(1));
    expect(s.distractorCount, 2);
  });

  test('boss wave needs 3 correct phrase answers and restores a life', () {
    final phrases = [
      for (var i = 0; i < 4; i++)
        vocab('phrase $i', 'cụm từ $i', entryType: 'phrase', pos: 'phrase'),
    ];
    final s = session(words: [...sampleVocabulary(), ...phrases]);
    s.wave = 5; // jump to a boss wave
    s.questionInWave = WordBlasterSession.questionsPerWave;
    // Finish the current question to trigger wave logic from wave 5.
    s.wave = 4;
    for (var i = 0; i < WordBlasterSession.questionsPerWave; i++) {
      answerCorrectly(s);
      if (s.phase == WordBlasterPhase.waveBreak) break;
    }
    s.update(WordBlasterSession.waveBreakSeconds + 0.01);
    expect(s.wave, 5);
    expect(s.bossActive, isTrue);
    spawnAll(s);
    s.shoot(wrongMeteor(s).id); // lose a life during the boss
    s.update(WordBlasterSession.revealSeconds + 0.01);
    final livesBefore = s.lives;
    final scoreBefore = s.score;
    for (var i = 0; i < 3; i++) {
      expect(s.question!.word.entryType, 'phrase');
      answerCorrectly(s);
    }
    expect(s.bossActive, isFalse);
    expect(s.lives, livesBefore + 1);
    expect(s.score - scoreBefore, greaterThan(1000));
    expect(s.phase, WordBlasterPhase.waveBreak);
  });

  test('boss wave without phrases becomes a fast bonus wave', () {
    final s = session();
    s.wave = 4;
    for (var i = 0; i < WordBlasterSession.questionsPerWave; i++) {
      answerCorrectly(s);
    }
    expect(s.wave, 5);
    expect(s.bossActive, isFalse);
    expect(s.fastWave, isTrue);
  });

  group('power-ups', () {
    WordBlasterSession withPowerUp(PowerUpKind kind) {
      final s = session();
      s.powerUp = PowerUpState(id: 999, kind: kind, x: 0.5);
      return s;
    }

    test('bomb clears distractors', () {
      final s = withPowerUp(PowerUpKind.bomb);
      spawnAll(s);
      s.collectPowerUp();
      expect(s.meteors.where((m) => !m.destroyed).single.isCorrect, isTrue);
    });

    test('shield absorbs the next life loss', () {
      final s = withPowerUp(PowerUpKind.shield);
      s.collectPowerUp();
      spawnAll(s);
      s.shoot(wrongMeteor(s).id);
      expect(s.lives, 3);
      expect(s.shieldCharges, 0);
    });

    test('slow motion halves the fall speed for 5 seconds', () {
      final s = withPowerUp(PowerUpKind.slowMotion);
      s.collectPowerUp();
      spawnAll(s);
      final before = correctMeteor(s).progress;
      s.update(1);
      final slowStep = correctMeteor(s).progress - before;
      expect(slowStep, closeTo(0.5 / s.fallSeconds, 0.01));
    });

    test('heart restores a life up to the maximum', () {
      final s = withPowerUp(PowerUpKind.heart);
      s.collectPowerUp();
      expect(s.lives, 4);
    });
  });
}

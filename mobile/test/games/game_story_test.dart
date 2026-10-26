import 'dart:io';

import 'package:expat8_language_app/src/games/common/game_audio.dart';
import 'package:expat8_language_app/src/games/common/game_story.dart';
import 'package:expat8_language_app/src/games/common/game_theme.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_catalog.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math/math_test_utils.dart';

class _RecordingAudio implements GameAudioPlayer {
  final List<String> calls = [];

  @override
  void playLevelUp() => calls.add('levelUp');

  @override
  void startMusic({
    GameVisualTheme theme = GameVisualTheme.space,
    GameStoryChapter chapter = GameStoryChapter.one,
  }) =>
      calls.add(GameStory.musicFile(theme, chapter));
}

void main() {
  test('chapters stop at the summit instead of cycling back', () {
    expect(GameStoryChapter.forLevel(0), GameStoryChapter.one);
    expect(GameStoryChapter.forLevel(5), GameStoryChapter.five);
    expect(GameStoryChapter.forLevel(42), GameStoryChapter.five);
    expect(GameStoryChapter.forProgress(11, 6), GameStoryChapter.two);
    expect(GameStoryChapter.forProgress(12, 6), GameStoryChapter.three);
  });

  test('every chapter fires a stronger, more brilliant shot than the last', () {
    for (final theme in GameVisualTheme.values) {
      final shots = [
        for (final c in GameStoryChapter.values) GameStory.stage(theme, c).shot,
      ];
      for (var i = 1; i < shots.length; i++) {
        final weaker = shots[i - 1], stronger = shots[i];
        expect(stronger.glow, greaterThan(weaker.glow),
            reason: '$theme $i glow');
        expect(stronger.trail, greaterThan(weaker.trail),
            reason: '$theme $i trail');
        expect(stronger.impactParticles, greaterThan(weaker.impactParticles),
            reason: '$theme $i burst');
      }
      expect(shots.last.sparkles, greaterThan(0));
      expect(shots.last.width, greaterThan(shots.first.width));
    }
  });

  test('music and shot sounds ship for every theme and chapter', () {
    for (final theme in GameVisualTheme.values) {
      for (final chapter in GameStoryChapter.values) {
        final file =
            File('assets/audio/${GameStory.musicFile(theme, chapter)}');
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    }
    for (final chapter in GameStoryChapter.values) {
      final shot = File('assets/audio/${GameSound.shotFor(chapter).file}');
      expect(shot.existsSync(), isTrue, reason: shot.path);
    }
    expect(File('assets/audio/${GameSound.levelUp.file}').existsSync(), isTrue);
  });

  test('the driver only moves forward and upgrades music on each chapter',
      () async {
    final audio = _RecordingAudio();
    final progress = GameStoryProgress(InMemoryGameStorage());
    final driver = GameStoryDriver(
        audio: audio, theme: GameVisualTheme.easter, progress: progress);

    driver.start();
    expect(audio.calls, ['music_easter_1.ogg']);
    expect(driver.reach(GameStoryChapter.one), isFalse);
    expect(driver.reach(GameStoryChapter.three), isTrue);
    expect(
        audio.calls, ['music_easter_1.ogg', 'levelUp', 'music_easter_3.ogg']);
    expect(driver.reach(GameStoryChapter.two), isFalse, reason: 'never back');
    expect(driver.stage.title, 'Rainbow Woods');

    await Future<void>.delayed(Duration.zero);
    expect(await progress.best(GameVisualTheme.easter), GameStoryChapter.three);
    expect(await progress.best(GameVisualTheme.space), GameStoryChapter.one);
  });

  testWidgets('Number Blaster opens chapter 2 after six problems',
      (tester) async {
    final ctx = mathContext(seed: 3);
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.blaster),
        level: 'grade1');
    expect(find.text('1 · Earth Orbit'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      final answer = evaluate(targetLabel(tester));
      await tester.tap(find.byKey(ValueKey('blaster-choice-$answer')));
      await frames(tester, 3);
    }
    expect(find.text('2 · Moon Base'), findsOneWidget);
    expect(find.text('New weapon: Twin laser'), findsOneWidget);
    expect(await ctx.story.best(GameVisualTheme.space), GameStoryChapter.two);
  });
}

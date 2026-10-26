import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import 'game_settings.dart';
import 'game_story.dart';
import 'game_theme.dart';

/// Sound effects shipped in assets/audio (tool/generate_game_audio.py and
/// tool/generate_stage_audio.py).
enum GameSound {
  shoot('shot_1.wav'),
  shotTwin('shot_2.wav'),
  shotPlasma('shot_3.wav'),
  shotBeam('shot_4.wav'),
  shotNova('shot_5.wav'),
  levelUp('levelup.wav'),
  hit('hit.wav'),
  wrong('wrong.wav'),
  combo('combo.wav'),
  powerUp('powerup.wav'),
  boss('boss.wav'),
  gameOver('gameover.wav'),
  select('select.wav'),
  solved('solved.wav');

  const GameSound(this.file);
  final String file;

  /// The cannon sound for a chapter: stronger as the story advances.
  static GameSound shotFor(GameStoryChapter chapter) => const [
        shoot,
        shotTwin,
        shotPlasma,
        shotBeam,
        shotNova,
      ][chapter.index];
}

enum GameHaptic { light, medium, heavy, selection }

/// Plays sounds, music and haptics according to [GameSettings]. Every call is
/// best effort: missing audio support (tests, some emulators) never throws.
class GameAudio implements GameAudioPlayer {
  GameAudio(this.settings, {this.enabled = true});

  /// A silent instance for tests and previews.
  GameAudio.silent(this.settings) : enabled = false;

  final GameSettings settings;
  final bool enabled;
  bool _musicPlaying = false;
  String? _musicFile;

  // Last requested track, so resuming after a pause restores the chapter.
  GameVisualTheme _theme = GameVisualTheme.space;
  GameStoryChapter _chapter = GameStoryChapter.one;
  Future<void> _musicChanges = Future.value();

  // FlameAudio.play creates (and tears down) a native player for every call;
  // in a fast game that churn builds up and makes frames stutter after a few
  // minutes. Pools reuse a few players per sound instead.
  final Map<GameSound, AudioPool> _pools = {};
  Future<void>? _preloading;

  /// Sounds that fire many times per round get more simultaneous players.
  static const _busySounds = {
    GameSound.shoot,
    GameSound.shotTwin,
    GameSound.shotPlasma,
    GameSound.shotBeam,
    GameSound.shotNova,
    GameSound.hit,
    GameSound.wrong,
  };

  Future<void> preload() {
    if (!enabled) return Future.value();
    return _preloading ??= _createPools();
  }

  Future<void> _createPools() async {
    try {
      await FlameAudio.audioCache.loadAll([
        for (final s in GameSound.values) s.file,
        for (final theme in GameVisualTheme.values)
          for (final chapter in GameStoryChapter.values)
            GameStory.musicFile(theme, chapter),
      ]);
      for (final sound in GameSound.values) {
        _pools[sound] = await FlameAudio.createPool(
          sound.file,
          maxPlayers: _busySounds.contains(sound) ? 4 : 2,
        );
      }
    } on Object {
      // Audio unavailable; stay silent (play() falls back per sound).
    }
  }

  void play(GameSound sound, {double volume = 0.8}) {
    if (!enabled || !settings.sound) return;
    final pool = _pools[sound];
    if (pool != null) {
      unawaited(_guard(() => pool.start(volume: volume)));
      return;
    }
    if (_preloading == null) unawaited(preload());
    // Pools not ready yet: skip rather than spawn a throwaway player.
  }

  /// Releases the pooled players (call when leaving the games area).
  Future<void> dispose() async {
    stopMusic();
    await _musicChanges;
    final pools = List.of(_pools.values);
    _pools.clear();
    _preloading = null;
    for (final pool in pools) {
      await _guard(() => pool.dispose());
    }
  }

  /// Plays the chapter's music loop (each chapter adds instruments and
  /// tempo). Switching chapters is queued so stop/play never interleave.
  @override
  void playLevelUp() => play(GameSound.levelUp);

  @override
  void startMusic({
    GameVisualTheme theme = GameVisualTheme.space,
    GameStoryChapter chapter = GameStoryChapter.one,
  }) {
    _theme = theme;
    _chapter = chapter;
    if (!enabled || !settings.music) return;
    final file = GameStory.musicFile(theme, chapter);
    if (_musicPlaying && _musicFile == file) return;
    _musicPlaying = true;
    _musicFile = file;
    _musicChanges = _musicChanges.then((_) async {
      if (!_musicPlaying || !settings.music || _musicFile != file) return;
      await _guard(() => FlameAudio.bgm.stop());
      if (!_musicPlaying || !settings.music || _musicFile != file) return;
      await _guard(() => FlameAudio.bgm.play(file, volume: 0.35));
    });
  }

  void stopMusic() {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    _musicFile = null;
    _musicChanges =
        _musicChanges.then((_) => _guard(() => FlameAudio.bgm.stop()));
  }

  void pauseMusic() {
    if (_musicPlaying) unawaited(_guard(() => FlameAudio.bgm.pause()));
  }

  void resumeMusic() {
    if (!_musicPlaying) {
      startMusic(theme: _theme, chapter: _chapter);
      return;
    }
    if (settings.music) unawaited(_guard(() => FlameAudio.bgm.resume()));
  }

  void haptic(GameHaptic kind) {
    if (!enabled || !settings.haptics) return;
    unawaited(_guard(() => switch (kind) {
          GameHaptic.light => HapticFeedback.lightImpact(),
          GameHaptic.medium => HapticFeedback.mediumImpact(),
          GameHaptic.heavy => HapticFeedback.heavyImpact(),
          GameHaptic.selection => HapticFeedback.selectionClick(),
        }));
  }

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on Object {
      // Ignore audio/haptic failures.
    }
  }
}

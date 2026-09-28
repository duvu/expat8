import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import 'game_settings.dart';

/// Sound effects shipped in assets/audio (see tool/generate_game_audio.py).
enum GameSound {
  shoot('shoot.wav'),
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
}

enum GameHaptic { light, medium, heavy, selection }

/// Plays sounds, music and haptics according to [GameSettings]. Every call is
/// best effort: missing audio support (tests, some emulators) never throws.
class GameAudio {
  GameAudio(this.settings, {this.enabled = true});

  /// A silent instance for tests and previews.
  GameAudio.silent(this.settings) : enabled = false;

  static const musicFile = 'music_loop.wav';

  final GameSettings settings;
  final bool enabled;
  bool _musicPlaying = false;

  Future<void> preload() async {
    if (!enabled) return;
    try {
      await FlameAudio.audioCache.loadAll([
        for (final s in GameSound.values) s.file,
        musicFile,
      ]);
    } on Object {
      // Audio unavailable; stay silent.
    }
  }

  void play(GameSound sound, {double volume = 0.8}) {
    if (!enabled || !settings.sound) return;
    unawaited(_guard(() => FlameAudio.play(sound.file, volume: volume)));
  }

  void startMusic() {
    if (!enabled || !settings.music || _musicPlaying) return;
    _musicPlaying = true;
    unawaited(_guard(() => FlameAudio.bgm.play(musicFile, volume: 0.35)));
  }

  void stopMusic() {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    unawaited(_guard(() => FlameAudio.bgm.stop()));
  }

  void pauseMusic() {
    if (_musicPlaying) unawaited(_guard(() => FlameAudio.bgm.pause()));
  }

  void resumeMusic() {
    if (!_musicPlaying) {
      startMusic();
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

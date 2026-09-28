import 'dart:convert';

import 'package:flutter/material.dart';

import '../game_storage.dart';

/// Sound, music, haptics and motion preferences shared by all games.
class GameSettings extends ChangeNotifier {
  GameSettings(this.storage);

  static const _key = 'games.settings.v1';

  final GameStorage storage;

  bool sound = true;
  bool music = true;
  bool haptics = true;

  /// Disables screen shake and large particle bursts, and slows action games.
  bool reducedMotion = false;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await storage.read(_key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      sound = json['sound'] as bool? ?? sound;
      music = json['music'] as bool? ?? music;
      haptics = json['haptics'] as bool? ?? haptics;
      reducedMotion = json['reduced_motion'] as bool? ?? reducedMotion;
      notifyListeners();
    } on Object {
      // Keep defaults.
    }
  }

  Future<void> update({
    bool? sound,
    bool? music,
    bool? haptics,
    bool? reducedMotion,
  }) async {
    this.sound = sound ?? this.sound;
    this.music = music ?? this.music;
    this.haptics = haptics ?? this.haptics;
    this.reducedMotion = reducedMotion ?? this.reducedMotion;
    notifyListeners();
    await storage.write(
      _key,
      jsonEncode({
        'sound': this.sound,
        'music': this.music,
        'haptics': this.haptics,
        'reduced_motion': this.reducedMotion,
      }),
    );
  }
}

Future<void> showGameSettingsSheet(
    BuildContext context, GameSettings settings) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Game settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('Sound effects'),
              value: settings.sound,
              onChanged: (v) => settings.update(sound: v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.music_note_outlined),
              title: const Text('Music'),
              value: settings.music,
              onChanged: (v) => settings.update(music: v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Vibration'),
              value: settings.haptics,
              onChanged: (v) => settings.update(haptics: v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.motion_photos_off_outlined),
              title: const Text('Reduce motion'),
              subtitle:
                  const Text('Less shaking and fewer particles; slower pace'),
              value: settings.reducedMotion,
              onChanged: (v) => settings.update(reducedMotion: v),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

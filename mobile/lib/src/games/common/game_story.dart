import 'dart:async';

import 'package:flutter/material.dart';

import '../game_storage.dart';
import 'game_theme.dart';

/// The five chapters of the journey every game shares. A game moves to the
/// next chapter as the player progresses within a round; each chapter
/// upgrades the scenery, the music and the projectiles. Chapter 5 is the
/// summit: progress past it stays there (never cycles back to plainer art).
enum GameStoryChapter {
  one,
  two,
  three,
  four,
  five;

  int get level => index + 1;

  static GameStoryChapter forLevel(int level) =>
      values[level.clamp(1, values.length) - 1];

  /// Every [perChapter] steps of progress opens the next chapter.
  static GameStoryChapter forProgress(int count, int perChapter) =>
      forLevel(1 + count ~/ perChapter);
}

/// How a chapter's projectile looks and sounds; stronger and more brilliant
/// as chapters advance.
class ShotStyle {
  const ShotStyle({
    required this.name,
    required this.colors,
    required this.width,
    required this.glow,
    required this.trail,
    required this.impactParticles,
    this.twin = false,
    this.beam = false,
    this.sparkles = 0,
  });

  final String name;

  /// Core → outer colours (outer used for glow and trail).
  final List<Color> colors;

  /// Core thickness, as a fraction of the screen width.
  final double width;

  /// Glow radius multiplier around the core.
  final double glow;

  /// Number of fading trail ghosts.
  final int trail;
  final int impactParticles;

  /// Two parallel bolts.
  final bool twin;

  /// A continuous beam from the cannon instead of a bolt.
  final bool beam;

  /// Orbiting star sparkles around the head.
  final int sparkles;
}

/// One chapter as staged in a theme.
class StoryStage {
  const StoryStage({
    required this.title,
    required this.guideLine,
    required this.skyTop,
    required this.skyBottom,
    required this.horizon,
    required this.accent,
    required this.shot,
    required this.dark,
  });

  final String title;

  /// What the guide says when the chapter opens.
  final String guideLine;
  final Color skyTop;
  final Color skyBottom;
  final Color horizon;
  final Color accent;
  final ShotStyle shot;

  /// Dark sky (light text on top).
  final bool dark;
}

abstract final class GameStory {
  static String guide(GameVisualTheme theme) => switch (theme) {
        GameVisualTheme.space => 'Captain Nova',
        GameVisualTheme.easter => 'Bunny Bo',
      };

  static String journey(GameVisualTheme theme) => switch (theme) {
        GameVisualTheme.space => 'Star Academy',
        GameVisualTheme.easter => 'The Great Egg Hunt',
      };

  static String intro(GameVisualTheme theme) => switch (theme) {
        GameVisualTheme.space =>
          'Cadet, rogue comets are heading for Earth! Every right answer '
              'powers your cannon. Fly from Earth to the mysterious Nebula Core.',
        GameVisualTheme.easter =>
          'The magic eggs rolled away! Every right answer brings one home. '
              'Hop from the Spring Garden all the way to the Moonlit Castle.',
      };

  static String musicFile(GameVisualTheme theme, GameStoryChapter chapter) =>
      'music_${theme.name}_${chapter.level}.ogg';

  static StoryStage stage(GameVisualTheme theme, GameStoryChapter chapter) =>
      (theme == GameVisualTheme.space ? _space : _easter)[chapter.index];

  static const _space = [
    StoryStage(
      title: 'Earth Orbit',
      guideLine: 'Launch! Keep the comets away from Earth.',
      skyTop: Color(0xFF0B1026),
      skyBottom: Color(0xFF1C2B4F),
      horizon: Color(0xFF2563EB),
      accent: Color(0xFFFFC857),
      dark: true,
      shot: ShotStyle(
        name: 'Star pellet',
        colors: [Color(0xFFFFFFFF), Color(0xFFFFC857)],
        width: 0.012,
        glow: 1.6,
        trail: 2,
        impactParticles: 18,
      ),
    ),
    StoryStage(
      title: 'Moon Base',
      guideLine: 'Twin lasers online. The Moon is ours!',
      skyTop: Color(0xFF070B1C),
      skyBottom: Color(0xFF232A48),
      horizon: Color(0xFF9CA3AF),
      accent: Color(0xFF67E8F9),
      dark: true,
      shot: ShotStyle(
        name: 'Twin laser',
        colors: [Color(0xFFFFFFFF), Color(0xFF67E8F9), Color(0xFF0EA5E9)],
        width: 0.011,
        glow: 2.2,
        trail: 4,
        impactParticles: 26,
        twin: true,
      ),
    ),
    StoryStage(
      title: 'Mars Canyon',
      guideLine: 'Red storms ahead. Plasma cannon charged!',
      skyTop: Color(0xFF1A0712),
      skyBottom: Color(0xFF5A1E1C),
      horizon: Color(0xFFC2410C),
      accent: Color(0xFFF472B6),
      dark: true,
      shot: ShotStyle(
        name: 'Plasma bolt',
        colors: [Color(0xFFFFFFFF), Color(0xFFF472B6), Color(0xFFA21CAF)],
        width: 0.018,
        glow: 2.8,
        trail: 6,
        impactParticles: 34,
      ),
    ),
    StoryStage(
      title: 'Saturn\'s Rings',
      guideLine: 'Ice and rock everywhere. Ion beam ready!',
      skyTop: Color(0xFF060418),
      skyBottom: Color(0xFF2E1A55),
      horizon: Color(0xFFD4A373),
      accent: Color(0xFFA78BFA),
      dark: true,
      shot: ShotStyle(
        name: 'Ion beam',
        colors: [Color(0xFFFFFFFF), Color(0xFFA78BFA), Color(0xFF22D3EE)],
        width: 0.02,
        glow: 3.2,
        trail: 8,
        impactParticles: 44,
        beam: true,
        sparkles: 3,
      ),
    ),
    StoryStage(
      title: 'Nebula Core',
      guideLine: 'The heart of the galaxy. Fire the Nova cannon!',
      skyTop: Color(0xFF03020B),
      skyBottom: Color(0xFF2A0B3D),
      horizon: Color(0xFF7C3AED),
      accent: Color(0xFFF0ABFC),
      dark: true,
      shot: ShotStyle(
        name: 'Nova star',
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFDE68A),
          Color(0xFFF0ABFC),
          Color(0xFF22D3EE),
        ],
        width: 0.026,
        glow: 3.8,
        trail: 10,
        impactParticles: 60,
        twin: true,
        sparkles: 6,
      ),
    ),
  ];

  static const _easter = [
    StoryStage(
      title: 'Spring Garden',
      guideLine: 'The first eggs are hiding among the tulips!',
      skyTop: Color(0xFFBDE7FF),
      skyBottom: Color(0xFFFFF1F7),
      horizon: Color(0xFF6CCB6A),
      accent: Color(0xFFFF8FAB),
      dark: false,
      shot: ShotStyle(
        name: 'Jelly bean',
        // Saturated cores: white would vanish on the bright daytime skies.
        colors: [Color(0xFFE11D74), Color(0xFFFF8FAB)],
        width: 0.012,
        glow: 1.6,
        trail: 2,
        impactParticles: 18,
      ),
    ),
    StoryStage(
      title: 'Flower Meadow',
      guideLine: 'Twin petals! The meadow is blooming.',
      skyTop: Color(0xFFCDEBFF),
      skyBottom: Color(0xFFFFF6E0),
      horizon: Color(0xFF7BD389),
      accent: Color(0xFFFFB38A),
      dark: false,
      shot: ShotStyle(
        name: 'Twin petals',
        colors: [Color(0xFFEA580C), Color(0xFFFFB38A), Color(0xFFFF8FAB)],
        width: 0.011,
        glow: 2.2,
        trail: 4,
        impactParticles: 26,
        twin: true,
      ),
    ),
    StoryStage(
      title: 'Rainbow Woods',
      guideLine: 'Follow the rainbow, rainbow shots unlocked!',
      skyTop: Color(0xFFB8E1FF),
      skyBottom: Color(0xFFE8FFF1),
      horizon: Color(0xFF3FA05A),
      accent: Color(0xFF7BDFF2),
      dark: false,
      shot: ShotStyle(
        name: 'Rainbow ribbon',
        colors: [
          Color(0xFF7C3AED),
          Color(0xFFFFD166),
          Color(0xFF7BDFF2),
          Color(0xFFC4A7F5),
        ],
        width: 0.018,
        glow: 2.8,
        trail: 6,
        impactParticles: 34,
      ),
    ),
    StoryStage(
      title: 'Candy Hills',
      guideLine: 'Sweet! Your candy beam is ready.',
      skyTop: Color(0xFFFFD6E8),
      skyBottom: Color(0xFFFFF3C4),
      horizon: Color(0xFFFF8FAB),
      accent: Color(0xFFC4A7F5),
      dark: false,
      shot: ShotStyle(
        name: 'Candy beam',
        colors: [Color(0xFFDB2777), Color(0xFFFF8FAB), Color(0xFFC4A7F5)],
        width: 0.02,
        glow: 3.2,
        trail: 8,
        impactParticles: 44,
        beam: true,
        sparkles: 3,
      ),
    ),
    StoryStage(
      title: 'Moonlit Castle',
      guideLine: 'A mysterious castle under the moon. Golden stars, go!',
      skyTop: Color(0xFF1F1B4D),
      skyBottom: Color(0xFF5B3F8C),
      horizon: Color(0xFF2D2560),
      accent: Color(0xFFFDE68A),
      dark: true,
      shot: ShotStyle(
        name: 'Golden star',
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFDE68A),
          Color(0xFFF59E0B),
          Color(0xFFF0ABFC),
        ],
        width: 0.026,
        glow: 3.8,
        trail: 10,
        impactParticles: 60,
        twin: true,
        sparkles: 6,
      ),
    ),
  ];
}

/// Furthest chapter reached per theme, across all games.
class GameStoryProgress {
  GameStoryProgress(this.storage);

  final GameStorage storage;

  String _key(GameVisualTheme theme) => 'games.story.${theme.name}.best';

  Future<GameStoryChapter> best(GameVisualTheme theme) async =>
      GameStoryChapter.forLevel(
          int.tryParse(await storage.read(_key(theme)) ?? '') ?? 1);

  Future<void> record(GameVisualTheme theme, GameStoryChapter chapter) async {
    if ((await best(theme)).index >= chapter.index) return;
    await storage.write(_key(theme), '${chapter.level}');
  }
}

/// Moves a round through the story: the single place that reacts to a new
/// chapter (music upgrade, level-up sound, saved journey progress). Screens
/// only map their own progress to a chapter and redraw.
class GameStoryDriver {
  GameStoryDriver({
    required this.audio,
    required this.theme,
    required this.progress,
  });

  final GameAudioPlayer audio;
  final GameVisualTheme theme;
  final GameStoryProgress progress;
  GameStoryChapter chapter = GameStoryChapter.one;

  StoryStage get stage => GameStory.stage(theme, chapter);

  void start() => audio.startMusic(theme: theme, chapter: chapter);

  /// Advances to [next] if it is further along (chapters never go back).
  /// Returns true when a new chapter opened.
  bool reach(GameStoryChapter next) {
    if (next.index <= chapter.index) return false;
    chapter = next;
    audio.playLevelUp();
    audio.startMusic(theme: theme, chapter: next);
    unawaited(progress.record(theme, next));
    return true;
  }
}

/// What the story needs from the audio layer (keeps the driver testable and
/// independent of the Flame-based implementation).
abstract interface class GameAudioPlayer {
  void startMusic({
    GameVisualTheme theme,
    GameStoryChapter chapter,
  });
  void playLevelUp();
}

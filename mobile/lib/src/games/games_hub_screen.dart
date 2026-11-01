import 'package:flutter/material.dart';

import 'common/game_audio.dart';
import 'common/game_settings.dart';
import 'game_storage.dart';
import 'party/party_home_screen.dart';
import 'party/party_relay_host.dart';
import 'party/room_discovery.dart';
import 'quiz/quiz_catalog.dart';
import 'quiz/quiz_game_context.dart';
import 'sudoku/sudoku_home_screen.dart';
import 'word_blaster/ui/word_blaster_home_screen.dart';
import 'word_blaster/word_blaster_context.dart';
import '../widgets/brand_backdrop.dart';
import '../theme/app_radius.dart';

/// Entry point for offline mini-games. Add new games to [_games].
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({
    required this.storage,
    this.wordBlaster,
    this.quiz,
    this.roomDiscovery,
    this.partyRelay,
    super.key,
  });

  final GameStorage storage;

  /// Finds party rooms on the WiFi; bonsoir (mDNS/Bonjour) when not given.
  final RoomDiscovery? roomDiscovery;

  /// Internet play through the backend; null keeps parties on the WiFi.
  final PartyRelay? partyRelay;

  /// Shared state for the math and English games; built from [storage] when
  /// not given.
  final QuizGameContext? quiz;

  /// Null when Word Blaster is disabled by its feature flag.
  final WordBlasterContext? wordBlaster;

  QuizGameContext get _quiz {
    final given = quiz;
    if (given != null) return given;
    final settings = GameSettings(storage);
    return QuizGameContext(
        storage: storage, settings: settings, audio: GameAudio(settings));
  }

  List<_GameEntry> get _games => [
        _GameEntry(
          section: 'Play together',
          title: 'Party',
          description:
              'Quiz Night or Duel on the same WiFi or online, each on their own phone and level.',
          icon: Icons.groups_rounded,
          colors: const [Color(0xFF7C2D92), Color(0xFFE0517A)],
          builder: (_) => PartyHomeScreen(
            storage: storage,
            skillSink: _quiz.skillSink,
            discovery: roomDiscovery ?? BonsoirRoomDiscovery(),
            relay: partyRelay,
          ),
        ),
        if (wordBlaster != null)
          _GameEntry(
            section: 'Vocabulary',
            title: 'Word Blaster',
            description:
                'Shoot the right word before it lands. Every answer is a review.',
            icon: Icons.rocket_launch_rounded,
            colors: const [Color(0xFF0B1026), Color(0xFF3B2A7A)],
            builder: (_) => WordBlasterHomeScreen(context: wordBlaster!),
          ),
        for (final kind in QuizGameKind.values)
          _quizEntry(kind, quizGameInfo(kind)),
        _GameEntry(
          section: 'Relax',
          title: 'Sudoku',
          description: 'Relax your brain between lessons. 5 levels.',
          icon: Icons.grid_on_rounded,
          colors: const [Color(0xFF256D5A), Color(0xFF3D8C9E)],
          builder: (_) => SudokuHomeScreen(storage: storage),
        ),
      ];

  _GameEntry _quizEntry(QuizGameKind kind, QuizGameInfo info) => _GameEntry(
        section: '${kind.subject.title} · ${kind.subject.audience}',
        title: kind.title,
        description: info.description,
        icon: info.icon,
        colors: info.colors,
        builder: (_) => quizGameHome(_quiz, kind),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: BrandBackdrop(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Play offline. Your records stay on this device.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final (i, game) in _games.indexed) ...[
            if (i == 0 || _games[i - 1].section != game.section)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(game.section,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                borderRadius: AppRadius.surface,
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: game.colors,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: game.builder)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppRadius.card,
                            ),
                            child:
                                Icon(game.icon, size: 32, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  game.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      )),
    );
  }
}

class _GameEntry {
  const _GameEntry({
    required this.section,
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
    required this.colors,
  });

  final String section;
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
  final List<Color> colors;
}

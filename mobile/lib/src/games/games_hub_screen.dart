import 'package:flutter/material.dart';

import 'game_storage.dart';
import 'sudoku/sudoku_home_screen.dart';
import 'word_blaster/ui/word_blaster_home_screen.dart';
import 'word_blaster/word_blaster_context.dart';

/// Entry point for offline mini-games. Add new games to [_games].
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({required this.storage, this.wordBlaster, super.key});

  final GameStorage storage;

  /// Null when Word Blaster is disabled by its feature flag.
  final WordBlasterContext? wordBlaster;

  List<_GameEntry> get _games => [
        if (wordBlaster != null)
          _GameEntry(
            title: 'Word Blaster',
            description:
                'Shoot the right word before it lands. Every answer is a review.',
            icon: Icons.rocket_launch_rounded,
            colors: const [Color(0xFF0B1026), Color(0xFF3B2A7A)],
            builder: (_) => WordBlasterHomeScreen(context: wordBlaster!),
          ),
        _GameEntry(
          title: 'Sudoku',
          description: 'Relax your brain between lessons. 5 levels.',
          icon: Icons.grid_on_rounded,
          colors: const [Color(0xFF256D5A), Color(0xFF3D8C9E)],
          builder: (_) => SudokuHomeScreen(storage: storage),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Play offline. Your records stay on this device.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final game in _games)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                borderRadius: BorderRadius.circular(24),
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
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(18),
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
      ),
    );
  }
}

class _GameEntry {
  const _GameEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
    required this.colors,
  });

  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
  final List<Color> colors;
}

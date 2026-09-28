import 'package:flutter/material.dart';

import 'game_storage.dart';
import 'sudoku/sudoku_home_screen.dart';

/// Entry point for offline mini-games. Add new games to [_games].
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({required this.storage, super.key});

  final GameStorage storage;

  List<_GameEntry> get _games => [
        _GameEntry(
          title: 'Sudoku',
          description: '5 difficulty levels · champion board · offline',
          icon: Icons.grid_on,
          builder: (_) => SudokuHomeScreen(storage: storage),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final game in _games)
            Card(
              child: ListTile(
                leading: Icon(game.icon, size: 36),
                title: Text(game.title),
                subtitle: Text(game.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: game.builder)),
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
  });

  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

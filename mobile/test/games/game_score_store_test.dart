import 'dart:convert';

import 'package:expat8_language_app/src/games/common/game_score_store.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_champion_store.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

GameScore score(int value, {int minute = 0, String name = 'P'}) => GameScore(
      playerName: name,
      score: value,
      completedAt: DateTime.utc(2026, 9, 28, 8, minute),
    );

void main() {
  test('keeps the top N per mode with higher scores first', () async {
    final store =
        GameScoreStore(InMemoryGameStorage(), gameId: 'g', maxEntries: 3);
    for (final v in [100, 300, 200, 50]) {
      await store.add('classic', score(v));
    }
    await store.add('time_attack', score(999));

    expect((await store.load('classic')).map((s) => s.score), [300, 200, 100]);
    expect((await store.load('time_attack')).single.score, 999);
    expect(await store.rankFor('classic', score(250)), 2);
    expect(await store.rankFor('classic', score(10)), isNull);
    expect(await store.add('classic', score(10)), isNull);
  });

  test('ties are broken by earlier completion', () async {
    final store = GameScoreStore(InMemoryGameStorage(), gameId: 'g');
    await store.add('m', score(100, minute: 5, name: 'late'));
    await store.add('m', score(100, minute: 1, name: 'early'));
    expect((await store.load('m')).first.playerName, 'early');
  });

  test('corrupt data yields an empty board', () async {
    final storage = InMemoryGameStorage();
    await storage.write('games.g.scores.v2', '{broken');
    expect(await GameScoreStore(storage, gameId: 'g').loadAll(), isEmpty);
  });

  test('player name is shared across games', () async {
    final storage = InMemoryGameStorage();
    await GameScoreStore(storage, gameId: 'a').savePlayerName('  Linh ');
    expect(await GameScoreStore(storage, gameId: 'b').loadPlayerName(), 'Linh');
  });

  test('legacy Sudoku records are migrated into the shared store', () async {
    final storage = InMemoryGameStorage();
    await storage.write(
      SudokuChampionStore.legacyBoardKey,
      jsonEncode({
        'hard': [
          {
            'player_name': 'Old',
            'difficulty': 'hard',
            'elapsed_ms': 90000,
            'hints_used': 1,
            'mistakes': 2,
            'completed_at': '2026-09-01T00:00:00.000Z',
          },
        ],
      }),
    );

    final store = SudokuChampionStore(storage);
    final hard = await store.recordsFor(SudokuDifficulty.hard);
    expect(hard.single.playerName, 'Old');
    expect(hard.single.elapsedMs, 90000);
    expect(hard.single.hintsUsed, 1);
    expect(hard.single.mistakes, 2);
    expect(storage.values.containsKey(SudokuChampionStore.legacyBoardKey),
        isFalse);
    expect(storage.values.containsKey('games.sudoku.scores.v2'), isTrue);
  });
}

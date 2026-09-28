import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_champion_store.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

SudokuRecord record({
  int seconds = 100,
  int hints = 0,
  int mistakes = 0,
  String name = 'An',
  SudokuDifficulty difficulty = SudokuDifficulty.easy,
  int minute = 0,
}) =>
    SudokuRecord(
      playerName: name,
      difficulty: difficulty,
      elapsedMs: seconds * 1000,
      hintsUsed: hints,
      mistakes: mistakes,
      completedAt: DateTime.utc(2026, 9, 28, 8, minute),
    );

void main() {
  test('ranks by time with hint penalty, then mistakes, then date', () async {
    final store = SudokuChampionStore(InMemoryGameStorage());
    await store.addRecord(record(seconds: 100, name: 'slow'));
    await store
        .addRecord(record(seconds: 60, hints: 2, name: 'hinted')); // 120s
    await store.addRecord(record(seconds: 90, mistakes: 3, name: 'sloppy'));
    await store.addRecord(record(seconds: 90, mistakes: 0, name: 'clean'));

    final names = [
      for (final r in await store.recordsFor(SudokuDifficulty.easy))
        r.playerName,
    ];
    expect(names, ['clean', 'sloppy', 'slow', 'hinted']);
  });

  test('keeps only the top 10 per difficulty and reports rank', () async {
    final store = SudokuChampionStore(InMemoryGameStorage());
    for (var i = 0; i < 10; i++) {
      await store.addRecord(record(seconds: 100 + i, minute: i));
    }
    expect(await store.rankFor(record(seconds: 500)), isNull);
    expect(await store.addRecord(record(seconds: 500)), isNull);
    expect(await store.rankFor(record(seconds: 50)), 1);
    expect(await store.addRecord(record(seconds: 50, name: 'best')), 1);

    final easy = await store.recordsFor(SudokuDifficulty.easy);
    expect(easy, hasLength(SudokuChampionStore.maxEntries));
    expect(easy.first.playerName, 'best');
    expect(await store.recordsFor(SudokuDifficulty.expert), isEmpty);
  });

  test('stats and player name persist', () async {
    final storage = InMemoryGameStorage();
    final store = SudokuChampionStore(storage);
    await store.recordStarted(SudokuDifficulty.hard);
    await store.recordStarted(SudokuDifficulty.hard);
    await store.recordCompleted(SudokuDifficulty.hard);
    await store.savePlayerName('Linh');

    final reloaded = SudokuChampionStore(storage);
    final stats = await reloaded.loadStats();
    expect(stats[SudokuDifficulty.hard]!.started, 2);
    expect(stats[SudokuDifficulty.hard]!.completed, 1);
    expect(await reloaded.loadPlayerName(), 'Linh');
  });

  test('corrupt board data yields an empty board', () async {
    final storage = InMemoryGameStorage();
    await storage.write('games.sudoku.champions.v1', 'garbage');
    final board = await SudokuChampionStore(storage).loadBoard();
    expect(board.values.every((records) => records.isEmpty), isTrue);
  });

  test('champion board persists in the local database across reopen', () async {
    final name = 'sudoku_champions_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = await LocalDatabase.open(databaseName: name);
    await SudokuChampionStore(LocalDatabaseGameStorage(database))
        .addRecord(record(seconds: 77, name: 'Minh'));
    await database.close();

    final reopened = await LocalDatabase.open(databaseName: name);
    final records =
        await SudokuChampionStore(LocalDatabaseGameStorage(reopened))
            .recordsFor(SudokuDifficulty.easy);
    expect(records.single.playerName, 'Minh');
    expect(records.single.elapsedMs, 77000);
    await reopened.close();
  });
}

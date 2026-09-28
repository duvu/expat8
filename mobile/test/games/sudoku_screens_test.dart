import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/games_hub_screen.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_champion_store.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_difficulty.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_game_controller.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_generator.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real generated grid with only the first cell left to fill.
SudokuPuzzle oneCellLeft(SudokuDifficulty difficulty) {
  final solution =
      SudokuGenerator(random: Random(3)).generate(difficulty).solution;
  final puzzle = List<int>.of(solution)..[0] = 0;
  return SudokuPuzzle(
    puzzle: puzzle,
    solution: solution,
    difficulty: difficulty,
  );
}

void main() {
  testWidgets('games hub lists Sudoku and opens its home screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GamesHubScreen(storage: InMemoryGameStorage())),
    );
    expect(find.text('Sudoku'), findsOneWidget);

    await tester.tap(find.text('Sudoku'));
    await tester.pumpAndSettle();
    for (final d in SudokuDifficulty.values) {
      expect(find.text(d.label), findsOneWidget);
    }
  });

  testWidgets('solving a puzzle records it on the champion board',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = InMemoryGameStorage();
    final puzzle = oneCellLeft(SudokuDifficulty.hard);

    await tester.pumpWidget(
      MaterialApp(
        home: SudokuHomeScreen(
          storage: storage,
          puzzleFactory: (_) async => puzzle,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sudoku-difficulty-hard')));
    await tester.pumpAndSettle();
    expect(find.text('Sudoku · Hard'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sudoku-cell-0')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('sudoku-digit-${puzzle.solution[0]}')));
    await tester.pumpAndSettle();

    // First record on an empty board: rank #1, asks for a name.
    expect(find.text('Rank #1!'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('sudoku-player-name')), 'Lan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New champion!'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Back on the home screen with the new best time and no saved game.
    expect(find.textContaining('Lan'), findsOneWidget);
    expect(find.text('Continue game'), findsNothing);

    final records = await SudokuChampionStore(storage)
        .recordsFor(SudokuDifficulty.hard);
    expect(records.single.playerName, 'Lan');

    // Long-pressing a level opens the champion board on that level.
    await tester.longPress(find.byKey(const ValueKey('sudoku-difficulty-hard')));
    await tester.pumpAndSettle();
    expect(find.text('Champion board'), findsOneWidget);
    expect(find.text('Lan'), findsOneWidget);
  });

  testWidgets('leaving mid-game offers to continue later', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = InMemoryGameStorage();
    final puzzle = oneCellLeft(SudokuDifficulty.easy);

    await tester.pumpWidget(
      MaterialApp(
        home: SudokuHomeScreen(
          storage: storage,
          puzzleFactory: (_) async => puzzle,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sudoku-difficulty-easy')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Continue game'), findsOneWidget);
    expect(await SudokuGameController.savedDifficulty(storage),
        SudokuDifficulty.easy);

    await tester.tap(find.text('Continue game'));
    await tester.pumpAndSettle();
    expect(find.text('Sudoku · Easy'), findsOneWidget);
  });
}

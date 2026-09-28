import 'dart:math';

import 'package:expat8_language_app/src/games/sudoku/sudoku_difficulty.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectValidSolution(List<int> grid) {
    for (var i = 0; i < 9; i++) {
      final row = {for (var c = 0; c < 9; c++) grid[i * 9 + c]};
      final col = {for (var r = 0; r < 9; r++) grid[r * 9 + i]};
      final box = {
        for (var k = 0; k < 9; k++)
          grid[((i ~/ 3) * 3 + k ~/ 3) * 9 + (i % 3) * 3 + k % 3],
      };
      final digits = {1, 2, 3, 4, 5, 6, 7, 8, 9};
      expect(row, digits, reason: 'row $i');
      expect(col, digits, reason: 'column $i');
      expect(box, digits, reason: 'box $i');
    }
  }

  for (final difficulty in SudokuDifficulty.values) {
    test('${difficulty.name} puzzle has a unique, consistent solution', () {
      final puzzle = SudokuGenerator(random: Random(difficulty.index + 7))
          .generate(difficulty);

      expect(puzzle.puzzle, hasLength(81));
      expectValidSolution(puzzle.solution);
      for (var i = 0; i < 81; i++) {
        if (puzzle.puzzle[i] != 0) {
          expect(puzzle.puzzle[i], puzzle.solution[i]);
        }
      }
      expect(countSolutions(puzzle.puzzle), 1);
      expect(puzzle.givens, greaterThanOrEqualTo(difficulty.targetGivens));
      expect(puzzle.givens, lessThanOrEqualTo(difficulty.targetGivens + 8));
    });
  }

  test('harder levels give fewer digits', () {
    final generator = SudokuGenerator(random: Random(42));
    final givens = [
      for (final d in SudokuDifficulty.values) generator.generate(d).givens,
    ];
    for (var i = 1; i < givens.length; i++) {
      expect(givens[i], lessThan(givens[i - 1]), reason: '$givens');
    }
  });

  test('countSolutions detects conflicts and multiple solutions', () {
    final empty = List<int>.filled(81, 0);
    expect(countSolutions(empty, limit: 2), 2);

    final conflicting = List<int>.filled(81, 0)
      ..[0] = 5
      ..[1] = 5;
    expect(countSolutions(conflicting), 0);
  });

  test('peers and placement validity follow Sudoku rules', () {
    expect(peersOf(0), hasLength(20));
    expect(peersOf(0), containsAll([1, 8, 9, 72, 10, 20]));
    expect(peersOf(0), isNot(contains(30)));

    final grid = List<int>.filled(81, 0)..[80] = 4;
    expect(isPlacementValid(grid, 8, 4), isFalse); // same column
    expect(isPlacementValid(grid, 0, 4), isTrue);
  });
}

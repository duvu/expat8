import 'dart:math';

import 'sudoku_difficulty.dart';

/// A generated puzzle: [puzzle] uses 0 for empty cells, [solution] is the
/// unique completed grid. Both are row-major lists of 81 digits.
class SudokuPuzzle {
  const SudokuPuzzle({
    required this.puzzle,
    required this.solution,
    required this.difficulty,
  });

  final List<int> puzzle;
  final List<int> solution;
  final SudokuDifficulty difficulty;

  int get givens => puzzle.where((v) => v != 0).length;
}

/// Pure-Dart Sudoku generator and solver. Runs fully offline.
class SudokuGenerator {
  SudokuGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  SudokuPuzzle generate(SudokuDifficulty difficulty) {
    final solution = List<int>.filled(81, 0);
    _fillRandom(solution);

    final puzzle = List<int>.of(solution);
    final order = List<int>.generate(81, (i) => i)..shuffle(_random);
    var givens = 81;
    for (final index in order) {
      if (givens <= difficulty.targetGivens) {
        break;
      }
      final kept = puzzle[index];
      puzzle[index] = 0;
      if (countSolutions(puzzle, limit: 2) != 1) {
        puzzle[index] = kept;
      } else {
        givens--;
      }
    }

    return SudokuPuzzle(
      puzzle: puzzle,
      solution: solution,
      difficulty: difficulty,
    );
  }

  bool _fillRandom(List<int> grid) {
    final index = grid.indexOf(0);
    if (index == -1) {
      return true;
    }
    final digits = List<int>.generate(9, (i) => i + 1)..shuffle(_random);
    for (final digit in digits) {
      if (isPlacementValid(grid, index, digit)) {
        grid[index] = digit;
        if (_fillRandom(grid)) {
          return true;
        }
        grid[index] = 0;
      }
    }
    return false;
  }
}

/// Counts solutions of [grid] (0 = empty), stopping once [limit] is reached.
int countSolutions(List<int> grid, {int limit = 2}) {
  final work = List<int>.of(grid);
  final rows = List<int>.filled(9, 0);
  final cols = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);
  for (var i = 0; i < 81; i++) {
    final value = work[i];
    if (value == 0) continue;
    final bit = 1 << value;
    final r = i ~/ 9, c = i % 9, b = boxIndex(i);
    if ((rows[r] | cols[c] | boxes[b]) & bit != 0) {
      return 0; // givens already conflict
    }
    rows[r] |= bit;
    cols[c] |= bit;
    boxes[b] |= bit;
  }

  var count = 0;
  void search() {
    if (count >= limit) return;
    // Pick the empty cell with the fewest candidates.
    var bestIndex = -1;
    var bestMask = 0;
    var bestCount = 10;
    for (var i = 0; i < 81; i++) {
      if (work[i] != 0) continue;
      final used = rows[i ~/ 9] | cols[i % 9] | boxes[boxIndex(i)];
      final mask = ~used & 0x3FE;
      final candidates = _bitCount(mask);
      if (candidates < bestCount) {
        bestIndex = i;
        bestMask = mask;
        bestCount = candidates;
        if (candidates <= 1) break;
      }
    }
    if (bestIndex == -1) {
      count++;
      return;
    }
    if (bestCount == 0) return;
    final r = bestIndex ~/ 9, c = bestIndex % 9, b = boxIndex(bestIndex);
    for (var digit = 1; digit <= 9; digit++) {
      final bit = 1 << digit;
      if (bestMask & bit == 0) continue;
      work[bestIndex] = digit;
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
      search();
      rows[r] &= ~bit;
      cols[c] &= ~bit;
      boxes[b] &= ~bit;
      work[bestIndex] = 0;
      if (count >= limit) return;
    }
  }

  search();
  return count;
}

/// Whether [digit] can go at [index] without repeating in its row, column
/// or 3x3 box (the cell itself is ignored).
bool isPlacementValid(List<int> grid, int index, int digit) {
  for (final peer in peersOf(index)) {
    if (grid[peer] == digit) return false;
  }
  return true;
}

int boxIndex(int index) => (index ~/ 27) * 3 + (index % 9) ~/ 3;

final List<List<int>> _peers = List<List<int>>.generate(81, (index) {
  final r = index ~/ 9, c = index % 9;
  final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
  final peers = <int>{};
  for (var i = 0; i < 9; i++) {
    peers.add(r * 9 + i);
    peers.add(i * 9 + c);
    peers.add((br + i ~/ 3) * 9 + bc + i % 3);
  }
  peers.remove(index);
  return List<int>.unmodifiable(peers);
}, growable: false);

/// The 20 cells sharing a row, column or box with [index].
List<int> peersOf(int index) => _peers[index];

int _bitCount(int mask) {
  var count = 0;
  var m = mask;
  while (m != 0) {
    m &= m - 1;
    count++;
  }
  return count;
}

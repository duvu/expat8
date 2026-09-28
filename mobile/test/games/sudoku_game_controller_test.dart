import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_difficulty.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_game_controller.dart';
import 'package:expat8_language_app/src/games/sudoku/sudoku_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Solved grid with [blanks] cleared.
SudokuPuzzle nearlySolved(List<int> blanks) {
  final full = SudokuGenerator(random: Random(1))
      .generate(SudokuDifficulty.beginner)
      .solution;
  final puzzle = List<int>.of(full);
  for (final i in blanks) {
    puzzle[i] = 0;
  }
  return SudokuPuzzle(
    puzzle: puzzle,
    solution: full,
    difficulty: SudokuDifficulty.medium,
  );
}

class FakeClock {
  DateTime now = DateTime.utc(2026, 9, 28, 8);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

void main() {
  late InMemoryGameStorage storage;
  late FakeClock clock;

  setUp(() {
    storage = InMemoryGameStorage();
    clock = FakeClock();
  });

  SudokuGameController newGame(List<int> blanks) {
    final game = SudokuGameController.fromPuzzle(
      nearlySolved(blanks),
      storage: storage,
      clock: clock.call,
    )..start();
    return game;
  }

  int wrongDigitFor(SudokuGameController game, int index, int correct) =>
      correct == 9 ? 1 : correct + 1;

  test('wrong entries count as mistakes and can be erased', () {
    final puzzle = nearlySolved([0, 1]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start()
      ..select(0);
    final wrong = wrongDigitFor(game, 0, puzzle.solution[0]);

    game.enter(wrong);
    expect(game.valueAt(0), wrong);
    expect(game.isWrong(0), isTrue);
    expect(game.mistakes, 1);

    game.erase();
    expect(game.valueAt(0), 0);
    expect(game.mistakes, 1);
  });

  test('given cells and correct entries cannot be changed', () {
    final puzzle = nearlySolved([0, 1]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start();

    game.select(2); // given
    game.enter(puzzle.solution[2] == 9 ? 1 : 9);
    expect(game.valueAt(2), puzzle.solution[2]);

    game.select(0);
    game.enter(puzzle.solution[0]);
    game.enter(wrongDigitFor(game, 0, puzzle.solution[0]));
    game.erase();
    expect(game.valueAt(0), puzzle.solution[0]);
  });

  test('notes toggle and are cleared from peers by a correct entry', () {
    final puzzle = nearlySolved([0, 1, 40]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start();
    final digit = puzzle.solution[0];

    game.toggleNotesMode();
    game.select(1);
    game.enter(digit);
    game.enter(puzzle.solution[1]);
    expect(game.notesAt(1), {digit, puzzle.solution[1]});
    game.enter(puzzle.solution[1]);
    expect(game.notesAt(1), {digit});

    game.toggleNotesMode();
    game.select(0);
    game.enter(digit);
    expect(game.notesAt(1), isEmpty, reason: 'peer note removed');
  });

  test('undo restores the previous value and notes', () {
    final puzzle = nearlySolved([0, 1]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start()
      ..select(0);

    game.enter(wrongDigitFor(game, 0, puzzle.solution[0]));
    expect(game.canUndo, isTrue);
    game.undo();
    expect(game.valueAt(0), 0);
    expect(game.canUndo, isFalse);
  });

  test('hint fills a cell and counts toward the penalty', () {
    final game = newGame([0, 1]);
    game.hint();
    expect(game.hintsUsed, 1);
    expect(game.selected, 0);
    expect(game.isWrong(0), isFalse);
    expect(game.valueAt(0), isNot(0));
  });

  test('solving stops the timer and clears the saved game', () async {
    final puzzle = nearlySolved([0, 1]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start();
    await game.save();
    expect(storage.values, contains(SudokuGameController.savedGameKey));

    clock.advance(const Duration(seconds: 42));
    game.select(0);
    game.enter(puzzle.solution[0]);
    game.select(1);
    game.enter(puzzle.solution[1]);
    await Future<void>.delayed(Duration.zero);

    expect(game.isSolved, isTrue);
    expect(game.isRunning, isFalse);
    clock.advance(const Duration(minutes: 5));
    expect(game.elapsed, const Duration(seconds: 42));
    expect(storage.values, isNot(contains(SudokuGameController.savedGameKey)));
  });

  test('timer only runs while started and ignores input when paused', () {
    final puzzle = nearlySolved([0, 1]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call);

    clock.advance(const Duration(minutes: 1));
    expect(game.elapsed, Duration.zero);

    game.start();
    clock.advance(const Duration(seconds: 10));
    game.pause();
    clock.advance(const Duration(minutes: 3));
    expect(game.elapsed, const Duration(seconds: 10));

    game.select(0);
    game.enter(puzzle.solution[0]);
    expect(game.valueAt(0), 0, reason: 'paused games ignore input');
  });

  test('unfinished game survives a save and restore', () async {
    final puzzle = nearlySolved([0, 1, 2]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start()
      ..select(0);
    game.enter(puzzle.solution[0]);
    game.toggleNotesMode();
    game.select(1);
    game.enter(3);
    clock.advance(const Duration(seconds: 30));
    game.pause();
    await game.save();

    final restored =
        await SudokuGameController.restore(storage: storage, clock: clock.call);
    expect(restored, isNotNull);
    expect(restored!.difficulty, SudokuDifficulty.medium);
    expect(restored.valueAt(0), puzzle.solution[0]);
    expect(restored.notesAt(1), {3});
    expect(restored.elapsed, const Duration(seconds: 30));
    expect(restored.isGiven(0), isFalse);
    expect(
      await SudokuGameController.savedDifficulty(storage),
      SudokuDifficulty.medium,
    );
  });

  test('corrupt saved data is discarded', () async {
    await storage.write(SudokuGameController.savedGameKey, '{not json');
    expect(await SudokuGameController.restore(storage: storage), isNull);
    expect(storage.values, isNot(contains(SudokuGameController.savedGameKey)));
  });

  test('emits feedback for correct, wrong, completed units and solve', () async {
    final puzzle = nearlySolved([0, 1]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start();
    final events = <SudokuFeedback>[];
    final sub = game.feedback.listen(events.add);

    game.select(0);
    game.enter(wrongDigitFor(game, 0, puzzle.solution[0]));
    game.erase();
    game.enter(puzzle.solution[0]);
    game.select(1);
    game.enter(puzzle.solution[1]);
    await Future<void>.delayed(Duration.zero);

    final kinds = events.map((e) => e.kind).toList();
    expect(kinds.first, SudokuFeedbackKind.wrong);
    expect(kinds, contains(SudokuFeedbackKind.correct));
    // Filling cell 1 completes row 0, column 1 and box 0.
    final completed =
        events.where((e) => e.kind == SudokuFeedbackKind.unitCompleted).toList();
    expect(completed.map((e) => e.cells.length), everyElement(9));
    expect(completed.length, greaterThanOrEqualTo(3));
    expect(kinds.last, SudokuFeedbackKind.solved);
    await sub.cancel();
  });

  test('remaining counts correctly placed digits', () {
    final puzzle = nearlySolved([0]);
    final game = SudokuGameController.fromPuzzle(puzzle,
        storage: storage, clock: clock.call)
      ..start();
    final digit = puzzle.solution[0];
    expect(game.remaining(digit), 1);
    game.select(0);
    game.enter(digit);
    expect(game.remaining(digit), 0);
  });
}

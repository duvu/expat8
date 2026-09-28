import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../game_storage.dart';
import 'sudoku_difficulty.dart';
import 'sudoku_generator.dart';

typedef Clock = DateTime Function();

class _Move {
  const _Move(this.index, this.value, this.notes);

  final int index;
  final int value;
  final Set<int> notes;
}

/// State and rules for one Sudoku game. Persists itself after every change
/// so an unfinished game survives app restarts.
class SudokuGameController extends ChangeNotifier {
  SudokuGameController._({
    required this.difficulty,
    required List<int> puzzle,
    required List<int> solution,
    required List<int> values,
    required List<Set<int>> notes,
    required this.storage,
    required Clock clock,
    int mistakes = 0,
    int hintsUsed = 0,
    int elapsedMs = 0,
  })  : _puzzle = List.unmodifiable(puzzle),
        _solution = List.unmodifiable(solution),
        _values = values,
        _notes = notes,
        _clock = clock,
        _mistakes = mistakes,
        _hintsUsed = hintsUsed,
        _accumulatedMs = elapsedMs;

  factory SudokuGameController.fromPuzzle(
    SudokuPuzzle puzzle, {
    required GameStorage storage,
    Clock? clock,
  }) =>
      SudokuGameController._(
        difficulty: puzzle.difficulty,
        puzzle: puzzle.puzzle,
        solution: puzzle.solution,
        values: List<int>.of(puzzle.puzzle),
        notes: List.generate(81, (_) => <int>{}),
        storage: storage,
        clock: clock ?? DateTime.now,
      );

  static const savedGameKey = 'games.sudoku.saved_game.v1';

  /// Restores the unfinished game, or returns null if there is none.
  static Future<SudokuGameController?> restore({
    required GameStorage storage,
    Clock? clock,
  }) async {
    final raw = await storage.read(savedGameKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      List<int> ints(String key) =>
          (json[key] as List<dynamic>).map((e) => e as int).toList();
      final puzzle = ints('puzzle');
      final solution = ints('solution');
      final values = ints('values');
      final notes = (json['notes'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((n) => n as int).toSet())
          .toList();
      if (puzzle.length != 81 ||
          solution.length != 81 ||
          values.length != 81 ||
          notes.length != 81) {
        return null;
      }
      return SudokuGameController._(
        difficulty: SudokuDifficulty.fromName(json['difficulty'] as String?),
        puzzle: puzzle,
        solution: solution,
        values: values,
        notes: notes,
        storage: storage,
        clock: clock ?? DateTime.now,
        mistakes: json['mistakes'] as int? ?? 0,
        hintsUsed: json['hints_used'] as int? ?? 0,
        elapsedMs: json['elapsed_ms'] as int? ?? 0,
      );
    } on Object {
      await storage.remove(savedGameKey);
      return null;
    }
  }

  static Future<SudokuDifficulty?> savedDifficulty(GameStorage storage) async {
    final raw = await storage.read(savedGameKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SudokuDifficulty.fromName(json['difficulty'] as String?);
    } on Object {
      return null;
    }
  }

  static Future<void> clearSaved(GameStorage storage) =>
      storage.remove(savedGameKey);

  final SudokuDifficulty difficulty;
  final GameStorage storage;
  final List<int> _puzzle;
  final List<int> _solution;
  final List<int> _values;
  final List<Set<int>> _notes;
  final Clock _clock;
  final List<_Move> _undo = [];

  int? _selected;
  bool _notesMode = false;
  int _mistakes;
  int _hintsUsed;
  int _accumulatedMs;
  DateTime? _runningSince;

  int? get selected => _selected;
  bool get notesMode => _notesMode;
  int get mistakes => _mistakes;
  int get hintsUsed => _hintsUsed;
  bool get canUndo => _undo.isNotEmpty && !isSolved;
  bool get isRunning => _runningSince != null;

  bool get isSolved {
    for (var i = 0; i < 81; i++) {
      if (_values[i] != _solution[i]) return false;
    }
    return true;
  }

  Duration get elapsed {
    final running = _runningSince;
    final extra =
        running == null ? 0 : _clock().difference(running).inMilliseconds;
    return Duration(milliseconds: _accumulatedMs + extra);
  }

  int valueAt(int index) => _values[index];
  bool isGiven(int index) => _puzzle[index] != 0;
  Set<int> notesAt(int index) => Set.unmodifiable(_notes[index]);

  /// A filled cell that does not match the solution.
  bool isWrong(int index) =>
      _values[index] != 0 && _values[index] != _solution[index];

  /// How many more times [digit] must be placed correctly.
  int remaining(int digit) {
    var placed = 0;
    for (var i = 0; i < 81; i++) {
      if (_values[i] == digit && _solution[i] == digit) placed++;
    }
    return 9 - placed;
  }

  void start() {
    if (isSolved || _runningSince != null) return;
    _runningSince = _clock();
    notifyListeners();
  }

  void pause() {
    final running = _runningSince;
    if (running == null) return;
    _accumulatedMs += _clock().difference(running).inMilliseconds;
    _runningSince = null;
    notifyListeners();
    unawaited(_save());
  }

  void select(int index) {
    _selected = index;
    notifyListeners();
  }

  void toggleNotesMode() {
    _notesMode = !_notesMode;
    notifyListeners();
  }

  void enter(int digit) {
    final index = _selected;
    if (index == null || isGiven(index) || isSolved || !isRunning) return;
    if (_values[index] == _solution[index] && _values[index] != 0) return;

    if (_notesMode) {
      if (_values[index] != 0) return;
      _pushUndo(index);
      final notes = _notes[index];
      notes.contains(digit) ? notes.remove(digit) : notes.add(digit);
      _changed();
      return;
    }

    if (_values[index] == digit) return;
    _pushUndo(index);
    _values[index] = digit;
    _notes[index].clear();
    if (digit != _solution[index]) {
      _mistakes++;
    } else {
      for (final peer in peersOf(index)) {
        _notes[peer].remove(digit);
      }
    }
    _changed();
  }

  void erase() {
    final index = _selected;
    if (index == null || isGiven(index) || isSolved || !isRunning) return;
    if (_values[index] == _solution[index] && _values[index] != 0) return;
    if (_values[index] == 0 && _notes[index].isEmpty) return;
    _pushUndo(index);
    _values[index] = 0;
    _notes[index].clear();
    _changed();
  }

  /// Reveals the selected cell, or the first unsolved cell if the selected
  /// one is already correct. Each hint adds a time penalty to the record.
  void hint() {
    if (isSolved || !isRunning) return;
    var index = _selected;
    if (index == null || _values[index] == _solution[index]) {
      index = List.generate(81, (i) => i)
          .firstWhere((i) => _values[i] != _solution[i], orElse: () => -1);
      if (index == -1) return;
    }
    _pushUndo(index);
    _values[index] = _solution[index];
    _notes[index].clear();
    for (final peer in peersOf(index)) {
      _notes[peer].remove(_solution[index]);
    }
    _hintsUsed++;
    _selected = index;
    _changed();
  }

  void undo() {
    if (!canUndo || !isRunning) return;
    final move = _undo.removeLast();
    _values[move.index] = move.value;
    _notes[move.index]
      ..clear()
      ..addAll(move.notes);
    _selected = move.index;
    _changed();
  }

  void _pushUndo(int index) {
    _undo.add(_Move(index, _values[index], Set.of(_notes[index])));
  }

  void _changed() {
    if (isSolved) {
      final running = _runningSince;
      if (running != null) {
        _accumulatedMs += _clock().difference(running).inMilliseconds;
        _runningSince = null;
      }
      _undo.clear();
      notifyListeners();
      unawaited(clearSaved(storage));
      return;
    }
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    if (isSolved) return;
    await storage.write(
      savedGameKey,
      jsonEncode({
        'difficulty': difficulty.name,
        'puzzle': _puzzle,
        'solution': _solution,
        'values': _values,
        'notes': [for (final n in _notes) n.toList()..sort()],
        'mistakes': _mistakes,
        'hints_used': _hintsUsed,
        'elapsed_ms': elapsed.inMilliseconds,
      }),
    );
  }

  /// Persists the current state immediately (e.g. when leaving the screen).
  Future<void> save() => _save();
}

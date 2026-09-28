import 'dart:convert';

import '../game_storage.dart';
import 'sudoku_difficulty.dart';

/// One finished game on the champion board.
class SudokuRecord {
  const SudokuRecord({
    required this.playerName,
    required this.difficulty,
    required this.elapsedMs,
    required this.hintsUsed,
    required this.mistakes,
    required this.completedAt,
  });

  factory SudokuRecord.fromJson(Map<String, dynamic> json) => SudokuRecord(
        playerName: json['player_name'] as String? ?? 'Player',
        difficulty: SudokuDifficulty.fromName(json['difficulty'] as String?),
        elapsedMs: json['elapsed_ms'] as int? ?? 0,
        hintsUsed: json['hints_used'] as int? ?? 0,
        mistakes: json['mistakes'] as int? ?? 0,
        completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// Each hint adds this much to the ranked time.
  static const hintPenalty = Duration(seconds: 30);

  final String playerName;
  final SudokuDifficulty difficulty;
  final int elapsedMs;
  final int hintsUsed;
  final int mistakes;
  final DateTime completedAt;

  /// Time used for ranking: solve time plus hint penalties.
  int get scoreMs => elapsedMs + hintsUsed * hintPenalty.inMilliseconds;

  Map<String, dynamic> toJson() => {
        'player_name': playerName,
        'difficulty': difficulty.name,
        'elapsed_ms': elapsedMs,
        'hints_used': hintsUsed,
        'mistakes': mistakes,
        'completed_at': completedAt.toUtc().toIso8601String(),
      };

  SudokuRecord copyWith({String? playerName}) => SudokuRecord(
        playerName: playerName ?? this.playerName,
        difficulty: difficulty,
        elapsedMs: elapsedMs,
        hintsUsed: hintsUsed,
        mistakes: mistakes,
        completedAt: completedAt,
      );

  static int compare(SudokuRecord a, SudokuRecord b) {
    final byScore = a.scoreMs.compareTo(b.scoreMs);
    if (byScore != 0) return byScore;
    final byMistakes = a.mistakes.compareTo(b.mistakes);
    if (byMistakes != 0) return byMistakes;
    return a.completedAt.compareTo(b.completedAt);
  }
}

/// Per-difficulty play statistics.
class SudokuStats {
  const SudokuStats({this.started = 0, this.completed = 0});

  final int started;
  final int completed;
}

/// Local champion board: the best [maxEntries] solves per difficulty.
class SudokuChampionStore {
  SudokuChampionStore(this.storage);

  static const maxEntries = 10;
  static const _boardKey = 'games.sudoku.champions.v1';
  static const _statsKey = 'games.sudoku.stats.v1';
  static const _playerNameKey = 'games.player_name';

  final GameStorage storage;

  Future<Map<SudokuDifficulty, List<SudokuRecord>>> loadBoard() async {
    final raw = await storage.read(_boardKey);
    final board = {
      for (final d in SudokuDifficulty.values) d: <SudokuRecord>[],
    };
    if (raw == null) return board;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final d in SudokuDifficulty.values) {
        final entries = decoded[d.name] as List<dynamic>? ?? const [];
        board[d] = [
          for (final e in entries)
            SudokuRecord.fromJson(e as Map<String, dynamic>),
        ]..sort(SudokuRecord.compare);
      }
    } on FormatException {
      // Corrupt data: start a fresh board rather than crash the game.
    } on TypeError {
      // Same as above for unexpected shapes.
    }
    return board;
  }

  Future<List<SudokuRecord>> recordsFor(SudokuDifficulty difficulty) async =>
      (await loadBoard())[difficulty]!;

  /// The 1-based rank [record] would get, or null if it would not make the
  /// board.
  Future<int?> rankFor(SudokuRecord record) async {
    final records = await recordsFor(record.difficulty);
    final position =
        records.where((r) => SudokuRecord.compare(r, record) <= 0).length;
    return position < maxEntries ? position + 1 : null;
  }

  /// Adds [record] and returns its 1-based rank, or null if it did not
  /// make the top [maxEntries].
  Future<int?> addRecord(SudokuRecord record) async {
    final board = await loadBoard();
    final records = board[record.difficulty]!
      ..add(record)
      ..sort(SudokuRecord.compare);
    final rank = records.indexOf(record) + 1;
    if (records.length > maxEntries) {
      records.removeRange(maxEntries, records.length);
    }
    await storage.write(
      _boardKey,
      jsonEncode({
        for (final entry in board.entries)
          entry.key.name: [for (final r in entry.value) r.toJson()],
      }),
    );
    return rank <= maxEntries ? rank : null;
  }

  Future<void> clearBoard() => storage.remove(_boardKey);

  Future<Map<SudokuDifficulty, SudokuStats>> loadStats() async {
    final raw = await storage.read(_statsKey);
    Map<String, dynamic> decoded = const {};
    if (raw != null) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } on FormatException {
        decoded = const {};
      }
    }
    return {
      for (final d in SudokuDifficulty.values)
        d: SudokuStats(
          started: (decoded[d.name] as Map?)?['started'] as int? ?? 0,
          completed: (decoded[d.name] as Map?)?['completed'] as int? ?? 0,
        ),
    };
  }

  Future<void> recordStarted(SudokuDifficulty difficulty) =>
      _updateStats(difficulty, started: 1);

  Future<void> recordCompleted(SudokuDifficulty difficulty) =>
      _updateStats(difficulty, completed: 1);

  Future<void> _updateStats(
    SudokuDifficulty difficulty, {
    int started = 0,
    int completed = 0,
  }) async {
    final stats = await loadStats();
    final current = stats[difficulty]!;
    stats[difficulty] = SudokuStats(
      started: current.started + started,
      completed: current.completed + completed,
    );
    await storage.write(
      _statsKey,
      jsonEncode({
        for (final entry in stats.entries)
          entry.key.name: {
            'started': entry.value.started,
            'completed': entry.value.completed,
          },
      }),
    );
  }

  Future<String> loadPlayerName() async =>
      (await storage.read(_playerNameKey)) ?? 'Player';

  Future<void> savePlayerName(String name) =>
      storage.write(_playerNameKey, name.trim().isEmpty ? 'Player' : name);
}

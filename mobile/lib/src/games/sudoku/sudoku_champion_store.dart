import 'dart:convert';

import '../common/game_score_store.dart';
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
/// Backed by the shared [GameScoreStore] (mode = difficulty name).
class SudokuChampionStore {
  SudokuChampionStore(this.storage)
      : _scores = GameScoreStore(
          storage,
          gameId: 'sudoku',
          compare: _compareScores,
          maxEntries: maxEntries,
        );

  static const maxEntries = 10;
  static const legacyBoardKey = 'games.sudoku.champions.v1';
  static const _statsKey = 'games.sudoku.stats.v1';

  final GameStorage storage;
  final GameScoreStore _scores;

  static int _compareScores(GameScore a, GameScore b) => SudokuRecord.compare(
        _fromScore(a, SudokuDifficulty.easy),
        _fromScore(b, SudokuDifficulty.easy),
      );

  static GameScore _toScore(SudokuRecord r) => GameScore(
        playerName: r.playerName,
        score: r.scoreMs,
        completedAt: r.completedAt,
        data: {
          'elapsed_ms': r.elapsedMs,
          'hints_used': r.hintsUsed,
          'mistakes': r.mistakes,
        },
      );

  static SudokuRecord _fromScore(GameScore s, SudokuDifficulty difficulty) =>
      SudokuRecord(
        playerName: s.playerName,
        difficulty: difficulty,
        elapsedMs: (s.data['elapsed_ms'] as num?)?.toInt() ?? s.score,
        hintsUsed: (s.data['hints_used'] as num?)?.toInt() ?? 0,
        mistakes: (s.data['mistakes'] as num?)?.toInt() ?? 0,
        completedAt: s.completedAt,
      );

  /// Moves records saved by the first Sudoku release into the shared store.
  Future<void> _migrateLegacyBoard() async {
    final raw = await storage.read(legacyBoardKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final board = await _scores.loadAll();
      for (final d in SudokuDifficulty.values) {
        final legacy = [
          for (final e in decoded[d.name] as List<dynamic>? ?? const [])
            SudokuRecord.fromJson(e as Map<String, dynamic>),
        ];
        if (legacy.isEmpty) continue;
        final merged = [...?board[d.name], ...legacy.map(_toScore)]
          ..sort(_compareScores);
        board[d.name] = merged.take(maxEntries).toList();
      }
      await _scores.replaceAll(board);
    } on Object {
      // Unreadable legacy data is dropped.
    }
    await storage.remove(legacyBoardKey);
  }

  Future<Map<SudokuDifficulty, List<SudokuRecord>>> loadBoard() async {
    await _migrateLegacyBoard();
    final all = await _scores.loadAll();
    return {
      for (final d in SudokuDifficulty.values)
        d: [
          for (final s in all[d.name] ?? const <GameScore>[]) _fromScore(s, d)
        ],
    };
  }

  Future<List<SudokuRecord>> recordsFor(SudokuDifficulty difficulty) async =>
      (await loadBoard())[difficulty]!;

  /// The 1-based rank [record] would get, or null if it would not make the
  /// board.
  Future<int?> rankFor(SudokuRecord record) async {
    await _migrateLegacyBoard();
    return _scores.rankFor(record.difficulty.name, _toScore(record));
  }

  /// Adds [record] and returns its 1-based rank, or null if it did not make
  /// the top [maxEntries].
  Future<int?> addRecord(SudokuRecord record) async {
    await _migrateLegacyBoard();
    return _scores.add(record.difficulty.name, _toScore(record));
  }

  Future<void> clearBoard() async {
    await storage.remove(legacyBoardKey);
    await _scores.clear();
  }

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

  Future<String> loadPlayerName() => _scores.loadPlayerName();

  Future<void> savePlayerName(String name) => _scores.savePlayerName(name);
}

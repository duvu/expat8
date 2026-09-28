import 'dart:convert';

import '../game_storage.dart';

/// One ranked result of any game. [score] is the primary ranking value;
/// whether higher or lower is better is decided by the store's comparator.
class GameScore {
  const GameScore({
    required this.playerName,
    required this.score,
    required this.completedAt,
    this.accuracy,
    this.bestCombo,
    this.data = const {},
  });

  factory GameScore.fromJson(Map<String, dynamic> json) => GameScore(
        playerName: json['player_name'] as String? ?? 'Player',
        score: (json['score'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        bestCombo: (json['best_combo'] as num?)?.toInt(),
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final String playerName;
  final int score;
  final DateTime completedAt;

  /// 0..1, when the game has a notion of accuracy.
  final double? accuracy;
  final int? bestCombo;

  /// Game-specific fields (e.g. hints, mistakes).
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'player_name': playerName,
        'score': score,
        'completed_at': completedAt.toUtc().toIso8601String(),
        if (accuracy != null) 'accuracy': accuracy,
        if (bestCombo != null) 'best_combo': bestCombo,
        if (data.isNotEmpty) 'data': data,
      };

  GameScore copyWith({String? playerName}) => GameScore(
        playerName: playerName ?? this.playerName,
        score: score,
        completedAt: completedAt,
        accuracy: accuracy,
        bestCombo: bestCombo,
        data: data,
      );
}

typedef GameScoreComparator = int Function(GameScore a, GameScore b);

/// Higher score first, then earlier completion.
int higherScoreFirst(GameScore a, GameScore b) {
  final byScore = b.score.compareTo(a.score);
  return byScore != 0 ? byScore : a.completedAt.compareTo(b.completedAt);
}

/// Local top-N records per game and mode, stored on the device.
class GameScoreStore {
  GameScoreStore(
    this.storage, {
    required this.gameId,
    this.compare = higherScoreFirst,
    this.maxEntries = 10,
  });

  final GameStorage storage;
  final String gameId;
  final GameScoreComparator compare;
  final int maxEntries;

  static const playerNameKey = 'games.player_name';

  String get _boardKey => 'games.$gameId.scores.v2';

  Future<Map<String, List<GameScore>>> loadAll() async {
    final raw = await storage.read(_boardKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: [
            for (final item in entry.value as List<dynamic>)
              GameScore.fromJson(item as Map<String, dynamic>),
          ]..sort(compare),
      };
    } on Object {
      // Corrupt data: start fresh rather than break the game.
      return {};
    }
  }

  Future<List<GameScore>> load(String modeId) async =>
      (await loadAll())[modeId] ?? [];

  /// 1-based rank [score] would get in [modeId], or null if outside the top.
  Future<int?> rankFor(String modeId, GameScore score) async {
    final records = await load(modeId);
    final position = records.where((r) => compare(r, score) <= 0).length;
    return position < maxEntries ? position + 1 : null;
  }

  /// Stores [score] and returns its 1-based rank, or null if it did not make
  /// the top [maxEntries].
  Future<int?> add(String modeId, GameScore score) async {
    final all = await loadAll();
    final records = (all[modeId] ?? [])
      ..add(score)
      ..sort(compare);
    final rank = records.indexOf(score) + 1;
    if (records.length > maxEntries) {
      records.removeRange(maxEntries, records.length);
    }
    all[modeId] = records;
    await _write(all);
    return rank <= maxEntries ? rank : null;
  }

  /// Replaces all records (used for migrations).
  Future<void> replaceAll(Map<String, List<GameScore>> board) => _write(board);

  Future<void> clear() => storage.remove(_boardKey);

  Future<void> _write(Map<String, List<GameScore>> board) => storage.write(
        _boardKey,
        jsonEncode({
          for (final entry in board.entries)
            entry.key: [for (final s in entry.value) s.toJson()],
        }),
      );

  Future<String> loadPlayerName() async =>
      (await storage.read(playerNameKey)) ?? 'Player';

  Future<void> savePlayerName(String name) => storage.write(
      playerNameKey, name.trim().isEmpty ? 'Player' : name.trim());
}

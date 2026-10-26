/// Game round sync and leaderboard DTOs.
class GameRoundSyncResult {
  const GameRoundSyncResult({
    required this.acceptedRoundIds,
    required this.duplicateRoundIds,
    required this.rejectedRounds,
  });

  final List<String> acceptedRoundIds;
  final List<String> duplicateRoundIds;
  final List<Map<String, dynamic>> rejectedRounds;
}

class GameLeaderboardEntry {
  const GameLeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.accuracy,
    required this.bestCombo,
    required this.isMe,
  });

  factory GameLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      GameLeaderboardEntry(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        displayName: json['display_name'] as String? ?? 'Player',
        score: (json['score'] as num?)?.toInt() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
        bestCombo: (json['best_combo'] as num?)?.toInt() ?? 0,
        isMe: json['is_me'] as bool? ?? false,
      );

  final int rank;
  final String displayName;
  final int score;
  final double accuracy;
  final int bestCombo;
  final bool isMe;

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'display_name': displayName,
        'score': score,
        'accuracy': accuracy,
        'best_combo': bestCombo,
        'is_me': isMe,
      };
}

class GameLeaderboard {
  const GameLeaderboard({
    required this.weekStart,
    required this.entries,
    this.me,
  });

  factory GameLeaderboard.fromJson(Map<String, dynamic> json) =>
      GameLeaderboard(
        weekStart: json['week_start'] as String? ?? '',
        entries: [
          for (final e in json['entries'] as List? ?? const [])
            GameLeaderboardEntry.fromJson(e as Map<String, dynamic>),
        ],
        me: json['me'] is Map<String, dynamic>
            ? GameLeaderboardEntry.fromJson(json['me'] as Map<String, dynamic>)
            : null,
      );

  final String weekStart;
  final List<GameLeaderboardEntry> entries;
  final GameLeaderboardEntry? me;

  Map<String, dynamic> toJson() => {
        'week_start': weekStart,
        'entries': [for (final e in entries) e.toJson()],
        if (me != null) 'me': me!.toJson(),
      };
}

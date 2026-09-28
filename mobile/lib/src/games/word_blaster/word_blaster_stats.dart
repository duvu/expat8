import 'dart:convert';

import '../game_storage.dart';
import 'word_blaster_mode.dart';

/// One finished round, as used by stats (and synced to the backend).
class WordBlasterRoundSummary {
  const WordBlasterRoundSummary({
    required this.clientRoundId,
    required this.mode,
    required this.score,
    required this.correct,
    required this.answered,
    required this.bestCombo,
    required this.wave,
    required this.durationMs,
    required this.language,
    required this.completedAt,
    required this.missedTerms,
  });

  final String clientRoundId;
  final WordBlasterMode mode;
  final int score;
  final int correct;
  final int answered;
  final int bestCombo;
  final int wave;
  final int durationMs;
  final String language;
  final DateTime completedAt;
  final List<String> missedTerms;

  double get accuracy => answered == 0 ? 0 : correct / answered;

  Map<String, dynamic> toSyncJson() => {
        'client_round_id': clientRoundId,
        'game': 'word_blaster',
        'mode': mode.name,
        'language': language,
        'score': score,
        'correct_count': correct,
        'answered_count': answered,
        'best_combo': bestCombo,
        'wave': wave,
        'duration_ms': durationMs,
        'completed_at': completedAt.toUtc().toIso8601String(),
      };
}

class DailyAccuracy {
  const DailyAccuracy(this.day,
      {required this.correct, required this.answered});

  final DateTime day;
  final int correct;
  final int answered;

  double get accuracy => answered == 0 ? 0 : correct / answered;
}

class WordBlasterStats {
  const WordBlasterStats({
    required this.roundsByMode,
    required this.totalCorrect,
    required this.totalAnswered,
    required this.bestCombo,
    required this.daily,
    required this.mostMissed,
  });

  final Map<WordBlasterMode, int> roundsByMode;
  final int totalCorrect;
  final int totalAnswered;
  final int bestCombo;

  /// Last 7 days, oldest first; days without play have zero counts.
  final List<DailyAccuracy> daily;

  /// Up to 10 terms, most missed first.
  final List<MapEntry<String, int>> mostMissed;

  int get roundsPlayed => roundsByMode.values.fold(0, (a, b) => a + b);
}

/// Local aggregate stats for Word Blaster.
class WordBlasterStatsStore {
  WordBlasterStatsStore(this.storage);

  static const _key = 'games.word_blaster.stats.v1';
  static const _maxMissedTerms = 200;

  final GameStorage storage;

  Future<Map<String, dynamic>> _read() async {
    final raw = await storage.read(_key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return {};
    }
  }

  Future<void> recordRound(WordBlasterRoundSummary round) async {
    final data = await _read();
    final rounds = Map<String, dynamic>.from(data['rounds'] as Map? ?? {});
    rounds[round.mode.name] =
        ((rounds[round.mode.name] as num?)?.toInt() ?? 0) + 1;

    final daily = Map<String, dynamic>.from(data['daily'] as Map? ?? {});
    final dayKey = _dayKey(round.completedAt.toLocal());
    final day = Map<String, dynamic>.from(daily[dayKey] as Map? ?? {});
    day['c'] = ((day['c'] as num?)?.toInt() ?? 0) + round.correct;
    day['a'] = ((day['a'] as num?)?.toInt() ?? 0) + round.answered;
    daily[dayKey] = day;
    // Keep ~60 days.
    final keys = daily.keys.toList()..sort();
    for (final k in keys.take(keys.length > 60 ? keys.length - 60 : 0)) {
      daily.remove(k);
    }

    final missed = Map<String, dynamic>.from(data['missed'] as Map? ?? {});
    for (final term in round.missedTerms) {
      missed[term] = ((missed[term] as num?)?.toInt() ?? 0) + 1;
    }
    if (missed.length > _maxMissedTerms) {
      final sorted = missed.entries.toList()
        ..sort((a, b) => (a.value as num).compareTo(b.value as num));
      for (final e in sorted.take(missed.length - _maxMissedTerms)) {
        missed.remove(e.key);
      }
    }

    await storage.write(
      _key,
      jsonEncode({
        'rounds': rounds,
        'correct': ((data['correct'] as num?)?.toInt() ?? 0) + round.correct,
        'answered': ((data['answered'] as num?)?.toInt() ?? 0) + round.answered,
        'best_combo': [
          (data['best_combo'] as num?)?.toInt() ?? 0,
          round.bestCombo
        ].reduce((a, b) => a > b ? a : b),
        'daily': daily,
        'missed': missed,
      }),
    );
  }

  Future<WordBlasterStats> load({DateTime? now}) async {
    final data = await _read();
    final rounds = data['rounds'] as Map? ?? {};
    final daily = data['daily'] as Map? ?? {};
    final today = (now ?? DateTime.now()).toLocal();
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: i)),
    ];
    final missed = (data['missed'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()))
        .entries
        .toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return WordBlasterStats(
      roundsByMode: {
        for (final m in WordBlasterMode.values)
          m: (rounds[m.name] as num?)?.toInt() ?? 0,
      },
      totalCorrect: (data['correct'] as num?)?.toInt() ?? 0,
      totalAnswered: (data['answered'] as num?)?.toInt() ?? 0,
      bestCombo: (data['best_combo'] as num?)?.toInt() ?? 0,
      daily: [
        for (final d in days)
          DailyAccuracy(
            d,
            correct: ((daily[_dayKey(d)] as Map?)?['c'] as num?)?.toInt() ?? 0,
            answered: ((daily[_dayKey(d)] as Map?)?['a'] as num?)?.toInt() ?? 0,
          ),
      ],
      mostMissed: missed.take(10).toList(),
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

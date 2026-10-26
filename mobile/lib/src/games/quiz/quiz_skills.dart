import 'dart:convert';
import 'dart:math';

import '../game_storage.dart';
import 'quiz_core.dart';

/// One item the player missed, kept until they get it right twice in a row.
class WeakItem<T extends QuizItem> {
  WeakItem({
    required this.item,
    required this.levelName,
    this.misses = 0,
    this.correctStreak = 0,
  });

  final T item;
  final String levelName;
  int misses;
  int correctStreak;

  Map<String, dynamic> toJson() => {
        'problem': item.toJson(),
        'level': levelName,
        'misses': misses,
        'streak': correctStreak,
      };
}

/// Lifetime totals per level, for the home screen.
class QuizLevelStats {
  QuizLevelStats({this.answered = 0, this.correct = 0, this.totalMs = 0});

  factory QuizLevelStats.fromJson(Map<String, dynamic> json) => QuizLevelStats(
        answered: (json['answered'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        totalMs: (json['ms'] as num?)?.toInt() ?? 0,
      );

  int answered;
  int correct;
  int totalMs;

  double get accuracy => answered == 0 ? 0 : correct / answered;
  double get averageSeconds =>
      correct == 0 ? 0 : totalMs / correct / Duration.millisecondsPerSecond;

  Map<String, dynamic> toJson() =>
      {'answered': answered, 'correct': correct, 'ms': totalMs};
}

/// Remembers missed items per subject (so they come back sooner, like spaced
/// repetition) and how fast/accurate the player is at each level.
class SkillTracker<T extends QuizItem> implements WeakItemSource<T> {
  SkillTracker(this.storage, {required this.storageKey, required this.decode});

  static const maxWeakItems = 60;

  final GameStorage storage;
  final String storageKey;
  final T Function(Map<String, dynamic> json) decode;
  final Map<String, WeakItem<T>> _weak = {};
  final Map<String, QuizLevelStats> _stats = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await storage.read(storageKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in (json['weak'] as List<dynamic>? ?? const [])) {
        final map = entry as Map<String, dynamic>;
        final weak = WeakItem<T>(
          item: decode(map['problem'] as Map<String, dynamic>),
          levelName: map['level'] as String? ?? '',
          misses: (map['misses'] as num?)?.toInt() ?? 0,
          correctStreak: (map['streak'] as num?)?.toInt() ?? 0,
        );
        _weak[_id(weak.levelName, weak.item.key)] = weak;
      }
      final stats = json['stats'] as Map<String, dynamic>? ?? const {};
      for (final entry in stats.entries) {
        _stats[entry.key] =
            QuizLevelStats.fromJson(entry.value as Map<String, dynamic>);
      }
    } on Object {
      // Corrupt data: start fresh.
      _weak.clear();
      _stats.clear();
    }
  }

  Future<void> save() => storage.write(
        storageKey,
        jsonEncode({
          'weak': [for (final w in _weak.values) w.toJson()],
          'stats': {for (final e in _stats.entries) e.key: e.value.toJson()},
        }),
      );

  String _id(String levelName, String key) => '$levelName|$key';

  void record(
    QuizLevel level,
    T item, {
    required bool correct,
    required Duration elapsed,
  }) {
    final stats = _stats.putIfAbsent(level.id, QuizLevelStats.new);
    stats.answered++;
    if (correct) {
      stats.correct++;
      stats.totalMs += elapsed.inMilliseconds;
    }
    final id = _id(level.id, item.key);
    final existing = _weak[id];
    if (correct) {
      if (existing == null) return;
      existing.correctStreak++;
      if (existing.correctStreak >= 2) _weak.remove(id);
      return;
    }
    final weak = existing ?? WeakItem<T>(item: item, levelName: level.id);
    weak
      ..misses += 1
      ..correctStreak = 0;
    _weak[id] = weak;
    if (_weak.length > maxWeakItems) {
      final easiest = _weak.entries
          .reduce((a, b) => a.value.misses <= b.value.misses ? a : b);
      _weak.remove(easiest.key);
    }
  }

  QuizLevelStats statsFor(QuizLevel level) =>
      _stats[level.id] ?? QuizLevelStats();

  /// Items to practise at [level], most missed first.
  List<WeakItem<T>> weakItems(QuizLevel level) =>
      _weak.values.where((w) => w.levelName == level.id).toList()
        ..sort((a, b) => b.misses.compareTo(a.misses));

  @override
  T? pickWeak(QuizLevel level, Random random, {String? avoidKey}) {
    final candidates =
        weakItems(level).where((w) => w.item.key != avoidKey).toList();
    if (candidates.isEmpty) return null;
    // Bias toward the most-missed items.
    final index = (pow(random.nextDouble(), 2) * candidates.length).floor();
    return candidates[index].item;
  }
}

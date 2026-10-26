import 'dart:math';

import 'vocabulary_word.dart';

const List<String> cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const List<String> hskLevels = [
  'HSK1',
  'HSK2',
  'HSK3',
  'HSK4',
  'HSK5',
  'HSK6',
];

const Map<String, String> _legacyLevels = {
  'beginner': 'A1',
  'elementary': 'A1',
  'pre-intermediate': 'A2',
  'intermediate': 'B1',
  'upper-intermediate': 'B2',
  'advanced': 'C1',
  'proficient': 'C2',
};

/// Levels the learner can pick for [scale] ("cefr" or "hsk").
List<String> studyLevelsForScale(String scale) =>
    scale.toLowerCase() == 'hsk' ? hskLevels : cefrLevels;

/// Folds backend labels ("b1", "HSK3", legacy "intermediate") into the scale's
/// canonical level, or null when the label is unknown.
String? normalizeStudyLevel(String? raw, String scale) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final levels = studyLevelsForScale(scale);
  final upper = value.toUpperCase();
  if (levels.contains(upper)) return upper;
  if (levels == hskLevels && levels.contains('HSK$upper')) return 'HSK$upper';
  final legacy = _legacyLevels[value.toLowerCase()];
  return levels == cefrLevels ? legacy : null;
}

/// Picks the word closest to [level]: same level first, then the nearest level
/// (the higher one on ties), newest first within a level. Words with an unknown
/// level rank last. Returns null for an empty list.
///
/// With a [random] source the pick is shuffled instead: [lowerShare] of the time
/// (0.2 = 20%) the word comes from a random lower level, otherwise from a random
/// word at [level]. An empty band falls back to the nearest-level rule above.
VocabularyWord? pickWordNearLevel(
  Iterable<VocabularyWord> words, {
  required String level,
  required String scale,
  Random? random,
  double lowerShare = 0,
}) {
  final levels = studyLevelsForScale(scale);
  final target = levels.indexOf(normalizeStudyLevel(level, scale) ?? '');
  if (target < 0) return null;
  if (random != null) {
    final byIndex = <int, List<VocabularyWord>>{};
    for (final word in words) {
      final index =
          levels.indexOf(normalizeStudyLevel(word.difficulty, scale) ?? '');
      if (index >= 0 && index <= target) {
        byIndex.putIfAbsent(index, () => []).add(word);
      }
    }
    final lowerIndexes = byIndex.keys.where((index) => index < target).toList();
    final same = byIndex[target];
    if (lowerIndexes.isNotEmpty && random.nextDouble() < lowerShare) {
      final bucket =
          byIndex[lowerIndexes[random.nextInt(lowerIndexes.length)]]!;
      return bucket[random.nextInt(bucket.length)];
    }
    if (same != null && same.isNotEmpty) {
      return same[random.nextInt(same.length)];
    }
  }
  VocabularyWord? best;
  var bestDelta = 0;
  for (final word in words) {
    final index =
        levels.indexOf(normalizeStudyLevel(word.difficulty, scale) ?? '');
    final delta = index < 0 ? levels.length + 1 : index - target;
    if (best == null || _isBetter(word, delta, best, bestDelta)) {
      best = word;
      bestDelta = delta;
    }
  }
  return best;
}

bool _isBetter(
    VocabularyWord word, int delta, VocabularyWord best, int bestDelta) {
  if (delta.abs() != bestDelta.abs()) return delta.abs() < bestDelta.abs();
  if (delta != bestDelta) return delta > bestDelta;
  return word.createdAt.isAfter(best.createdAt);
}

import 'dart:math';

import '../../models/vocabulary_word.dart';

/// Minimum distinct words needed to start a round.
const minimumWordsForRound = 12;

/// Level index for CEFR (A1..C2) and HSK (HSK1..HSK6) labels; unknown = 0.
int levelIndexOf(String label) {
  final upper = label.trim().toUpperCase();
  const cefr = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final cefrIndex = cefr.indexOf(upper);
  if (cefrIndex >= 0) return cefrIndex;
  final hsk = RegExp(r'^HSK\s*([1-6])$').firstMatch(upper);
  if (hsk != null) return int.parse(hsk.group(1)!) - 1;
  return 0;
}

/// The words one round draws its prompts from, plus the wider vocabulary used
/// for distractors.
class WordPool {
  const WordPool({required this.roundWords, required this.allWords});

  final List<VocabularyWord> roundWords;
  final List<VocabularyWord> allWords;
}

sealed class WordPoolResult {
  const WordPoolResult();
}

class WordPoolReady extends WordPoolResult {
  const WordPoolReady(this.pool);
  final WordPool pool;
}

class WordPoolInsufficient extends WordPoolResult {
  const WordPoolInsufficient(
      {required this.available, this.required = minimumWordsForRound});
  final int available;
  final int required;
}

/// Picks an SRS-weighted pool: ~50% due reviews, ~30% recently seen or
/// difficult words, ~20% new words at most one level above the learner.
/// Missing categories are back-filled from the others.
///
/// With [levelIndex] the player chose which level to shoot: ~50% of the round
/// words are at that level and ~50% come from lower levels to keep it
/// stimulating (a lowest-level pick has nothing below, so it is all that
/// level). Each half uses the same SRS weighting without the learner-level cap
/// on new words, and a short half is back-filled from the other. Distractors
/// ([WordPool.allWords]) still span every level.
WordPoolResult buildWordPool({
  required List<VocabularyWord> words,
  required int learnerLevelIndex,
  required DateTime now,
  required Random random,
  int size = 40,
  int? levelIndex,
}) {
  final usable = <String, VocabularyWord>{};
  for (final word in words) {
    if (word.term.trim().isEmpty || word.meaningVi.trim().isEmpty) continue;
    usable.putIfAbsent(word.term.trim().toLowerCase(), () => word);
  }
  final all = usable.values.toList();
  if (all.length < minimumWordsForRound) {
    return WordPoolInsufficient(available: all.length);
  }

  List<VocabularyWord> picked;
  if (levelIndex == null) {
    picked = _srsPick(
      all,
      min(size, all.length),
      now: now,
      random: random,
      maxNewLevelIndex: learnerLevelIndex + 1,
    );
  } else {
    final atLevel =
        all.where((w) => levelIndexOf(w.difficulty) == levelIndex).toList();
    final lower =
        all.where((w) => levelIndexOf(w.difficulty) < levelIndex).toList();
    final available = atLevel.length + lower.length;
    if (available < minimumWordsForRound) {
      return WordPoolInsufficient(available: available);
    }
    final target = min(size, available);
    final lowerTarget = lower.isEmpty ? 0 : target ~/ 2;
    var levelCount = min(target - lowerTarget, atLevel.length);
    var lowerCount = min(target - levelCount, lower.length);
    levelCount = min(target - lowerCount, atLevel.length);
    picked = [
      ..._srsPick(atLevel, levelCount, now: now, random: random),
      ..._srsPick(lower, lowerCount, now: now, random: random),
    ];
  }
  picked.shuffle(random);
  return WordPoolReady(WordPool(roundWords: picked, allWords: all));
}

/// SRS-weighted draw of [count] words from [candidates]: due reviews first
/// (~50%), then recent/difficult (~30%), then new words, back-filled from
/// whatever is left. New words above [maxNewLevelIndex] are not preferred.
List<VocabularyWord> _srsPick(
  List<VocabularyWord> candidates,
  int count, {
  required DateTime now,
  required Random random,
  int? maxNewLevelIndex,
}) {
  bool isActive(VocabularyWord w) =>
      w.status == WordStatus.learning || w.status == WordStatus.review;
  final due = candidates
      .where((w) =>
          isActive(w) &&
          (w.nextReviewAt == null || !w.nextReviewAt!.isAfter(now)))
      .toList();
  final recentCutoff = now.subtract(const Duration(days: 7));
  final recent = candidates
      .where((w) =>
          isActive(w) &&
          !due.contains(w) &&
          (w.status == WordStatus.learning ||
              (w.lastSeenAt != null && w.lastSeenAt!.isAfter(recentCutoff))))
      .toList();
  final fresh = candidates
      .where((w) =>
          w.status == WordStatus.newWord &&
          (maxNewLevelIndex == null ||
              levelIndexOf(w.difficulty) <= maxNewLevelIndex))
      .toList();

  for (final list in [due, recent, fresh]) {
    list.shuffle(random);
  }
  final target = min(count, candidates.length);
  final picked = <VocabularyWord>[];
  void take(List<VocabularyWord> from, int n) {
    for (final w in from) {
      if (picked.length >= target || n <= 0) return;
      if (picked.contains(w)) continue;
      picked.add(w);
      n--;
    }
  }

  take(due, (target * 0.5).round());
  take(recent, (target * 0.3).round());
  take(fresh, target - picked.length);
  // Back-fill: remaining due/recent/new, then anything else (incl. mastered).
  final rest = [
    ...due,
    ...recent,
    ...fresh,
    ...(List.of(candidates)..shuffle(random))
  ];
  take(rest, target - picked.length);
  return picked;
}

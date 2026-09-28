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
WordPoolResult buildWordPool({
  required List<VocabularyWord> words,
  required int learnerLevelIndex,
  required DateTime now,
  required Random random,
  int size = 40,
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

  bool isActive(VocabularyWord w) =>
      w.status == WordStatus.learning || w.status == WordStatus.review;
  final due = all
      .where((w) =>
          isActive(w) &&
          (w.nextReviewAt == null || !w.nextReviewAt!.isAfter(now)))
      .toList();
  final recentCutoff = now.subtract(const Duration(days: 7));
  final recent = all
      .where((w) =>
          isActive(w) &&
          !due.contains(w) &&
          (w.status == WordStatus.learning ||
              (w.lastSeenAt != null && w.lastSeenAt!.isAfter(recentCutoff))))
      .toList();
  final fresh = all
      .where((w) =>
          w.status == WordStatus.newWord &&
          levelIndexOf(w.difficulty) <= learnerLevelIndex + 1)
      .toList();

  for (final list in [due, recent, fresh]) {
    list.shuffle(random);
  }
  final target = min(size, all.length);
  final picked = <VocabularyWord>[];
  void take(List<VocabularyWord> from, int count) {
    for (final w in from) {
      if (picked.length >= target || count <= 0) return;
      if (picked.contains(w)) continue;
      picked.add(w);
      count--;
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
    ...(List.of(all)..shuffle(random))
  ];
  take(rest, target - picked.length);
  picked.shuffle(random);
  return WordPoolReady(WordPool(roundWords: picked, allWords: all));
}

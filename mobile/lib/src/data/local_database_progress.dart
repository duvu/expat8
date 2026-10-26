part of 'local_database.dart';

/// Learning history and progress totals.
extension LocalDatabaseProgress on LocalDatabase {
  Future<void> appendWordLearnedHistory({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    await _appendLearningHistory(
      snapshot: LearningItemSnapshot.fromVocabularyWord(word),
      state: LearningItemState.learned,
      occurredAt: now,
    );
  }

  Future<void> _appendLearningHistory({
    required LearningItemSnapshot snapshot,
    required LearningItemState state,
    required DateTime occurredAt,
  }) async {
    _learningHistory.put(
      LearningHistoryEntity(
        snapshotJson: jsonEncode(snapshot.toJson()),
        learningState: state.name,
        occurredAtMs: occurredAt.toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<LearningHistoryEntry>> getLearningHistory({
    int limit = -1,
  }) async {
    final rows = _learningHistory
        .query()
        .order(LearningHistoryEntity_.occurredAtMs)
        .build()
        .find();
    final entries = rows
        .map(
          (row) => LearningHistoryEntry.fromJson(
            {
              'snapshot': jsonDecode(row.snapshotJson) as Map<String, dynamic>,
              'state': row.learningState,
              'occurred_at_ms': row.occurredAtMs,
            },
          ),
        )
        .toList(growable: false);
    if (limit >= 0) {
      return entries.take(limit).toList(growable: false);
    }
    return entries;
  }

  Future<LearningProgressTotals> getLearningProgressTotals() async {
    final learned = await _countLearningState(LearningItemState.learned.name);
    final remembered =
        await _countLearningState(LearningItemState.remembered.name);
    final difficult =
        await _countLearningState(LearningItemState.difficult.name);
    return LearningProgressTotals(
      learned: learned,
      remembered: remembered,
      difficult: difficult,
    );
  }

  Future<int> _countLearningState(String state) async {
    final wordCount = _localWords
        .query(LocalWordEntity_.learningState.equals(state))
        .build()
        .count();
    final sentenceCount = _localWorkplaceSentences
        .query(LocalWorkplaceSentenceEntity_.learningState.equals(state))
        .build()
        .count();
    return wordCount + sentenceCount;
  }

  Future<void> _backfillLearningStateFields() async {
    final wordRows = _localWords.getAll();
    for (final row in wordRows) {
      if (row.learningState.isNotEmpty) {
        continue;
      }
      final backfilled = _learningStateFromWordStatus(row.status);
      if (backfilled == null) {
        continue;
      }
      row.learningState = backfilled.name;
      row.learningStateAtMs = row.lastSeenAtMs ?? row.updatedAtMs;
      _localWords.put(row);
    }

    final sentenceRows = _localWorkplaceSentences.getAll();
    for (final row in sentenceRows) {
      if (row.learningState.isNotEmpty) {
        continue;
      }
      final backfilled = _learningStateFromSentenceStatus(row.status);
      if (backfilled == null) {
        continue;
      }
      row.learningState = backfilled.name;
      row.learningStateAtMs = row.lastSeenAtMs ?? row.updatedAtMs;
      _localWorkplaceSentences.put(row);
    }
  }

  LearningItemState? _learningStateFromWordStatus(String status) {
    return switch (status) {
      'mastered' => LearningItemState.remembered,
      'learning' => LearningItemState.learned,
      'review' => LearningItemState.learned,
      _ => null,
    };
  }

  LearningItemState? _learningStateFromSentenceStatus(String status) {
    return switch (status) {
      'seen' => LearningItemState.learned,
      _ => null,
    };
  }
}

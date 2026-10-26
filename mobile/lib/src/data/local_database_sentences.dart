part of 'local_database.dart';

/// Workplace sentences: lookup, states, batches and caps.
extension LocalDatabaseSentences on LocalDatabase {
  Future<void> upsertWorkplaceSentence(WorkplaceSentence sentence) async {
    final existing = _localWorkplaceSentences
        .query(
          LocalWorkplaceSentenceEntity_.localId.equals(sentence.localId),
        )
        .build()
        .findFirst();
    _localWorkplaceSentences.put(
      LocalWorkplaceSentenceEntity(
        id: existing?.id ?? 0,
        localId: sentence.localId,
        serverSentenceId: sentence.serverSentenceId,
        text: sentence.text,
        language: sentence.language,
        meaningVi: sentence.meaningVi,
        topic: sentence.topic,
        sourceTitle: sentence.sourceTitle,
        generationSource: sentence.generationSource,
        isBundled: sentence.isBundled ? 1 : 0,
        status: sentence.status.name,
        lastSeenAtMs: sentence.lastSeenAt?.toUtc().millisecondsSinceEpoch,
        createdAtMs: sentence.createdAt.toUtc().millisecondsSinceEpoch,
        updatedAtMs: sentence.updatedAt.toUtc().millisecondsSinceEpoch,
        learningState: existing?.learningState ?? '',
        learningStateAtMs: existing?.learningStateAtMs,
      ),
    );

    await _logger.debug(
      category: AppLogCategory.database,
      event: 'local_workplace_sentences.upsert',
      message: 'Workplace sentence upserted in local cache.',
      context: {
        'local_id': sentence.localId,
        'server_sentence_id': sentence.serverSentenceId,
        'is_bundled': sentence.isBundled,
      },
    );
  }

  Future<WorkplaceSentence?> nextUnseenWorkplaceSentence({
    String language = 'en',
    Random? random,
  }) async {
    final rows = _localWorkplaceSentences
        .query(
          LocalWorkplaceSentenceEntity_.status
                  .equals(WorkplaceSentenceStatus.unseen.name) &
              LocalWorkplaceSentenceEntity_.language.equals(language),
        )
        .order(
          LocalWorkplaceSentenceEntity_.createdAtMs,
          flags: Order.descending,
        )
        .build()
        .find();
    if (rows.isEmpty) {
      return null;
    }
    final rng = random ?? Random();
    return _workplaceSentenceFromEntity(rows[rng.nextInt(rows.length)]);
  }

  Future<WorkplaceSentence?> randomWorkplaceSentence({
    String language = 'en',
    Random? random,
  }) async {
    final rows = _localWorkplaceSentences
        .query(LocalWorkplaceSentenceEntity_.language.equals(language))
        .build()
        .find();
    if (rows.isEmpty) {
      return null;
    }
    final rng = random ?? Random();
    return _workplaceSentenceFromEntity(rows[rng.nextInt(rows.length)]);
  }

  Future<void> markWorkplaceSentenceSeen({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) async {
    final existing = _localWorkplaceSentences
        .query(
          LocalWorkplaceSentenceEntity_.localId.equals(sentence.localId),
        )
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    existing.status = WorkplaceSentenceStatus.seen.name;
    existing.lastSeenAtMs = now.toUtc().millisecondsSinceEpoch;
    existing.updatedAtMs = now.toUtc().millisecondsSinceEpoch;
    _localWorkplaceSentences.put(existing);
  }

  Future<void> markSentenceLearned({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) async {
    final existing = _localWorkplaceSentences
        .query(
          LocalWorkplaceSentenceEntity_.localId.equals(sentence.localId),
        )
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.status = WorkplaceSentenceStatus.seen.name;
    existing.learningState = LearningItemState.learned.name;
    existing.learningStateAtMs = nowMs;
    existing.lastSeenAtMs = nowMs;
    existing.updatedAtMs = nowMs;
    _localWorkplaceSentences.put(existing);
    await _appendLearningHistory(
      snapshot: LearningItemSnapshot.fromWorkplaceSentence(sentence),
      state: LearningItemState.learned,
      occurredAt: now,
    );
  }

  Future<void> markSentenceRemembered({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) async {
    final existing = _localWorkplaceSentences
        .query(
          LocalWorkplaceSentenceEntity_.localId.equals(sentence.localId),
        )
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.status = WorkplaceSentenceStatus.seen.name;
    existing.learningState = LearningItemState.remembered.name;
    existing.learningStateAtMs = nowMs;
    existing.lastSeenAtMs = nowMs;
    existing.updatedAtMs = nowMs;
    _localWorkplaceSentences.put(existing);
  }

  Future<void> markSentenceDifficult({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) async {
    final existing = _localWorkplaceSentences
        .query(
          LocalWorkplaceSentenceEntity_.localId.equals(sentence.localId),
        )
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.status = WorkplaceSentenceStatus.seen.name;
    existing.learningState = LearningItemState.difficult.name;
    existing.learningStateAtMs = nowMs;
    existing.lastSeenAtMs = nowMs;
    existing.updatedAtMs = nowMs;
    _localWorkplaceSentences.put(existing);
  }

  Future<int> countUnseenWorkplaceSentences({String language = 'en'}) async {
    return _localWorkplaceSentences
        .query(
          LocalWorkplaceSentenceEntity_.status
                  .equals(WorkplaceSentenceStatus.unseen.name) &
              LocalWorkplaceSentenceEntity_.language.equals(language),
        )
        .build()
        .count();
  }

  Future<int> countWorkplaceSentences({String language = 'en'}) async {
    return _localWorkplaceSentences
        .query(LocalWorkplaceSentenceEntity_.language.equals(language))
        .build()
        .count();
  }

  Future<int> addWorkplaceSentenceBatch(
      List<WorkplaceSentence> sentences) async {
    if (sentences.isEmpty) return 0;
    return _store.runAsync(_addWorkplaceSentenceBatchWorker, sentences);
  }

  static Future<int> _addWorkplaceSentenceBatchWorker(
          Store store, List<WorkplaceSentence> sentences) =>
      LocalDatabase(store)._addWorkplaceSentenceBatchHere(sentences);
  Future<int> _addWorkplaceSentenceBatchHere(
      List<WorkplaceSentence> sentences) async {
    var inserted = 0;
    final affectedLanguages = <String>{};
    for (final sentence in sentences) {
      final alreadyExists = _localWorkplaceSentences
          .query(
            LocalWorkplaceSentenceEntity_.localId.equals(sentence.localId),
          )
          .build()
          .findFirst();
      if (alreadyExists == null) {
        inserted += 1;
      }
      await upsertWorkplaceSentence(sentence);
      affectedLanguages.add(sentence.language);
    }
    for (final language in affectedLanguages) {
      await pruneWorkplaceSentencesToCap(
          maxSentences: 1000, language: language);
    }
    return inserted;
  }

  Future<int> pruneWorkplaceSentencesToCap({
    int maxSentences = 1000,
    required String language,
  }) async {
    final rows = _localWorkplaceSentences
        .query(LocalWorkplaceSentenceEntity_.language.equals(language))
        .build()
        .find();
    if (rows.length <= maxSentences) {
      return 0;
    }

    final removable = rows.where((row) => row.isBundled == 0).toList()
      ..sort((a, b) {
        final aTs = a.lastSeenAtMs ?? a.createdAtMs;
        final bTs = b.lastSeenAtMs ?? b.createdAtMs;
        return aTs.compareTo(bTs);
      });

    var removed = 0;
    final targetRemovals = rows.length - maxSentences;
    for (final row in removable.take(targetRemovals)) {
      _localWorkplaceSentences.remove(row.id);
      removed += 1;
    }
    return removed;
  }

  WorkplaceSentence _workplaceSentenceFromEntity(
    LocalWorkplaceSentenceEntity row,
  ) {
    return WorkplaceSentence(
      localId: row.localId,
      serverSentenceId: row.serverSentenceId,
      text: row.text,
      language: row.language,
      meaningVi: row.meaningVi,
      topic: row.topic,
      sourceTitle: row.sourceTitle,
      generationSource: row.generationSource,
      isBundled: row.isBundled == 1,
      status: WorkplaceSentenceStatus.values.byName(row.status),
      lastSeenAt: _parseDateMs(row.lastSeenAtMs),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.createdAtMs, isUtc: true),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row.updatedAtMs, isUtc: true),
    );
  }
}

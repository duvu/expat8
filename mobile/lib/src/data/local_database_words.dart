part of 'local_database.dart';

/// Vocabulary cards: lookup, SRS scheduling, batches and cache caps.
extension LocalDatabaseWords on LocalDatabase {
  /// Stores [word]'s content. A word already on the device keeps its learning
  /// schedule (status, next review, SRS memory): refetched cards — e.g. due
  /// reviews the server sends again — must not reset the learner's progress.
  Future<void> upsertWord(VocabularyWord word) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    final entity = LocalWordEntity(
      id: existing?.id ?? 0,
      localId: word.localId,
      serverWordId: word.serverWordId,
      term: word.term,
      language: word.language,
      meaningVi: word.meaningVi,
      partOfSpeech: word.partOfSpeech,
      ipa: word.ipa,
      vietnamesePronunciation: word.vietnamesePronunciation,
      example: word.example,
      exampleVi: word.exampleVi,
      difficulty: word.difficulty,
      topicsJson: jsonEncode(word.topics),
      status: existing?.status ?? word.status.name,
      lastSeenAtMs: existing != null
          ? existing.lastSeenAtMs
          : word.lastSeenAt?.toUtc().millisecondsSinceEpoch,
      nextReviewAtMs: existing != null
          ? existing.nextReviewAtMs
          : word.nextReviewAt?.toUtc().millisecondsSinceEpoch,
      createdAtMs: word.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtMs: word.updatedAt.toUtc().millisecondsSinceEpoch,
      entryType: word.entryType,
      explanation: word.explanation,
      learningState: existing?.learningState ?? '',
      learningStateAtMs: existing?.learningStateAtMs,
      srsIntervalDays: existing?.srsIntervalDays ?? 0,
      srsEase: existing?.srsEase ?? SrsMemory.defaultEase,
      srsReps: existing?.srsReps ?? 0,
      srsLapses: existing?.srsLapses ?? 0,
    );
    _localWords.put(entity);

    await _logger.debug(
      category: AppLogCategory.database,
      event: 'local_words.upsert',
      message: 'Word upserted in local cache.',
      context: {
        'local_id': word.localId,
        'server_word_id': word.serverWordId,
      },
    );
  }

  Future<void> markWordLearned({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.learningState = LearningItemState.learned.name;
    existing.learningStateAtMs = nowMs;
    existing.lastSeenAtMs = nowMs;
    existing.updatedAtMs = nowMs;
    // Advance nextReviewAtMs by at least 30 minutes so this word is not
    // immediately re-selected as a review candidate by recentlyLearnedReviewWord.
    // Takes max(existing, now + 30 min) so a longer SRS interval is never shortened.
    final minNextReview = nowMs + 30 * 60 * 1000;
    final existingNextReview = existing.nextReviewAtMs ?? 0;
    existing.nextReviewAtMs =
        existingNextReview > minNextReview ? existingNextReview : minNextReview;
    _localWords.put(existing);
    await _appendLearningHistory(
      snapshot: LearningItemSnapshot.fromVocabularyWord(word),
      state: LearningItemState.learned,
      occurredAt: now,
    );
  }

  /// Every cached word for [language] (used by games to build question pools).
  Future<List<VocabularyWord>> wordsForLanguage(String language) async {
    return _localWords
        .query(LocalWordEntity_.language.equals(language))
        .build()
        .find()
        .map(_wordFromEntity)
        .toList();
  }

  /// Every not-yet-studied word for [language]; used for level-aware picking.
  Future<List<VocabularyWord>> newWordsForLanguage(String language) async {
    return _localWords
        .query(
          LocalWordEntity_.status.equals(WordStatus.newWord.name) &
              LocalWordEntity_.language.equals(language),
        )
        .build()
        .find()
        .map(_wordFromEntity)
        .toList();
  }

  Future<VocabularyWord?> nextNewWord({String language = 'en'}) async {
    final rows = _localWords
        .query(
          LocalWordEntity_.status.equals(WordStatus.newWord.name) &
              LocalWordEntity_.language.equals(language),
        )
        .order(LocalWordEntity_.createdAtMs, flags: Order.descending)
        .build()
        .find();
    return rows.isEmpty ? null : _wordFromEntity(rows.first);
  }

  Future<VocabularyWord?> nextDueReviewWord(DateTime now,
      {String language = 'en'}) async {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status
                  .oneOf(LocalDatabase._activeReviewStatuses) &
              (LocalWordEntity_.nextReviewAtMs.isNull() |
                  LocalWordEntity_.nextReviewAtMs.lessOrEqual(nowMs)),
        )
        .build()
        .find();

    if (rows.isEmpty) {
      return null;
    }

    rows.sort((a, b) {
      final aNext = a.nextReviewAtMs ?? -1;
      final bNext = b.nextReviewAtMs ?? -1;
      final nextCompare = aNext.compareTo(bNext);
      if (nextCompare != 0) {
        return nextCompare;
      }
      final aSeen = a.lastSeenAtMs ?? -1;
      final bSeen = b.lastSeenAtMs ?? -1;
      return aSeen.compareTo(bSeen);
    });

    return _wordFromEntity(rows.first);
  }

  Future<VocabularyWord?> recentlyLearnedReviewWord(
    DateTime now, {
    String language = 'en',
  }) async {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status
                  .oneOf(LocalDatabase._activeReviewStatuses) &
              LocalWordEntity_.lastSeenAtMs.notNull() &
              (LocalWordEntity_.nextReviewAtMs.isNull() |
                  LocalWordEntity_.nextReviewAtMs.lessOrEqual(nowMs)),
        )
        .build()
        .find();

    if (rows.isEmpty) {
      return null;
    }

    rows.sort((a, b) {
      final seenCompare =
          (b.lastSeenAtMs ?? -1).compareTo(a.lastSeenAtMs ?? -1);
      if (seenCompare != 0) {
        return seenCompare;
      }
      return b.updatedAtMs.compareTo(a.updatedAtMs);
    });

    return _wordFromEntity(rows.first);
  }

  Future<VocabularyWord?> nextDifficultRelearnWord(DateTime now,
      {String language = 'en'}) async {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status.equals(WordStatus.learning.name) &
              (LocalWordEntity_.nextReviewAtMs.isNull() |
                  LocalWordEntity_.nextReviewAtMs.lessOrEqual(nowMs)),
        )
        .build()
        .find();

    if (rows.isEmpty) {
      return null;
    }

    rows.sort((a, b) {
      final aTs = a.nextReviewAtMs ?? a.updatedAtMs;
      final bTs = b.nextReviewAtMs ?? b.updatedAtMs;
      return aTs.compareTo(bTs);
    });

    return _wordFromEntity(rows.first);
  }

  Future<List<String>> recentServerWordIds({int limit = 20}) async {
    final rows = _localWords
        .query(LocalWordEntity_.serverWordId.notNull())
        .build()
        .find();

    rows.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return bTs.compareTo(aTs);
    });

    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final serverWordId = row.serverWordId;
      if (serverWordId == null ||
          serverWordId.isEmpty ||
          seen.contains(serverWordId)) {
        continue;
      }
      seen.add(serverWordId);
      result.add(serverWordId);
      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  Future<List<String>> activeCachedServerWordIds({int limit = 1000}) async {
    final rows = _localWords
        .query(LocalWordEntity_.serverWordId.notNull())
        .build()
        .find();

    rows.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return bTs.compareTo(aTs);
    });

    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final serverWordId = row.serverWordId;
      if (serverWordId == null ||
          serverWordId.isEmpty ||
          seen.contains(serverWordId)) {
        continue;
      }
      seen.add(serverWordId);
      result.add(serverWordId);
      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  Future<bool> deleteLocalWord(String localId) async {
    final query =
        _localWords.query(LocalWordEntity_.localId.equals(localId)).build();
    final matches = query.find();
    if (matches.isEmpty) {
      return false;
    }
    for (final entity in matches) {
      _localWords.remove(entity.id);
    }
    return true;
  }

  Future<VocabularyWord?> getWordByServerId(String serverWordId) async {
    final row = _localWords
        .query(LocalWordEntity_.serverWordId.equals(serverWordId))
        .build()
        .findFirst();
    return row == null ? null : _wordFromEntity(row);
  }

  /// Schedules [word]'s next review from [rating] with the shared SRS
  /// scheduler (the same result the server computes once the event syncs).
  Future<void> updateWordAfterRating({
    required VocabularyWord word,
    required StudyRating rating,
    required DateTime now,
  }) =>
      applySrsRating(localId: word.localId, rating: rating, now: now);

  /// Applies one rating to the word's spaced-repetition memory and schedule.
  Future<void> applySrsRating({
    required String localId,
    required StudyRating rating,
    required DateTime now,
    String? learningState,
  }) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(localId))
        .build()
        .findFirst();
    if (existing == null) return;
    final memory = SrsMemory(
      reps: existing.srsReps,
      lapses: existing.srsLapses,
      ease: existing.srsEase,
      intervalDays: existing.srsIntervalDays,
    ).rate(rating);
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing
      ..srsReps = memory.reps
      ..srsLapses = memory.lapses
      ..srsEase = memory.ease
      ..srsIntervalDays = memory.intervalDays
      ..status = memory.status.name
      ..nextReviewAtMs = memory.dueAfter(now.toUtc()).millisecondsSinceEpoch
      ..lastSeenAtMs = nowMs
      ..updatedAtMs = nowMs;
    if (learningState != null) {
      existing
        ..learningState = learningState
        ..learningStateAtMs = nowMs;
    }
    _localWords.put(existing);
  }

  /// Adopts the server's schedule for pulled words (`GET /v1/review/states`).
  /// A word with events still waiting to upload keeps its local schedule: the
  /// server state predates them, and the next pull brings the merged result.
  Future<void> applyServerReviewStates(
    List<ServerReviewState> states, {
    required String? ownerUserId,
  }) async {
    if (states.isEmpty) return;
    await _store.runAsync(_applyServerStatesWorker, (states, ownerUserId));
  }

  static Future<void> _applyServerStatesWorker(
          Store store, (List<ServerReviewState>, String?) args) =>
      LocalDatabase(store)._applyServerStatesHere(args.$1, args.$2);

  Future<void> _applyServerStatesHere(
      List<ServerReviewState> states, String? ownerUserId) async {
    final pendingWordIds = _pendingEventWordIds(ownerUserId);
    for (final state in states) {
      final localId = state.word.localId;
      if (pendingWordIds.contains(localId)) continue;
      await upsertWord(state.word);
      final entity = _localWords
          .query(LocalWordEntity_.localId.equals(localId))
          .build()
          .findFirst();
      if (entity == null) continue;
      _localWords.put(entity
        ..status = state.status.name
        ..nextReviewAtMs = state.nextReviewAt?.millisecondsSinceEpoch
        ..lastSeenAtMs = state.lastStudiedAt?.millisecondsSinceEpoch
        ..srsEase = state.ease
        ..srsIntervalDays = state.intervalDays
        ..srsReps = state.reps
        ..srsLapses = state.lapses);
    }
  }

  /// Rebuilds every word's schedule for [ownerUserId] (null = signed out)
  /// from that account's own study events on this device, so switching
  /// accounts on a shared family device never mixes progress. Works offline;
  /// a later [applyServerReviewStates] adds what was studied elsewhere.
  Future<void> rebuildScheduleForOwner(String? ownerUserId) =>
      _store.runAsync(_rebuildScheduleWorker, ownerUserId);

  static Future<void> _rebuildScheduleWorker(
          Store store, String? ownerUserId) =>
      LocalDatabase(store)._rebuildScheduleHere(ownerUserId);

  // Only the schedule is per account; learning history (learningState) and
  // lastSeen stay as they are (the progress screen counts learningState).
  Future<void> _rebuildScheduleHere(String? ownerUserId) async {
    final words = _localWords.getAll();
    for (final word in words) {
      word
        ..status = WordStatus.newWord.name
        ..nextReviewAtMs = null
        ..srsEase = SrsMemory.defaultEase
        ..srsIntervalDays = 0
        ..srsReps = 0
        ..srsLapses = 0;
    }
    _localWords.putMany(words);
    final events = (ownerUserId == null
            ? _studyEvents.query(StudyEventEntity_.ownerUserId.isNull())
            : _studyEvents
                .query(StudyEventEntity_.ownerUserId.equals(ownerUserId)))
        .order(StudyEventEntity_.occurredAtMs)
        .build()
        .find();
    for (final event in events) {
      final rating = StudyRating.values
          .where((r) => r.apiValue == event.rating)
          .firstOrNull;
      if (rating == null) continue;
      await applySrsRating(
        localId: event.localWordId,
        rating: rating,
        now: DateTime.fromMillisecondsSinceEpoch(event.occurredAtMs,
            isUtc: true),
      );
    }
  }

  /// Words with not-yet-uploaded events that will be sent under
  /// [ownerUserId]'s session (theirs, plus signed-out ones they will claim).
  Set<String> _pendingEventWordIds(String? ownerUserId) => _studyEvents
      .query(StudyEventEntity_.syncStatus.equals(SyncStatus.pending.name))
      .build()
      .find()
      .where((e) => e.ownerUserId == null || e.ownerUserId == ownerUserId)
      .map((e) => e.localWordId)
      .toSet();

  /// Makes [word] due for review now (e.g. picked while reading an article).
  /// A word the learner already studies keeps its SRS memory; only its next
  /// review moves up.
  Future<void> scheduleReviewNow({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    await upsertWord(word);
    final entity = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    if (entity == null) return;
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    if (entity.status == WordStatus.newWord.name) {
      entity.status = WordStatus.learning.name;
    }
    _localWords.put(entity
      ..nextReviewAtMs = nowMs
      ..updatedAtMs = nowMs);
  }

  /// "Remembered" swipe: rated `too_easy`, so the word comes back rarely.
  Future<void> markWordRememberedLowFrequency({
    required VocabularyWord word,
    required DateTime now,
  }) =>
      applySrsRating(
        localId: word.localId,
        rating: StudyRating.tooEasy,
        now: now,
        learningState: LearningItemState.remembered.name,
      );

  /// "Difficult" swipe: rated `too_hard`, so the word is relearned in minutes.
  Future<void> markWordDifficultForRelearn({
    required VocabularyWord word,
    required DateTime now,
  }) =>
      applySrsRating(
        localId: word.localId,
        rating: StudyRating.tooHard,
        now: now,
        learningState: LearningItemState.difficult.name,
      );

  /// Transitions a [newWord] word to [learning] status on first display.
  ///
  /// Schedules a review in 24 hours so the word enters the SRS cycle.
  /// Safe to call fire-and-forget — no-op if word not found.
  Future<void> markWordAsLearning({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    if (existing == null) return;

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.status = WordStatus.learning.name;
    existing.lastSeenAtMs = nowMs;
    existing.nextReviewAtMs =
        now.toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    existing.updatedAtMs = nowMs;
    _localWords.put(existing);
  }

  Future<int> countUnstudiedNewWords({String language = 'en'}) async {
    return _localWords
        .query(
          LocalWordEntity_.status.equals(WordStatus.newWord.name) &
              LocalWordEntity_.language.equals(language),
        )
        .build()
        .count();
  }

  Future<int> countWords({String language = 'en'}) async {
    return _localWords
        .query(LocalWordEntity_.language.equals(language))
        .build()
        .count();
  }

  /// Picks a random word for [language] whose status is not [mastered]
  /// (i.e., not yet marked as remembered). Used as the fallback when no
  /// new-word card is available so the learner always has something to study.
  Future<VocabularyWord?> randomNotMasteredWord({
    String language = 'en',
    Random? random,
  }) async {
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status.notEquals(WordStatus.mastered.name),
        )
        .build()
        .find();
    if (rows.isEmpty) return null;
    final rng = random ?? Random();
    return _wordFromEntity(rows[rng.nextInt(rows.length)]);
  }

  /// Picks any cached word for [language], including mastered words.
  ///
  /// This is the final offline fallback: if the learner has exhausted every
  /// new/learning/review card, the app must still show something instead of
  /// leaving the card area empty.
  Future<VocabularyWord?> randomWord({
    String language = 'en',
    Random? random,
  }) async {
    final rows = _localWords
        .query(LocalWordEntity_.language.equals(language))
        .build()
        .find();
    if (rows.isEmpty) return null;
    final rng = random ?? Random();
    return _wordFromEntity(rows[rng.nextInt(rows.length)]);
  }

  /// Deletes up to [limit] oldest mastered (remembered) words for [language],
  /// skipping any with pending sync events. Returns the number actually removed.
  Future<int> deleteOldestMasteredWords({
    String language = 'en',
    required int limit,
  }) async {
    if (limit <= 0) return 0;
    final pendingLocalIds = _studyEvents
        .query(StudyEventEntity_.syncStatus.equals(SyncStatus.pending.name))
        .build()
        .find()
        .map((e) => e.localWordId)
        .toSet();

    final rows = _localWords
        .query(
          LocalWordEntity_.status.equals(WordStatus.mastered.name) &
              LocalWordEntity_.language.equals(language),
        )
        .build()
        .find()
        .where((e) => !pendingLocalIds.contains(e.localId))
        .toList();

    rows.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return aTs.compareTo(bTs);
    });

    final toDelete = rows.take(limit).toList();
    for (final row in toDelete) {
      _localWords.remove(row.id);
    }
    return toDelete.length;
  }

  /// Adds a batch of words to the local cache.
  ///
  /// Enforces the per-language 1000-word cap after every batch write.
  /// Pruning runs once per language present in [words] so seeding one language
  /// never evicts entries from another.
  /// Stores fetched cards and trims the cache. Runs on ObjectBox's background
  /// worker (same store, attached there) so a top-up never stalls the UI.
  Future<void> addBatch(List<VocabularyWord> words) async {
    if (words.isEmpty) return;
    await _store.runAsync(_addBatchWorker, words);
  }

  static Future<void> _addBatchWorker(
          Store store, List<VocabularyWord> words) =>
      LocalDatabase(store)._addBatchHere(words);
  Future<void> _addBatchHere(List<VocabularyWord> words) async {
    final affectedLanguages = <String>{};
    for (final word in words) {
      await upsertWord(word);
      affectedLanguages.add(word.language);
    }
    for (final language in affectedLanguages) {
      await pruneToCapSmartly(maxWords: 1000, language: language);
    }
  }

  /// Prunes the local word store for [language] (or globally when null) to
  /// [maxWords] using smart priority ordering:
  ///
  /// Pass 1: Remove [mastered] words (least-recently-seen first).
  /// Pass 2: Remove [review] words with nextReviewAt > 30 days from now
  ///         (farthest-first).
  /// Pass 3: Fallback — remove oldest words by createdAt.
  ///
  /// Words with pending (unsynced) study events are skipped in all passes.
  Future<int> pruneToCapSmartly({
    int maxWords = 1000,
    String? language,
    DateTime? now,
  }) async {
    final all = language == null
        ? _localWords.getAll()
        : _localWords
            .query(LocalWordEntity_.language.equals(language))
            .build()
            .find();
    if (all.length <= maxWords) return 0;

    // Build set of localIds that have pending sync events.
    final pendingLocalIds = _studyEvents
        .query(StudyEventEntity_.syncStatus.equals(SyncStatus.pending.name))
        .build()
        .find()
        .map((e) => e.localWordId)
        .toSet();

    bool hasPending(LocalWordEntity e) => pendingLocalIds.contains(e.localId);

    var removed = 0;
    final nowMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final thirtyDaysMs = const Duration(days: 30).inMilliseconds;

    // Pass 1: mastered words, least-recently-seen first.
    if (all.length - removed > maxWords) {
      final mastered = all
          .where((e) => e.status == WordStatus.mastered.name && !hasPending(e))
          .toList()
        ..sort((a, b) {
          final aTs = a.lastSeenAtMs ?? 0;
          final bTs = b.lastSeenAtMs ?? 0;
          return aTs.compareTo(bTs); // ascending: least-recently-seen first
        });
      for (final row in mastered) {
        if (all.length - removed <= maxWords) break;
        _localWords.remove(row.id);
        removed += 1;
      }
    }

    // Pass 2: review words with nextReviewAt far in the future (> 30 days).
    if (all.length - removed > maxWords) {
      final farReview = all
          .where((e) =>
              e.status == WordStatus.review.name &&
              !hasPending(e) &&
              (e.nextReviewAtMs != null &&
                  e.nextReviewAtMs! > nowMs + thirtyDaysMs))
          .toList()
        ..sort((a, b) {
          final aTs = a.nextReviewAtMs ?? 0;
          final bTs = b.nextReviewAtMs ?? 0;
          return bTs.compareTo(aTs); // descending: farthest first
        });
      for (final row in farReview) {
        if (all.length - removed <= maxWords) break;
        _localWords.remove(row.id);
        removed += 1;
      }
    }

    // Pass 3: fallback — oldest by createdAt, skipping pending.
    if (all.length - removed > maxWords) {
      final oldest = all.where((e) => !hasPending(e)).toList()
        ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
      for (final row in oldest) {
        if (all.length - removed <= maxWords) break;
        // Skip rows already removed in earlier passes.
        if (_localWords.get(row.id) == null) continue;
        _localWords.remove(row.id);
        removed += 1;
      }
    }

    return removed;
  }

  Future<int> pruneToMostRecent({int maxWords = 1000}) async {
    final words = _localWords.getAll();
    if (words.length <= maxWords) {
      return 0;
    }

    words.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return bTs.compareTo(aTs);
    });

    final stale = words.skip(maxWords).toList(growable: false);
    for (final row in stale) {
      _localWords.remove(row.id);
    }
    return stale.length;
  }
}

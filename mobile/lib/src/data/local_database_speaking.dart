part of 'local_database.dart';

/// Speaking prompt cache and recorded attempts.
extension LocalDatabaseSpeaking on LocalDatabase {
  // ---- Speaking prompt cache ----

  /// Upserts a speaking prompt into the local cache.
  void cacheSpeakingPrompt(SpeakingPromptEntity entity) {
    _speakingPrompts.put(entity);
  }

  /// Returns the cached prompt for [promptId], or null if not cached.
  SpeakingPromptEntity? getCachedPrompt(String promptId) {
    return _speakingPrompts
        .query(SpeakingPromptEntity_.promptId.equals(promptId))
        .build()
        .findFirst();
  }

  /// Returns up to [limit] cached prompts linked to [serverWordId].
  List<SpeakingPromptEntity> promptsForWord(String serverWordId,
      {int limit = 5}) {
    return _speakingPrompts
        .query(SpeakingPromptEntity_.serverWordId.equals(serverWordId))
        .build()
        .find()
        .take(limit)
        .toList(growable: false);
  }

  /// Returns up to [limit] cached prompts, most recently cached first.
  /// Used by drill selection when choosing from the local cache.
  List<SpeakingPromptEntity> recentCachedPrompts({int limit = 10}) {
    return _speakingPrompts
        .query()
        .order(SpeakingPromptEntity_.cachedAtMs, flags: Order.descending)
        .build()
        .find()
        .take(limit)
        .toList(growable: false);
  } // ---- Speaking attempt storage ----

  /// Saves a new speaking attempt entity, returning the ObjectBox id.
  int saveSpeakingAttempt(SpeakingAttemptEntity entity) {
    return _speakingAttempts.put(entity);
  }

  /// Updates an existing speaking attempt (by ObjectBox id).
  void updateSpeakingAttempt(SpeakingAttemptEntity entity) {
    _speakingAttempts.put(entity);
  }

  /// Returns the attempt entity with [attemptId], or null.
  SpeakingAttemptEntity? getSpeakingAttempt(String attemptId) {
    return _speakingAttempts
        .query(SpeakingAttemptEntity_.attemptId.equals(attemptId))
        .build()
        .findFirst();
  }

  /// Marks the attempt identified by [attemptId] as synced and removes its
  /// sync queue entry.
  void markSpeakingAttemptSynced(String attemptId) {
    final entity = getSpeakingAttempt(attemptId);
    if (entity != null) {
      entity.syncStatus = SyncStatus.synced.name;
      _speakingAttempts.put(entity);
    }
    // Remove from sync queue (payload contains the attempt_id).
    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.payload.contains('"attempt_id":"$attemptId"')) {
        _syncQueue.remove(item.id);
      }
    }
  }

  /// Queues a speaking event payload (JSON string) for background sync.
  void enqueueSpeakingEvent(String payloadJson) {
    _syncQueue.put(
      SyncQueueEntity(
        type: 'speaking_event',
        payload: payloadJson,
        retryCount: 0,
        nextRetryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  /// Deletes all speaking attempt entities and clears their sync queue
  /// entries. Audio files are managed by [AudioFileManager] separately.
  Future<int> deleteAllSpeakingAttempts() async {
    final count = _speakingAttempts.count();
    _speakingAttempts.removeAll();
    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.type == 'speaking_event') {
        _syncQueue.remove(item.id);
      }
    }
    return count;
  }

  /// Returns the total number of speaking attempts stored locally.
  int countSpeakingAttempts() => _speakingAttempts.count();

  /// Speaking attempts recorded at or after [sinceMs] (UTC epoch ms).
  List<SpeakingAttemptEntity> speakingAttemptsSince(int sinceMs) =>
      _speakingAttempts
          .query(SpeakingAttemptEntity_.occurredAtMs.greaterOrEqual(sinceMs))
          .build()
          .find();

  /// Returns all cached prompts linked to [wordSenseId].
  List<SpeakingPromptEntity> getPromptsByWordSenseId(String wordSenseId) {
    return _speakingPrompts
        .query(SpeakingPromptEntity_.wordSenseId.equals(wordSenseId))
        .build()
        .find();
  }

  /// Upserts a batch of speaking prompts from the server sync endpoint.
  ///
  /// Existing entries are updated in-place (preserving their ObjectBox id);
  /// new entries are inserted. Any prompts not present in [prompts] are
  /// deleted from local storage (they have been removed on the server).
  void upsertAllSpeakingPrompts(List<SpeakingPromptEntity> prompts) {
    for (final prompt in prompts) {
      final existing = _speakingPrompts
          .query(SpeakingPromptEntity_.promptId.equals(prompt.promptId))
          .build()
          .findFirst();
      _speakingPrompts.put(
        SpeakingPromptEntity(
          id: existing?.id ?? 0,
          promptId: prompt.promptId,
          wordSenseId: prompt.wordSenseId,
          serverWordId: prompt.serverWordId,
          targetText: prompt.targetText,
          viHint: prompt.viHint,
          targetPhrase: prompt.targetPhrase,
          pronunciationTip: prompt.pronunciationTip,
          commonMistake: prompt.commonMistake,
          difficulty: prompt.difficulty,
          topic: prompt.topic,
          cachedAtMs: prompt.cachedAtMs,
        ),
      );
    }
    // Delete any locally-cached prompts that were not in the server response.
    // An empty response is treated as "no information" rather than "delete
    // everything", so offline drills keep working after a bad sync.
    if (prompts.isEmpty) return;
    final receivedIds = prompts.map((p) => p.promptId).toSet();
    final allLocal = _speakingPrompts.getAll();
    final staleObjectIds = allLocal
        .where((p) => !receivedIds.contains(p.promptId))
        .map((p) => p.id)
        .toList();
    if (staleObjectIds.isNotEmpty) {
      _speakingPrompts.removeMany(staleObjectIds);
    }
  }
}

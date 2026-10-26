part of 'local_database.dart';

/// Offline sync queue, study events and submitted words.
extension LocalDatabaseSync on LocalDatabase {
  Future<void> upsertSubmittedWord(SubmittedWord submission) async {
    final existing = _submittedWords
        .query(
          SubmittedWordEntity_.localSubmissionId
              .equals(submission.localSubmissionId),
        )
        .build()
        .findFirst();
    _submittedWords.put(
      SubmittedWordEntity(
        id: existing?.id ?? 0,
        localSubmissionId: submission.localSubmissionId,
        serverSubmissionId: submission.serverSubmissionId,
        submittedTerm: submission.submittedTerm,
        targetLanguage: submission.targetLanguage,
        status: submission.status.name,
        failureReason: submission.failureReason,
        resolutionType: switch (submission.resolutionType) {
          SubmittedWordResolutionType.existingWord => 'existing_word',
          SubmittedWordResolutionType.generatedWord => 'generated_word',
          null => null,
        },
        resolvedWordServerId: submission.resolvedWord?.serverWordId ??
            existing?.resolvedWordServerId,
        createdAtMs: submission.createdAt.toUtc().millisecondsSinceEpoch,
        updatedAtMs: submission.updatedAt.toUtc().millisecondsSinceEpoch,
        resolvedAtMs: submission.resolvedAt?.toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  Future<SubmittedWord?> getSubmittedWord(String localSubmissionId) async {
    final row = _submittedWords
        .query(
          SubmittedWordEntity_.localSubmissionId.equals(localSubmissionId),
        )
        .build()
        .findFirst();
    return row == null ? null : _submittedWordFromEntity(row);
  }

  Future<List<SubmittedWord>> listSubmittedWords({int limit = 200}) async {
    final rows = _submittedWords
        .query()
        .order(SubmittedWordEntity_.updatedAtMs, flags: Order.descending)
        .build()
        .find();
    final items = rows.map(_submittedWordFromEntity).toList(growable: false);
    return items.take(limit).toList(growable: false);
  }

  /// Queues a finished game round summary for upload.
  Future<void> enqueueGameRound(Map<String, dynamic> round) async {
    _syncQueue.put(
      SyncQueueEntity(
        type: 'game_round',
        payload: jsonEncode(round),
        retryCount: 0,
        nextRetryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> enqueueSubmittedWordCreate(
    String localSubmissionId, {
    DateTime? nextRetryAt,
  }) async {
    final existing = _findSubmittedWordQueueEntry(
      type: 'submitted_word_create',
      localSubmissionId: localSubmissionId,
    );
    final nextRetryAtMs =
        (nextRetryAt ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch;
    if (existing != null) {
      existing.nextRetryAtMs = nextRetryAtMs;
      existing.retryCount = 0;
      _syncQueue.put(existing);
      return;
    }
    _syncQueue.put(
      SyncQueueEntity(
        type: 'submitted_word_create',
        payload: jsonEncode({'local_submission_id': localSubmissionId}),
        retryCount: 0,
        nextRetryAtMs: nextRetryAtMs,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> enqueueSubmittedWordStatus(
    String localSubmissionId, {
    required String serverSubmissionId,
    DateTime? nextRetryAt,
  }) async {
    final existing = _findSubmittedWordQueueEntry(
      type: 'submitted_word_status',
      localSubmissionId: localSubmissionId,
    );
    final payload = jsonEncode({
      'local_submission_id': localSubmissionId,
      'server_submission_id': serverSubmissionId,
    });
    final nextRetryAtMs =
        (nextRetryAt ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch;
    if (existing != null) {
      existing.payload = payload;
      existing.nextRetryAtMs = nextRetryAtMs;
      existing.retryCount = 0;
      _syncQueue.put(existing);
      return;
    }
    _syncQueue.put(
      SyncQueueEntity(
        type: 'submitted_word_status',
        payload: payload,
        retryCount: 0,
        nextRetryAtMs: nextRetryAtMs,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> removeSyncQueueEntry(int id) async {
    _syncQueue.remove(id);
  }

  Future<void> removeSubmittedWordQueueEntries(String localSubmissionId) async {
    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (_queuePayloadContainsLocalSubmissionId(item, localSubmissionId)) {
        _syncQueue.remove(item.id);
      }
    }
  }

  /// Persists [event] for the signed-in account (or none) and queues it.
  /// The owner travels in the queue payload as a local-only key that the sync
  /// loop strips before upload.
  Future<void> insertStudyEvent(StudyEvent event) async {
    final ownerUserId = (await loadUserSession())?.userId;
    final payload = jsonEncode({
      ...event.toSyncJson(),
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
    });

    final existing = _studyEvents
        .query(StudyEventEntity_.clientEventId.equals(event.clientEventId))
        .build()
        .findFirst();
    if (existing == null) {
      _studyEvents.put(
        StudyEventEntity(
          clientEventId: event.clientEventId,
          localWordId: event.localWordId,
          serverWordId: event.serverWordId,
          rating: event.rating.apiValue,
          occurredAtMs: event.occurredAt.toUtc().millisecondsSinceEpoch,
          syncStatus: event.syncStatus.name,
          ownerUserId: ownerUserId,
        ),
      );
    }

    _syncQueue.put(
      SyncQueueEntity(
        type: 'study_event',
        payload: payload,
        retryCount: 0,
        nextRetryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  /// Gives [userId] every study event recorded without an account (before
  /// signing in, or before events had owners), mirroring the server, which
  /// moves a device's anonymous progress to the account that signs in on it.
  Future<void> claimUnownedEvents(String userId) async {
    final unowned = _studyEvents
        .query(StudyEventEntity_.ownerUserId.isNull())
        .build()
        .find();
    _studyEvents.putMany([for (final e in unowned) e..ownerUserId = userId]);
    final queued = _syncQueue
        .query(SyncQueueEntity_.type.equals('study_event'))
        .build()
        .find();
    final claimed = <SyncQueueEntity>[];
    for (final row in queued) {
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      if (payload['owner_user_id'] != null) continue;
      row.payload = jsonEncode({...payload, 'owner_user_id': userId});
      claimed.add(row);
    }
    _syncQueue.putMany(claimed);
  }

  /// The next queued writes to upload, oldest first. Study events of other
  /// accounts on a shared device are skipped (they wait for their owner's
  /// session) so they can never crowd the batch.
  Future<List<SyncQueueEntry>> dueSyncEntries(DateTime now) async {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final currentOwner = (await loadUserSession())?.userId;
    final rows = _syncQueue
        .query(SyncQueueEntity_.nextRetryAtMs.lessOrEqual(nowMs))
        .order(SyncQueueEntity_.createdAtMs)
        .build()
        .find()
        .where((row) {
      final owner = _queueOwner(row);
      return owner == null || owner == currentOwner;
    });

    return rows.take(50).map(_queueFromEntity).toList(growable: false);
  }

  static String? _queueOwner(SyncQueueEntity row) {
    if (row.type != 'study_event') return null;
    try {
      return (jsonDecode(row.payload) as Map<String, dynamic>)['owner_user_id']
          as String?;
    } on FormatException {
      return null;
    }
  }

  Future<void> markEventSynced(String clientEventId) async {
    _finishEventSync(clientEventId, SyncStatus.synced);
  }

  /// Marks an event the server permanently rejected and stops retrying it.
  /// The event itself stays in local history.
  Future<void> markEventFailed(String clientEventId) async {
    _finishEventSync(clientEventId, SyncStatus.failed);
  }

  void _finishEventSync(String clientEventId, SyncStatus status) {
    final event = _studyEvents
        .query(StudyEventEntity_.clientEventId.equals(clientEventId))
        .build()
        .findFirst();
    if (event != null) {
      event.syncStatus = status.name;
      _studyEvents.put(event);
    }

    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.payload.contains('"client_event_id":"$clientEventId"')) {
        _syncQueue.remove(item.id);
      }
    }
  }

  Future<void> scheduleRetry(SyncQueueEntry entry, DateTime now) async {
    if (entry.id == null) {
      return;
    }

    final entity = _syncQueue.get(entry.id!);
    if (entity == null) {
      return;
    }

    final retryCount = entry.retryCount + 1;
    final delayMinutes = retryCount.clamp(1, 30).toInt();

    entity.retryCount = retryCount;
    entity.nextRetryAtMs =
        now.add(Duration(minutes: delayMinutes)).toUtc().millisecondsSinceEpoch;
    _syncQueue.put(entity);

    await _logger.warning(
      category: AppLogCategory.sync,
      event: 'sync_queue.retry_scheduled',
      message: 'Sync retry scheduled for queue entry.',
      context: {
        'queue_id': entry.id,
        'retry_count': retryCount,
      },
    );
  }

  SyncQueueEntry _queueFromEntity(SyncQueueEntity row) {
    return SyncQueueEntry(
      id: row.id,
      type: row.type,
      payload: row.payload,
      retryCount: row.retryCount,
      nextRetryAt:
          DateTime.fromMillisecondsSinceEpoch(row.nextRetryAtMs, isUtc: true),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.createdAtMs, isUtc: true),
    );
  }

  SubmittedWord _submittedWordFromEntity(SubmittedWordEntity row) {
    final resolvedWordRow = row.resolvedWordServerId == null
        ? null
        : _localWords
            .query(
              LocalWordEntity_.serverWordId.equals(row.resolvedWordServerId!),
            )
            .build()
            .findFirst();
    return SubmittedWord(
      localSubmissionId: row.localSubmissionId,
      serverSubmissionId: row.serverSubmissionId,
      submittedTerm: row.submittedTerm,
      targetLanguage: row.targetLanguage,
      status: SubmittedWordStatus.values.byName(row.status),
      failureReason: row.failureReason,
      resolutionType: switch (row.resolutionType) {
        'existing_word' => SubmittedWordResolutionType.existingWord,
        'generated_word' => SubmittedWordResolutionType.generatedWord,
        _ => null,
      },
      resolvedWord:
          resolvedWordRow == null ? null : _wordFromEntity(resolvedWordRow),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.createdAtMs, isUtc: true),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row.updatedAtMs, isUtc: true),
      resolvedAt: _parseDateMs(row.resolvedAtMs),
    );
  }

  SyncQueueEntity? _findSubmittedWordQueueEntry({
    required String type,
    required String localSubmissionId,
  }) {
    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.type == type &&
          _queuePayloadContainsLocalSubmissionId(item, localSubmissionId)) {
        return item;
      }
    }
    return null;
  }

  bool _queuePayloadContainsLocalSubmissionId(
    SyncQueueEntity item,
    String localSubmissionId,
  ) {
    return item.payload.contains('"local_submission_id":"$localSubmissionId"');
  }
}

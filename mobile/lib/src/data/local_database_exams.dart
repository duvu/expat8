part of 'local_database.dart';

/// Exam attempts and their sync.
extension LocalDatabaseExams on LocalDatabase {
  // ─── Exam Attempts ──────────────────────────────────────────────────────────

  /// Persists a new exam attempt. Returns the ObjectBox id.
  int saveExamAttempt(ExamAttemptEntity entity) {
    return _examAttempts.put(entity);
  }

  /// Returns an exam attempt by its [attemptId] (local or server-assigned), or null.
  ExamAttemptEntity? getExamAttempt(String attemptId) {
    return _examAttempts
        .query(ExamAttemptEntity_.attemptId.equals(attemptId))
        .build()
        .findFirst();
  }

  /// Returns all locally cached exam attempts, newest first.
  List<ExamAttemptEntity> getAllExamAttempts() {
    return _examAttempts
        .query()
        .order(ExamAttemptEntity_.createdAtMs, flags: Order.descending)
        .build()
        .find();
  }

  /// Returns the total number of exam attempts stored locally.
  int countExamAttempts() => _examAttempts.count();

  /// Deletes all locally cached exam attempts.
  void deleteAllExamAttempts() => _examAttempts.removeAll();

  /// Queues a completed exam result for background sync to the backend.
  ///
  /// [localAttemptId] is a stable client-generated UUID used as the
  /// idempotency key so retries do not create duplicate backend records.
  void enqueueExamResult({
    required String localAttemptId,
    required String sessionId,
    required List<int> answers,
    required String language,
  }) {
    final payload = jsonEncode({
      'local_attempt_id': localAttemptId,
      'session_id': sessionId,
      'answers': answers,
      'language': language,
    });
    _syncQueue.put(
      SyncQueueEntity(
        type: 'exam_result',
        payload: payload,
        retryCount: 0,
        nextRetryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  /// Updates the locally stored exam attempt with the confirmed backend result
  /// and marks its sync status as 'synced'. Also removes the corresponding
  /// sync queue entry identified by [localAttemptId].
  void markExamAttemptSynced({
    required String localAttemptId,
    required String serverAttemptId,
    required int correctCount,
    required double scorePct,
    required bool passed,
    String? certificateId,
  }) {
    final entity = getExamAttempt(localAttemptId);
    if (entity != null) {
      entity.attemptId = serverAttemptId;
      entity.correctCount = correctCount;
      entity.scorePct = scorePct;
      entity.passed = passed ? 1 : 0;
      entity.certificateId = certificateId;
      entity.syncStatus = 'synced';
      _examAttempts.put(entity);
    }

    // Remove from sync queue (payload contains the local_attempt_id).
    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.type == 'exam_result' &&
          item.payload.contains('"local_attempt_id":"$localAttemptId"')) {
        _syncQueue.remove(item.id);
      }
    }
  }
}

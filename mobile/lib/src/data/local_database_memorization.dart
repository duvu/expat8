part of 'local_database.dart';

/// Memorization passages, segments and progress.
extension LocalDatabaseMemorization on LocalDatabase {
  // ---------------------------------------------------------------------------
  // Memorization passages — local cache
  // ---------------------------------------------------------------------------

  /// Upserts passage metadata into the local cache.
  void upsertPassage(LocalPassageEntity entity) {
    _passages.put(entity);
  }

  /// Returns all cached passages, sorted by createdAt descending.
  List<LocalPassageEntity> getAllPassages() {
    return _passages.getAll()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Removes a passage and its cached segments and progress.
  void removePassageLocal(String passageId) {
    _passages
        .query(LocalPassageEntity_.passageId.equals(passageId))
        .build()
        .remove();
    _segments
        .query(LocalSegmentEntity_.passageId.equals(passageId))
        .build()
        .remove();
    _segmentProgress
        .query(LocalSegmentProgressEntity_.passageId.equals(passageId))
        .build()
        .remove();
  }

  /// Returns cached passage by server ID, or null if not cached.
  LocalPassageEntity? getPassageById(String passageId) {
    return _passages
        .query(LocalPassageEntity_.passageId.equals(passageId))
        .build()
        .findFirst();
  }

  /// Upserts a batch of segments for a passage (replacing all prior entries
  /// with the same [segmentId]).
  void upsertSegments(List<LocalSegmentEntity> entities) {
    _segments.putMany(entities);
  }

  /// Returns all segments for [passageId], ordered by [position].
  List<LocalSegmentEntity> getSegmentsByPassage(String passageId) {
    return _segments
        .query(LocalSegmentEntity_.passageId.equals(passageId))
        .order(LocalSegmentEntity_.position)
        .build()
        .find();
  }

  /// Returns true if any segments are cached for [passageId].
  bool hasSegments(String passageId) {
    return _segments
            .query(LocalSegmentEntity_.passageId.equals(passageId))
            .build()
            .count() >
        0;
  } // ---------------------------------------------------------------------------
  // Memorization segment progress — drill state
  // ---------------------------------------------------------------------------

  /// Returns the progress for [segmentId], or null if not yet studied.
  LocalSegmentProgressEntity? getSegmentProgress(String segmentId) {
    return _segmentProgress
        .query(LocalSegmentProgressEntity_.segmentId.equals(segmentId))
        .build()
        .findFirst();
  }

  /// Returns all progress records for [passageId].
  List<LocalSegmentProgressEntity> getPassageProgressLocal(String passageId) {
    return _segmentProgress
        .query(LocalSegmentProgressEntity_.passageId.equals(passageId))
        .build()
        .find();
  }

  /// Creates or updates a progress record.
  void upsertSegmentProgress(LocalSegmentProgressEntity entity) {
    _segmentProgress.put(entity);
  }

  /// Returns all progress records with [isDirty] == 1 (need backend sync).
  List<LocalSegmentProgressEntity> getDirtySegmentProgress() {
    return _segmentProgress
        .query(LocalSegmentProgressEntity_.isDirty.equals(1))
        .build()
        .find();
  }

  /// Marks a progress record as synced (isDirty = 0).
  void markSegmentProgressSynced(String segmentId) {
    final entity = getSegmentProgress(segmentId);
    if (entity != null) {
      entity.isDirty = 0;
      _segmentProgress.put(entity);
    }
  }

  /// Bulk-replaces progress records received from the backend (marks isDirty=0).
  void importBackendSegmentProgress(List<LocalSegmentProgressEntity> entities) {
    for (final e in entities) {
      e.isDirty = 0;
    }
    _segmentProgress.putMany(entities);
  }
}

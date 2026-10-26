part of 'local_database.dart';

/// Shadowing videos, segments and progress.
extension LocalDatabaseShadowing on LocalDatabase {
  // ---------------------------------------------------------------------------
  // Shadowing video cache
  // ---------------------------------------------------------------------------

  void upsertShadowingVideo(ShadowingVideoEntity entity) {
    _shadowingVideos.put(entity);
  }

  void upsertShadowingVideos(List<ShadowingVideoEntity> entities) {
    _shadowingVideos.putMany(entities);
  }

  List<ShadowingVideoEntity> getShadowingVideos() {
    return _shadowingVideos
        .query()
        .order(ShadowingVideoEntity_.updatedAtMs, flags: Order.descending)
        .build()
        .find();
  }

  ShadowingVideoEntity? getShadowingVideo(String entryId) {
    return _shadowingVideos
        .query(ShadowingVideoEntity_.entryId.equals(entryId))
        .build()
        .findFirst();
  }

  void replaceShadowingSegments(
    String entryId,
    List<ShadowingSegmentEntity> entities,
  ) {
    final existing = _shadowingSegments
        .query(ShadowingSegmentEntity_.entryId.equals(entryId))
        .build()
        .find();
    if (existing.isNotEmpty) {
      _shadowingSegments.removeMany(existing.map((item) => item.id).toList());
    }
    if (entities.isNotEmpty) {
      _shadowingSegments.putMany(entities);
    }
  }

  List<ShadowingSegmentEntity> getShadowingSegments(String entryId) {
    return _shadowingSegments
        .query(ShadowingSegmentEntity_.entryId.equals(entryId))
        .order(ShadowingSegmentEntity_.position)
        .build()
        .find();
  }

  void upsertShadowingProgress(ShadowingProgressEntity entity) {
    _shadowingProgress.put(entity);
  }

  ShadowingProgressEntity? getShadowingProgress(String entryId) {
    return _shadowingProgress
        .query(ShadowingProgressEntity_.entryId.equals(entryId))
        .build()
        .findFirst();
  }
}

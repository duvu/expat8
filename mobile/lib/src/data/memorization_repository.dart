import '../api/backend_api_client.dart';
import '../models/memorization_passage.dart';
import 'local_database.dart';
import 'local_database_entities.dart';

/// Repository for memorization passages.
///
/// Implements an offline-first strategy:
/// - [listPassagesCached] returns locally cached passages immediately.
/// - [syncPassageMetadata] fetches fresh data from the backend and updates the
///   local cache (metadata only — no segments).
/// - [getPassage] checks local segment cache first; fetches from backend when
///   missing and writes segments to cache for offline access.
/// Data plus whether it came from the local cache because the backend was
/// unreachable.
class CachedResult<T> {
  const CachedResult(this.data, {required this.fromCache});

  final T data;
  final bool fromCache;
}

class MemorizationRepository {
  MemorizationRepository({required this.apiClient, LocalDatabase? localDb})
      : localDb = localDb;

  final BackendApiClient apiClient;
  final LocalDatabase? localDb;

  // ---------------------------------------------------------------------------
  // Passage metadata
  // ---------------------------------------------------------------------------

  /// Returns all cached passages (instant, no network).
  List<MemorizationPassage> listPassagesCached() {
    return localDb!
        .getAllPassages()
        .map(_passageEntityToModel)
        .toList();
  }

  /// Fetches passage list from backend, upserts into local cache, returns
  /// updated list.
  Future<List<MemorizationPassage>> syncPassageMetadata({
    required String sessionToken,
  }) async {
    final passages = await apiClient.listPassages(sessionToken: sessionToken);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in passages) {
      localDb!.upsertPassage(LocalPassageEntity(
        passageId: p.id,
        title: p.title,
        language: p.language,
        status: p.status,
        visibility: p.visibility,
        segmentCount: p.segmentCount,
        createdAt: p.createdAt,
        enrichmentStatus: p.enrichmentStatus,
        ownerUserId: p.ownerUserId,
        syncedAtMs: now,
      ));
    }
    return passages;
  }

  /// Fetches passage list from backend (legacy — always network).
  Future<List<MemorizationPassage>> listPassages({
    required String sessionToken,
  }) =>
      apiClient.listPassages(sessionToken: sessionToken);

  /// Offline-first list: refreshes from the backend when reachable (dropping
  /// passages deleted on the server), otherwise returns the cached list.
  Future<CachedResult<List<MemorizationPassage>>> loadPassages({
    required String sessionToken,
  }) async {
    try {
      final passages = await syncPassageMetadata(sessionToken: sessionToken);
      final live = passages.map((p) => p.id).toSet();
      for (final cached in localDb!.getAllPassages()) {
        if (!live.contains(cached.passageId)) {
          localDb!.removePassageLocal(cached.passageId);
        }
      }
      return CachedResult(passages, fromCache: false);
    } on Object {
      return CachedResult(listPassagesCached(), fromCache: true);
    }
  }

  /// Offline-first progress: merges server progress into the local store
  /// (never overwriting unsynced local drill results) and falls back to local
  /// progress when offline.
  Future<List<MemorizationSegmentProgress>> loadPassageProgress({
    required String sessionToken,
    required String passageId,
  }) async {
    try {
      final remote = await apiClient.getPassageProgress(
        sessionToken: sessionToken,
        passageId: passageId,
      );
      final imported = <LocalSegmentProgressEntity>[];
      for (final r in remote) {
        final local = localDb!.getSegmentProgress(r.segmentId);
        if (local != null && local.isDirty == 1) continue;
        imported.add(LocalSegmentProgressEntity(
          id: local?.id ?? 0,
          segmentId: r.segmentId,
          passageId: passageId,
          status: r.status,
          reviewCount: r.reviewCount,
          easeFactor: local?.easeFactor ?? 2.5,
          intervalDays: local?.intervalDays ?? 0,
          lastReviewedAtMs: r.lastReviewedAt == null
              ? local?.lastReviewedAtMs
              : DateTime.tryParse(r.lastReviewedAt!)?.millisecondsSinceEpoch,
          nextReviewAtMs: local?.nextReviewAtMs,
          isDirty: 0,
        ));
      }
      localDb!.importBackendSegmentProgress(imported);
    } on Object {
      // Offline: use what is stored locally.
    }
    return localDb!
        .getPassageProgressLocal(passageId)
        .map((e) => MemorizationSegmentProgress(
              segmentId: e.segmentId,
              status: e.status,
              reviewCount: e.reviewCount,
              lastReviewedAt: e.lastReviewedAtMs == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(e.lastReviewedAtMs!,
                          isUtc: true)
                      .toIso8601String(),
            ))
        .toList();
  }

  Future<MemorizationPassage> createPassage({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
  }) =>
      apiClient.createPassage(
        sessionToken: sessionToken,
        title: title,
        language: language,
        rawText: rawText,
      );

  // ---------------------------------------------------------------------------
  // Passage detail (with segments)
  // ---------------------------------------------------------------------------

  /// Returns full passage with segments.
  ///
  /// If the passage has segments in the local cache, assembles from cache.
  /// Otherwise fetches from backend and caches the result.
  Future<MemorizationPassage> getPassage({
    required String sessionToken,
    required String passageId,
  }) async {
    if (localDb!.hasSegments(passageId)) {
      final cached = localDb!.getPassageById(passageId);
      if (cached != null) {
        final segments = localDb!
            .getSegmentsByPassage(passageId)
            .map(_segmentEntityToModel)
            .toList();
        return _passageEntityToModel(cached, segments: segments);
      }
    }
    final passage = await apiClient.getPassage(
      sessionToken: sessionToken,
      passageId: passageId,
    );
    _cachePassageWithSegments(passage);
    return passage;
  }

  /// Forces a network fetch for [passageId], refreshing the cache.
  Future<MemorizationPassage> refreshPassage({
    required String sessionToken,
    required String passageId,
  }) async {
    final passage = await apiClient.getPassage(
      sessionToken: sessionToken,
      passageId: passageId,
    );
    _cachePassageWithSegments(passage);
    return passage;
  }

  void _cachePassageWithSegments(MemorizationPassage passage) {
    final now = DateTime.now().millisecondsSinceEpoch;
    localDb!.upsertPassage(LocalPassageEntity(
      passageId: passage.id,
      title: passage.title,
      language: passage.language,
      status: passage.status,
      visibility: passage.visibility,
      segmentCount: passage.segmentCount,
      createdAt: passage.createdAt,
      enrichmentStatus: passage.enrichmentStatus,
      ownerUserId: passage.ownerUserId,
      syncedAtMs: now,
    ));
    final segs = passage.segments ?? [];
    if (segs.isNotEmpty) {
      localDb!.upsertSegments(segs.map((s) {
        return LocalSegmentEntity(
          segmentId: s.id,
          passageId: passage.id,
          position: s.position,
          text: s.text,
          wordCount: s.wordCount,
          ipaText: s.ipaText,
          translationText: s.translationText,
          translationLanguage: s.translationLanguage,
          vietReadingText: s.vietReadingText,
          syncedAtMs: now,
        );
      }).toList());
    }
  }

  Future<void> deletePassage({
    required String sessionToken,
    required String passageId,
  }) async {
    await apiClient.deletePassage(
      sessionToken: sessionToken,
      passageId: passageId,
    );
    localDb!.removePassageLocal(passageId);
  }

  // ---------------------------------------------------------------------------
  // Segment progress
  // ---------------------------------------------------------------------------

  Future<List<MemorizationSegmentProgress>> getPassageProgress({
    required String sessionToken,
    required String passageId,
  }) =>
      apiClient.getPassageProgress(
        sessionToken: sessionToken,
        passageId: passageId,
      );

  Future<void> upsertSegmentProgress({
    required String sessionToken,
    required List<Map<String, dynamic>> progressUpdates,
  }) =>
      apiClient.upsertSegmentProgress(
        sessionToken: sessionToken,
        progressUpdates: progressUpdates,
      );

  // ---------------------------------------------------------------------------
  // Local segment progress (drill state)
  // ---------------------------------------------------------------------------

  /// Returns local progress for [segmentId], or null.
  LocalSegmentProgressEntity? getSegmentProgressLocal(String segmentId) =>
      localDb!.getSegmentProgress(segmentId);

  /// Returns all local progress for [passageId].
  List<LocalSegmentProgressEntity> getPassageProgressLocalAll(
          String passageId) =>
      localDb!.getPassageProgressLocal(passageId);

  /// Saves drill progress locally (marks isDirty for later sync).
  void saveSegmentProgressLocal(LocalSegmentProgressEntity entity) =>
      localDb!.upsertSegmentProgress(entity);

  /// Syncs dirty local progress to backend and marks records clean.
  Future<void> syncDirtyProgress({required String sessionToken}) async {
    final dirty = localDb!.getDirtySegmentProgress();
    if (dirty.isEmpty) return;
    final updates = dirty
        .map((e) => {
              'segment_id': e.segmentId,
              'status': e.status,
              'review_count': e.reviewCount,
              'ease_factor': e.easeFactor,
              'interval_days': e.intervalDays,
              if (e.lastReviewedAtMs != null)
                'last_reviewed_at': DateTime.fromMillisecondsSinceEpoch(
                        e.lastReviewedAtMs!, isUtc: true)
                    .toIso8601String(),
              if (e.nextReviewAtMs != null)
                'next_review_at': DateTime.fromMillisecondsSinceEpoch(
                        e.nextReviewAtMs!, isUtc: true)
                    .toIso8601String(),
            })
        .toList();
    await apiClient.upsertSegmentProgress(
        sessionToken: sessionToken, progressUpdates: updates);
    for (final e in dirty) {
      localDb!.markSegmentProgressSynced(e.segmentId);
    }
  }

  // ---------------------------------------------------------------------------
  // Converters
  // ---------------------------------------------------------------------------

  static MemorizationPassage _passageEntityToModel(
    LocalPassageEntity e, {
    List<MemorizationSegment>? segments,
  }) {
    return MemorizationPassage(
      id: e.passageId,
      title: e.title,
      language: e.language,
      status: e.status,
      visibility: e.visibility,
      segmentCount: e.segmentCount,
      createdAt: e.createdAt,
      enrichmentStatus: e.enrichmentStatus,
      ownerUserId: e.ownerUserId,
      segments: segments,
    );
  }

  static MemorizationSegment _segmentEntityToModel(LocalSegmentEntity e) {
    return MemorizationSegment(
      id: e.segmentId,
      position: e.position,
      text: e.text,
      wordCount: e.wordCount,
      ipaText: e.ipaText,
      translationText: e.translationText,
      translationLanguage: e.translationLanguage,
      vietReadingText: e.vietReadingText,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../models/shadowing_video.dart';
import 'local_database.dart';
import 'local_database_entities.dart';

class ShadowingRepository {
  ShadowingRepository({
    required BackendApiClient apiClient,
    required LocalDatabase database,
    Uuid? uuid,
  })  : apiClient = apiClient,
        database = database,
        _uuid = uuid ?? const Uuid();

  /// Test-only constructor. Leaves [apiClient] and [database] uninitialized.
  /// Subclasses must override all methods that access them.
  @visibleForTesting
  ShadowingRepository.forTest() : _uuid = const Uuid();

  late final BackendApiClient apiClient;
  late final LocalDatabase database;
  final Uuid _uuid;

  List<ShadowingVideo> listCachedVideos() {
    final items = database
        .getShadowingVideos()
        .map(_videoFromEntity)
        .toList(growable: false);
    items.sort(_compareVideos);
    return items;
  }

  ShadowingVideo? getCachedVideo(String entryId) {
    final entity = database.getShadowingVideo(entryId);
    if (entity == null) {
      return null;
    }
    return _videoFromEntity(entity,
        segments: database
            .getShadowingSegments(entryId)
            .map(_segmentFromEntity)
            .toList(growable: false));
  }

  Future<List<ShadowingVideo>> refreshLibrary({int limit = 50}) async {
    final deviceId = await _getOrCreateDeviceId();
    final sessionToken = await _loadSessionToken();
    final items = await apiClient.fetchShadowingVideos(
      deviceId: deviceId,
      limit: limit,
      sessionToken: sessionToken,
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    database.upsertShadowingVideos(
      items.map((item) => _entityFromVideo(item, cachedAtMs: now)).toList(),
    );
    return listCachedVideos();
  }

  Future<ShadowingVideo> importVideo({required String sourceUrl}) async {
    final deviceId = await _getOrCreateDeviceId();
    final sessionToken = await _loadSessionToken();
    final video = await apiClient.importShadowingVideo(
      deviceId: deviceId,
      sourceUrl: sourceUrl,
      sessionToken: sessionToken,
    );
    database.upsertShadowingVideo(
      _entityFromVideo(
        video,
        cachedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
    return video;
  }

  Future<ShadowingVideo> getVideoDetail({required String entryId}) async {
    final cached = getCachedVideo(entryId);
    if (cached != null && cached.hasSegments) {
      return cached;
    }
    return refreshVideoDetail(entryId: entryId);
  }

  Future<ShadowingVideo> refreshVideoDetail({required String entryId}) async {
    final deviceId = await _getOrCreateDeviceId();
    final sessionToken = await _loadSessionToken();
    final video = await apiClient.fetchShadowingVideoDetail(
      entryId: entryId,
      deviceId: deviceId,
      sessionToken: sessionToken,
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    database.upsertShadowingVideo(_entityFromVideo(video, cachedAtMs: now));
    database.replaceShadowingSegments(
      entryId,
      video.segments
          .map((segment) => _segmentEntityFromModel(segment, entryId: entryId))
          .toList(growable: false),
    );
    return getCachedVideo(entryId) ?? video;
  }

  ShadowingVideoProgress loadProgress(ShadowingVideo video) {
    final existing = database.getShadowingProgress(video.id);
    if (existing == null) {
      return ShadowingVideoProgress(
        entryId: video.id,
        lastPositionMs: 0,
        playbackRate: video.playbackDefaults.initialPlaybackRate,
      );
    }
    return ShadowingVideoProgress(
      entryId: existing.entryId,
      lastPositionMs: existing.lastPositionMs,
      playbackRate: existing.playbackRate,
      lastOpenedAt: existing.lastOpenedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(existing.lastOpenedAtMs!,
              isUtc: true),
    );
  }

  Future<void> saveProgress({
    required String entryId,
    required int lastPositionMs,
    required double playbackRate,
  }) async {
    database.upsertShadowingProgress(
      ShadowingProgressEntity(
        entryId: entryId,
        lastPositionMs: lastPositionMs,
        playbackRate: playbackRate,
        lastOpenedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  Future<String> _getOrCreateDeviceId() {
    return database.getOrCreateDeviceId(_uuid.v4);
  }

  Future<String?> _loadSessionToken() async {
    return (await database.loadUserSession())?.sessionToken;
  }

  static int _compareVideos(ShadowingVideo left, ShadowingVideo right) {
    if (left.entryType != right.entryType) {
      if (left.isCurated) {
        return -1;
      }
      if (right.isCurated) {
        return 1;
      }
    }
    final updatedAtCompare = right.updatedAt.compareTo(left.updatedAt);
    if (updatedAtCompare != 0) {
      return updatedAtCompare;
    }
    return left.title.compareTo(right.title);
  }

  static ShadowingVideo _videoFromEntity(
    ShadowingVideoEntity entity, {
    List<ShadowingTranscriptSegment>? segments,
  }) {
    final sortedSegments = List<ShadowingTranscriptSegment>.of(
        segments ?? const <ShadowingTranscriptSegment>[])
      ..sort((left, right) => left.position.compareTo(right.position));
    return ShadowingVideo(
      id: entity.entryId,
      entryType: entity.entryType,
      visibility: entity.visibility,
      sourceType: entity.sourceType,
      providerVideoId: entity.providerVideoId,
      sourceUrl: entity.sourceUrl,
      title: entity.title,
      channelTitle: entity.channelTitle,
      thumbnailUrl: entity.thumbnailUrl,
      durationSeconds: entity.durationSeconds,
      transcriptLanguage: entity.transcriptLanguage,
      transcriptSource: entity.transcriptSource,
      segmentCount: entity.segmentCount,
      playbackDefaults: ShadowingPlaybackDefaults(
        initialPlaybackRate: entity.initialPlaybackRate,
        seekBackMs: entity.seekBackMs,
      ),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(entity.createdAtMs, isUtc: true),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(entity.updatedAtMs, isUtc: true),
      segments: sortedSegments,
    );
  }

  static ShadowingVideoEntity _entityFromVideo(
    ShadowingVideo video, {
    required int cachedAtMs,
  }) {
    return ShadowingVideoEntity(
      entryId: video.id,
      entryType: video.entryType,
      visibility: video.visibility,
      sourceType: video.sourceType,
      providerVideoId: video.providerVideoId,
      sourceUrl: video.sourceUrl,
      title: video.title,
      channelTitle: video.channelTitle,
      thumbnailUrl: video.thumbnailUrl,
      durationSeconds: video.durationSeconds,
      transcriptLanguage: video.transcriptLanguage,
      transcriptSource: video.transcriptSource,
      segmentCount: video.segmentCount,
      initialPlaybackRate: video.playbackDefaults.initialPlaybackRate,
      seekBackMs: video.playbackDefaults.seekBackMs,
      createdAtMs: video.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtMs: video.updatedAt.toUtc().millisecondsSinceEpoch,
      cachedAtMs: cachedAtMs,
    );
  }

  static ShadowingTranscriptSegment _segmentFromEntity(
    ShadowingSegmentEntity entity,
  ) {
    return ShadowingTranscriptSegment(
      id: entity.segmentId,
      position: entity.position,
      startMs: entity.startMs,
      endMs: entity.endMs,
      text: entity.text,
    );
  }

  static ShadowingSegmentEntity _segmentEntityFromModel(
    ShadowingTranscriptSegment segment, {
    required String entryId,
  }) {
    return ShadowingSegmentEntity(
      segmentId: segment.id,
      entryId: entryId,
      position: segment.position,
      startMs: segment.startMs,
      endMs: segment.endMs,
      text: segment.text,
    );
  }
}

class ShadowingPlaybackDefaults {
  const ShadowingPlaybackDefaults({
    required this.initialPlaybackRate,
    required this.seekBackMs,
  });

  factory ShadowingPlaybackDefaults.fromJson(Map<String, dynamic> json) {
    return ShadowingPlaybackDefaults(
      initialPlaybackRate:
          (json['initial_playback_rate'] as num?)?.toDouble() ?? 1.0,
      seekBackMs: json['seek_back_ms'] as int? ?? 5000,
    );
  }

  final double initialPlaybackRate;
  final int seekBackMs;
}

class ShadowingTranscriptSegment {
  const ShadowingTranscriptSegment({
    required this.id,
    required this.position,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  factory ShadowingTranscriptSegment.fromJson(Map<String, dynamic> json) {
    return ShadowingTranscriptSegment(
      id: json['id'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      startMs: json['start_ms'] as int? ?? 0,
      endMs: json['end_ms'] as int? ?? 0,
      text: json['text'] as String? ?? '',
    );
  }

  final String id;
  final int position;
  final int startMs;
  final int endMs;
  final String text;
}

class ShadowingVideo {
  const ShadowingVideo({
    required this.id,
    required this.entryType,
    required this.visibility,
    required this.sourceType,
    required this.providerVideoId,
    required this.sourceUrl,
    required this.title,
    this.channelTitle,
    this.thumbnailUrl,
    this.durationSeconds,
    this.transcriptLanguage,
    this.transcriptSource,
    required this.segmentCount,
    required this.playbackDefaults,
    required this.createdAt,
    required this.updatedAt,
    this.segments = const [],
  });

  factory ShadowingVideo.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'] as List? ?? const [];
    final segments = rawSegments
        .whereType<Map<String, dynamic>>()
        .map(ShadowingTranscriptSegment.fromJson)
        .toList(growable: false)
      ..sort((left, right) => left.position.compareTo(right.position));
    return ShadowingVideo(
      id: json['id'] as String? ?? '',
      entryType: json['entry_type'] as String? ?? 'saved',
      visibility: json['visibility'] as String? ?? 'private',
      sourceType: json['source_type'] as String? ?? 'youtube',
      providerVideoId: json['provider_video_id'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      channelTitle: json['channel_title'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      transcriptLanguage: json['transcript_language'] as String?,
      transcriptSource: json['transcript_source'] as String?,
      segmentCount: json['segment_count'] as int? ?? segments.length,
      playbackDefaults: ShadowingPlaybackDefaults.fromJson(
        json['playback_defaults'] is Map<String, dynamic>
            ? json['playback_defaults'] as Map<String, dynamic>
            : const {},
      ),
      createdAt: _parseShadowingDate(json['created_at']),
      updatedAt: _parseShadowingDate(json['updated_at']),
      segments: segments,
    );
  }

  final String id;
  final String entryType;
  final String visibility;
  final String sourceType;
  final String providerVideoId;
  final String sourceUrl;
  final String title;
  final String? channelTitle;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? transcriptLanguage;
  final String? transcriptSource;
  final int segmentCount;
  final ShadowingPlaybackDefaults playbackDefaults;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShadowingTranscriptSegment> segments;

  bool get isCurated => entryType == 'curated';
  bool get hasSegments => segments.isNotEmpty;

  ShadowingVideo copyWith({
    String? id,
    String? entryType,
    String? visibility,
    String? sourceType,
    String? providerVideoId,
    String? sourceUrl,
    String? title,
    String? channelTitle,
    String? thumbnailUrl,
    int? durationSeconds,
    String? transcriptLanguage,
    String? transcriptSource,
    int? segmentCount,
    ShadowingPlaybackDefaults? playbackDefaults,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ShadowingTranscriptSegment>? segments,
    bool clearChannelTitle = false,
    bool clearThumbnailUrl = false,
    bool clearDurationSeconds = false,
    bool clearTranscriptLanguage = false,
    bool clearTranscriptSource = false,
  }) {
    return ShadowingVideo(
      id: id ?? this.id,
      entryType: entryType ?? this.entryType,
      visibility: visibility ?? this.visibility,
      sourceType: sourceType ?? this.sourceType,
      providerVideoId: providerVideoId ?? this.providerVideoId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      title: title ?? this.title,
      channelTitle:
          clearChannelTitle ? null : channelTitle ?? this.channelTitle,
      thumbnailUrl:
          clearThumbnailUrl ? null : thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: clearDurationSeconds
          ? null
          : durationSeconds ?? this.durationSeconds,
      transcriptLanguage: clearTranscriptLanguage
          ? null
          : transcriptLanguage ?? this.transcriptLanguage,
      transcriptSource: clearTranscriptSource
          ? null
          : transcriptSource ?? this.transcriptSource,
      segmentCount: segmentCount ?? this.segmentCount,
      playbackDefaults: playbackDefaults ?? this.playbackDefaults,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      segments: segments ?? this.segments,
    );
  }
}

class ShadowingVideoProgress {
  const ShadowingVideoProgress({
    required this.entryId,
    required this.lastPositionMs,
    required this.playbackRate,
    this.lastOpenedAt,
  });

  final String entryId;
  final int lastPositionMs;
  final double playbackRate;
  final DateTime? lastOpenedAt;

  ShadowingVideoProgress copyWith({
    String? entryId,
    int? lastPositionMs,
    double? playbackRate,
    DateTime? lastOpenedAt,
    bool clearLastOpenedAt = false,
  }) {
    return ShadowingVideoProgress(
      entryId: entryId ?? this.entryId,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      playbackRate: playbackRate ?? this.playbackRate,
      lastOpenedAt:
          clearLastOpenedAt ? null : lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}

DateTime _parseShadowingDate(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toUtc() ??
      DateTime.now().toUtc();
}

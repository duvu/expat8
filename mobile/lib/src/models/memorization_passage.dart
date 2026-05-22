class MemorizationPassage {
  const MemorizationPassage({
    required this.id,
    required this.title,
    required this.language,
    required this.status,
    required this.visibility,
    required this.segmentCount,
    required this.createdAt,
    this.enrichmentStatus,
    this.ownerUserId,
    this.rawText,
    this.segments,
  });

  factory MemorizationPassage.fromJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List<dynamic>?;
    return MemorizationPassage(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      status: json['status'] as String? ?? 'pending',
      visibility: json['visibility'] as String? ?? 'private',
      segmentCount: (json['segment_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      enrichmentStatus: json['enrichment_status'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      rawText: json['raw_text'] as String?,
      segments: segmentsList
          ?.map((s) =>
              MemorizationSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String title;
  final String language;
  final String status;
  final String visibility;
  final int segmentCount;
  final String createdAt;
  final String? enrichmentStatus;
  final String? ownerUserId;
  final String? rawText;
  final List<MemorizationSegment>? segments;
}

class MemorizationSegment {
  const MemorizationSegment({
    required this.id,
    required this.position,
    required this.text,
    required this.wordCount,
    this.ipaText,
    this.translationText,
    this.translationLanguage,
    this.vietReadingText,
  });

  factory MemorizationSegment.fromJson(Map<String, dynamic> json) {
    return MemorizationSegment(
      id: json['id'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      ipaText: json['ipa_text'] as String?,
      translationText: json['translation_text'] as String?,
      translationLanguage: json['translation_language'] as String?,
      vietReadingText: json['viet_reading_text'] as String?,
    );
  }

  final String id;
  final int position;
  final String text;
  final int wordCount;
  final String? ipaText;
  final String? translationText;
  final String? translationLanguage;
  final String? vietReadingText;
}

class MemorizationSegmentProgress {
  const MemorizationSegmentProgress({
    required this.segmentId,
    required this.status,
    required this.reviewCount,
    this.lastReviewedAt,
  });

  factory MemorizationSegmentProgress.fromJson(Map<String, dynamic> json) {
    return MemorizationSegmentProgress(
      segmentId: json['segment_id'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      lastReviewedAt: json['last_reviewed_at'] as String?,
    );
  }

  final String segmentId;
  final String status;
  final int reviewCount;
  final String? lastReviewedAt;
}

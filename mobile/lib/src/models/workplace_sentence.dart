enum WorkplaceSentenceStatus { unseen, seen }

class WorkplaceSentence {
  const WorkplaceSentence({
    required this.localId,
    this.serverSentenceId,
    required this.text,
    required this.language,
    required this.meaningVi,
    this.topic,
    this.sourceTitle,
    required this.generationSource,
    required this.isBundled,
    required this.status,
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkplaceSentence.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return WorkplaceSentence(
      localId: (json['local_id'] ?? json['sentence_id'] ?? json['text']) as String,
      serverSentenceId: json['sentence_id'] as String?,
      text: json['text'] as String,
      language: json['language'] as String,
      meaningVi: json['meaning_vi'] as String,
      topic: json['topic'] as String?,
      sourceTitle: json['source_title'] as String?,
      generationSource:
          json['generation_source'] as String? ?? 'article_workplace_sentence',
      isBundled: json['is_bundled'] as bool? ?? false,
      status: _statusFromJson(json['status'] as String?),
      lastSeenAt: _parseDate(json['last_seen_at'] as String?),
      createdAt: _parseDate(json['created_at'] as String?) ?? now,
      updatedAt: _parseDate(json['updated_at'] as String?) ?? now,
    );
  }

  final String localId;
  final String? serverSentenceId;
  final String text;
  final String language;
  final String meaningVi;
  final String? topic;
  final String? sourceTitle;
  final String generationSource;
  final bool isBundled;
  final WorkplaceSentenceStatus status;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkplaceSentence copyWith({
    String? localId,
    String? serverSentenceId,
    String? text,
    String? language,
    String? meaningVi,
    String? topic,
    String? sourceTitle,
    String? generationSource,
    bool? isBundled,
    WorkplaceSentenceStatus? status,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkplaceSentence(
      localId: localId ?? this.localId,
      serverSentenceId: serverSentenceId ?? this.serverSentenceId,
      text: text ?? this.text,
      language: language ?? this.language,
      meaningVi: meaningVi ?? this.meaningVi,
      topic: topic ?? this.topic,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      generationSource: generationSource ?? this.generationSource,
      isBundled: isBundled ?? this.isBundled,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

WorkplaceSentenceStatus _statusFromJson(String? raw) {
  return raw == WorkplaceSentenceStatus.seen.name
      ? WorkplaceSentenceStatus.seen
      : WorkplaceSentenceStatus.unseen;
}

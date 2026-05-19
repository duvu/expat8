/// Lightweight summary returned by `GET /v1/content-packs`.
class ContentPackSummary {
  const ContentPackSummary({
    required this.id,
    required this.language,
    required this.version,
    required this.status,
    required this.createdAt,
    this.publishedAt,
  });

  factory ContentPackSummary.fromJson(Map<String, dynamic> json) {
    return ContentPackSummary(
      id: json['id'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      version: (json['version'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      publishedAt: json['published_at'] as String?,
    );
  }

  final String id;
  final String language;
  final int version;
  final String status;
  final String createdAt;
  final String? publishedAt;
}

/// A single vocabulary entry inside a content pack.
class ContentPackItem {
  const ContentPackItem({
    required this.id,
    required this.wordSenseId,
    required this.createdAt,
  });

  factory ContentPackItem.fromJson(Map<String, dynamic> json) {
    return ContentPackItem(
      id: json['id'] as String? ?? '',
      wordSenseId: json['word_sense_id'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final String id;
  final String wordSenseId;
  final String createdAt;
}

/// Full content pack returned by `GET /v1/content-packs/:id`.
class ContentPack extends ContentPackSummary {
  const ContentPack({
    required super.id,
    required super.language,
    required super.version,
    required super.status,
    required super.createdAt,
    super.publishedAt,
    required this.items,
  });

  factory ContentPack.fromJson(Map<String, dynamic> json) {
    final base = ContentPackSummary.fromJson(json);
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return ContentPack(
      id: base.id,
      language: base.language,
      version: base.version,
      status: base.status,
      createdAt: base.createdAt,
      publishedAt: base.publishedAt,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ContentPackItem.fromJson)
          .toList(growable: false),
    );
  }

  final List<ContentPackItem> items;
}

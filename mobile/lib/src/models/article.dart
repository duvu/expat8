DateTime _parseUtcDate(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
  }
  return DateTime.now().toUtc();
}

class ManagedArticle {
  const ManagedArticle({
    required this.id,
    required this.title,
    this.sourceUrl,
    required this.language,
    required this.visibility,
    required this.status,
    this.processingError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ManagedArticle.fromJson(Map<String, dynamic> json) {
    return ManagedArticle(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceUrl: json['source_url'] as String?,
      language: json['language'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'private',
      status: json['status'] as String? ?? 'pending_processing',
      processingError: json['processing_error'] as String?,
      createdAt: _parseUtcDate(json['created_at']),
      updatedAt: _parseUtcDate(json['updated_at']),
    );
  }

  final String id;
  final String title;
  final String? sourceUrl;
  final String language;
  final String visibility;
  final String status;
  final String? processingError;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ArticleVocabularyItem {
  const ArticleVocabularyItem({
    required this.termId,
    required this.displayTerm,
    this.wordSenseId,
    required this.meaningVi,
    this.partOfSpeech,
    this.ipa,
    this.level,
    required this.status,
    this.classification,
    this.suggestionType,
  });

  factory ArticleVocabularyItem.fromJson(Map<String, dynamic> json) {
    return ArticleVocabularyItem(
      termId: json['term_id'] as String? ?? '',
      displayTerm: json['display_term'] as String? ??
          json['term'] as String? ??
          '',
      wordSenseId: json['word_sense_id'] as String?,
      meaningVi: json['meaning_vi'] as String? ?? '',
      partOfSpeech: json['part_of_speech'] as String?,
      ipa: json['ipa'] as String?,
      level: json['level'] as String?,
      status: json['status'] as String? ?? 'pending_review',
      classification: json['classification'] as String?,
      suggestionType: json['suggestion_type'] as String?,
    );
  }

  final String termId;
  final String displayTerm;
  final String? wordSenseId;
  final String meaningVi;
  final String? partOfSpeech;
  final String? ipa;
  final String? level;
  final String status;
  final String? classification;
  final String? suggestionType;
}

class ArticleVocabularyResponse {
  const ArticleVocabularyResponse({
    required this.articleId,
    required this.items,
  });

  factory ArticleVocabularyResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return ArticleVocabularyResponse(
      articleId: json['article_id'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ArticleVocabularyItem.fromJson)
          .toList(growable: false),
    );
  }

  final String articleId;
  final List<ArticleVocabularyItem> items;
}

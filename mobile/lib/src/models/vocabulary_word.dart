enum WordStatus { newWord, learning, review, mastered }

class VocabularyWord {
  const VocabularyWord({
    required this.localId,
    this.serverWordId,
    required this.term,
    required this.language,
    required this.meaningVi,
    this.partOfSpeech,
    required this.ipa,
    required this.vietnamesePronunciation,
    required this.example,
    required this.exampleVi,
    required this.difficulty,
    required this.topics,
    required this.status,
    this.lastSeenAt,
    this.nextReviewAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return VocabularyWord(
      localId: (json['local_id'] ?? json['server_word_id'] ?? json['term']) as String,
      serverWordId: json['server_word_id'] as String?,
      term: json['term'] as String,
      language: json['language'] as String,
      meaningVi: json['meaning_vi'] as String,
      partOfSpeech: json['part_of_speech'] as String?,
      ipa: json['ipa'] as String,
      vietnamesePronunciation: json['vietnamese_pronunciation'] as String,
      example: json['example'] as String,
      exampleVi: json['example_vi'] as String,
      difficulty: json['difficulty'] as String,
      topics: List<String>.from(json['topics'] as List? ?? const []),
      status: WordStatus.newWord,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? now,
      updatedAt: now,
    );
  }

  final String localId;
  final String? serverWordId;
  final String term;
  final String language;
  final String meaningVi;
  final String? partOfSpeech;
  final String ipa;
  final String vietnamesePronunciation;
  final String example;
  final String exampleVi;
  final String difficulty;
  final List<String> topics;
  final WordStatus status;
  final DateTime? lastSeenAt;
  final DateTime? nextReviewAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VocabularyWord copyWith({
    String? localId,
    String? serverWordId,
    String? term,
    String? language,
    String? meaningVi,
    String? partOfSpeech,
    String? ipa,
    String? vietnamesePronunciation,
    String? example,
    String? exampleVi,
    String? difficulty,
    List<String>? topics,
    WordStatus? status,
    DateTime? lastSeenAt,
    DateTime? nextReviewAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VocabularyWord(
      localId: localId ?? this.localId,
      serverWordId: serverWordId ?? this.serverWordId,
      term: term ?? this.term,
      language: language ?? this.language,
      meaningVi: meaningVi ?? this.meaningVi,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      ipa: ipa ?? this.ipa,
      vietnamesePronunciation:
          vietnamesePronunciation ?? this.vietnamesePronunciation,
      example: example ?? this.example,
      exampleVi: exampleVi ?? this.exampleVi,
      difficulty: difficulty ?? this.difficulty,
      topics: topics ?? this.topics,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum WordStatus { newWord, learning, review, mastered }

enum LearningCardType { newCard, review }

/// A speaking prompt supplied by the backend for a vocabulary card.
/// All fields are optional — absence means no approved prompt exists and the
/// UI falls back to the card's [VocabularyWord.example] sentence.
class SpeakingPrompt {
  const SpeakingPrompt({
    required this.promptId,
    this.targetText,
    this.viHint,
    this.targetPhrase,
    this.pronunciationTip,
    this.commonMistake,
    this.difficulty,
    this.topic,
  });

  factory SpeakingPrompt.fromJson(Map<String, dynamic> json) {
    return SpeakingPrompt(
      promptId: json['prompt_id'] as String,
      targetText: json['target_text'] as String?,
      viHint: json['vi_hint'] as String?,
      targetPhrase: json['target_phrase'] as String?,
      pronunciationTip: json['pronunciation_tip'] as String?,
      commonMistake: json['common_mistake'] as String?,
      difficulty: json['difficulty'] as String?,
      topic: json['topic'] as String?,
    );
  }

  final String promptId;
  final String? targetText;
  final String? viHint;
  final String? targetPhrase;
  final String? pronunciationTip;
  final String? commonMistake;
  final String? difficulty;
  final String? topic;
}

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
    this.cardType,
    this.selectionReason,
    this.speakingPrompt,
    this.entryType = 'word',
    this.explanation = '',
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final spJson = json['speaking_prompt'] as Map<String, dynamic>?;
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
      status: _statusFromJsonCardType(json['card_type'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? now,
      updatedAt: now,
      cardType: _cardTypeFromJson(json['card_type'] as String?),
      selectionReason: json['selection_reason'] as String?,
      speakingPrompt: spJson != null ? SpeakingPrompt.fromJson(spJson) : null,
      entryType: json['entry_type'] as String? ?? 'word',
      explanation: json['explanation'] as String? ?? '',
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
  final LearningCardType? cardType;
  final String? selectionReason;

  /// Optional speaking prompt from the backend.
  /// Null when no approved prompt exists — UI falls back to [example].
  final SpeakingPrompt? speakingPrompt;

  /// Entry type: `'word'`, `'phrase'`, or `'idiom'`.
  final String entryType;

  /// Vietnamese usage note for phrase/idiom entries. Empty string for plain words.
  final String explanation;

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
    LearningCardType? cardType,
    String? selectionReason,
    SpeakingPrompt? speakingPrompt,
    String? entryType,
    String? explanation,
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
      cardType: cardType ?? this.cardType,
      selectionReason: selectionReason ?? this.selectionReason,
      speakingPrompt: speakingPrompt ?? this.speakingPrompt,
      entryType: entryType ?? this.entryType,
      explanation: explanation ?? this.explanation,
    );
  }
}

LearningCardType? _cardTypeFromJson(String? raw) {
  return switch (raw) {
    'new' => LearningCardType.newCard,
    'review' => LearningCardType.review,
    _ => null,
  };
}

WordStatus _statusFromJsonCardType(String? raw) {
  return raw == 'review' ? WordStatus.review : WordStatus.newWord;
}

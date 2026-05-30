/// Weekly speaking summary returned by `GET /v1/speaking/summary`.
class SpeakingWeeklySummary {
  const SpeakingWeeklySummary({
    required this.spokenSentenceCount,
    required this.retryCount,
    required this.approximateDurationMs,
    required this.selfRatingCounts,
    required this.loopCompletionCount,
    this.latestActivityAt,
  });

  factory SpeakingWeeklySummary.fromJson(Map<String, dynamic> json) {
    final raw = json['self_rating_counts'] as Map<String, dynamic>? ?? {};
    return SpeakingWeeklySummary(
      spokenSentenceCount: json['spoken_sentence_count'] as int? ?? 0,
      retryCount: json['retry_count'] as int? ?? 0,
      approximateDurationMs: json['approximate_duration_ms'] as int? ?? 0,
      loopCompletionCount: json['loop_completion_count'] as int? ?? 0,
      selfRatingCounts: raw.map((k, v) => MapEntry(k, (v as num).toInt())),
      latestActivityAt: json['latest_activity_at'] == null
          ? null
          : DateTime.tryParse(json['latest_activity_at'] as String),
    );
  }

  final int spokenSentenceCount;
  final int retryCount;
  final int approximateDurationMs;
  final int loopCompletionCount;
  final Map<String, int> selfRatingCounts;
  final DateTime? latestActivityAt;
}

/// A single speaking prompt item returned by `GET /v1/speaking/prompts`.
class SpeakingPromptItem {
  const SpeakingPromptItem({
    required this.id,
    this.wordSenseId,
    required this.targetText,
    this.viHint,
    this.pronunciationTip,
    this.commonMistake,
    this.difficulty,
    this.topic,
  });

  factory SpeakingPromptItem.fromJson(Map<String, dynamic> json) {
    return SpeakingPromptItem(
      id: json['id'] as String? ?? '',
      wordSenseId: json['word_sense_id'] as String?,
      targetText: json['target_text'] as String? ?? '',
      viHint: json['vi_hint'] as String?,
      pronunciationTip: json['pronunciation_tip_vi'] as String?,
      commonMistake: json['common_mistake_vi'] as String?,
      difficulty: json['difficulty'] as String?,
      topic: json['topic'] as String?,
    );
  }

  final String id;
  final String? wordSenseId;
  final String targetText;
  final String? viHint;
  final String? pronunciationTip;
  final String? commonMistake;
  final String? difficulty;
  final String? topic;
}

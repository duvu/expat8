class ProficiencyState {
  const ProficiencyState({
    required this.level,
    this.levelChanged = false,
    this.previousLevel,
    this.triggeredBy,
    this.consecutiveCount = 0,
    this.consecutiveRatingType,
    this.language = 'en',
    this.lastUpdated,
  });

  factory ProficiencyState.initial() {
    return const ProficiencyState(level: 'A1');
  }

  factory ProficiencyState.fromJson(Map<String, dynamic> json) {
    return ProficiencyState(
      level: (json['level'] ?? 'A1') as String,
      levelChanged: (json['level_changed'] ?? false) as bool,
      previousLevel: json['previous_level'] as String?,
      triggeredBy: json['triggered_by'] as String?,
      consecutiveCount: (json['consecutive_count'] ?? 0) as int,
      consecutiveRatingType: json['consecutive_rating_type'] as String?,
      language: (json['language'] ?? 'en') as String,
      lastUpdated: json['last_updated'] == null
          ? null
          : DateTime.tryParse(json['last_updated'] as String),
    );
  }

  final String level;
  final bool levelChanged;
  final String? previousLevel;
  final String? triggeredBy;
  final int consecutiveCount;
  final String? consecutiveRatingType;
  final String language;
  final DateTime? lastUpdated;
}
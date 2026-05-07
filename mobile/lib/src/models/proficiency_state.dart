class ProficiencyState {
  const ProficiencyState({
    required this.scale,
    required this.level,
    required this.levelIndex,
    this.levelChanged = false,
    this.previousLevel,
    this.triggeredBy,
    this.consecutiveCount = 0,
    this.consecutiveRatingType,
    this.language = 'en',
    this.lastUpdated,
  });

  factory ProficiencyState.initial() {
    return const ProficiencyState(scale: 'cefr', level: 'A1', levelIndex: 0);
  }

  factory ProficiencyState.fromJson(Map<String, dynamic> json) {
    final resolvedLevel = (json['level'] ?? 'A1') as String;
    final resolvedScale = (json['scale'] as String?) ?? _inferScaleFromLevel(resolvedLevel);
    return ProficiencyState(
      scale: resolvedScale,
      level: resolvedLevel,
      levelIndex: (json['level_index'] ?? 0) as int,
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

  final String scale;
  final String level;
  final int levelIndex;
  final bool levelChanged;
  final String? previousLevel;
  final String? triggeredBy;
  final int consecutiveCount;
  final String? consecutiveRatingType;
  final String language;
  final DateTime? lastUpdated;

  static String _inferScaleFromLevel(String level) {
    if (level.toUpperCase().startsWith('HSK')) {
      return 'hsk';
    }
    return 'cefr';
  }
}
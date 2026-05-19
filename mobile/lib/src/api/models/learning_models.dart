import '../../models/proficiency_state.dart';
import '../../models/vocabulary_word.dart';

class SyncResult {
  const SyncResult({
    required this.acceptedEventIds,
    required this.rejectedEvents,
    this.proficiency,
  });

  final List<String> acceptedEventIds;
  final List<Map<String, dynamic>> rejectedEvents;
  final ProficiencyState? proficiency;
}

class StudyEventResult {
  const StudyEventResult({
    required this.success,
    required this.eventId,
    required this.idempotent,
    required this.proficiency,
  });

  final bool success;
  final String? eventId;
  final bool idempotent;
  final ProficiencyState proficiency;
}

class LearningCardBatch {
  const LearningCardBatch({
    required this.items,
    required this.targetMix,
    required this.actualMix,
  });

  final List<VocabularyWord> items;
  final LearningCardMix targetMix;
  final LearningCardMix actualMix;
}

class LearningCardMix {
  const LearningCardMix({
    required this.newCount,
    required this.reviewCount,
  });

  factory LearningCardMix.fromJson(Map<String, dynamic> json) {
    return LearningCardMix(
      newCount: json['new'] as int? ?? 0,
      reviewCount: json['review'] as int? ?? 0,
    );
  }

  final int newCount;
  final int reviewCount;
}

class CacheInventoryResult {
  const CacheInventoryResult({
    required this.storedCount,
    required this.unknownServerWordIds,
  });

  final int storedCount;
  final List<String> unknownServerWordIds;
}

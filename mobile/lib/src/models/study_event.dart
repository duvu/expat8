enum StudyRating { notRemembered, hard, remembered, tooEasy }

enum SyncStatus { pending, synced, failed }

class StudyEvent {
  const StudyEvent({
    required this.clientEventId,
    required this.localWordId,
    this.serverWordId,
    required this.rating,
    required this.occurredAt,
    required this.syncStatus,
  });

  final String clientEventId;
  final String localWordId;
  final String? serverWordId;
  final StudyRating rating;
  final DateTime occurredAt;
  final SyncStatus syncStatus;

  Map<String, dynamic> toSyncJson() {
    return {
      'client_event_id': clientEventId,
      'server_word_id': serverWordId,
      'local_word_id': localWordId,
      'rating': rating.name,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    };
  }
}

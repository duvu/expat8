enum StudyRating {
  easy('easy'),
  tooEasy('too_easy'),
  hard('hard'),
  tooHard('too_hard');

  const StudyRating(this.apiValue);

  final String apiValue;
}

enum SyncStatus { pending, synced, failed }

class StudyEvent {
  const StudyEvent({
    required this.clientEventId,
    required this.localWordId,
    this.serverWordId,
    required this.rating,
    required this.occurredAt,
    required this.syncStatus,
    this.language,
  });

  final String clientEventId;
  final String localWordId;
  final String? serverWordId;
  final StudyRating rating;
  final DateTime occurredAt;
  final SyncStatus syncStatus;

  /// Learning language of the rated word. Queued with the event so offline
  /// ratings are applied to the right proficiency track when replayed.
  final String? language;

  Map<String, dynamic> toSyncJson() {
    return {
      'client_event_id': clientEventId,
      'server_word_id': serverWordId,
      'local_word_id': localWordId,
      'rating': rating.apiValue,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      if (language != null) 'language': language,
    };
  }
}

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../models/study_event.dart';
import '../models/vocabulary_word.dart';
import 'local_database.dart';

class WordRepository {
  WordRepository({
    required this.database,
    required this.apiClient,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final LocalDatabase database;
  final BackendApiClient apiClient;
  final Uuid _uuid;

  Future<VocabularyWord?> getNewWordWithFallback({String? excludeServerWordId}) async {
    try {
      final excludeServerWordIds = await database.recentServerWordIds();
      if (excludeServerWordId != null &&
          excludeServerWordId.isNotEmpty &&
          !excludeServerWordIds.contains(excludeServerWordId)) {
        excludeServerWordIds.insert(0, excludeServerWordId);
      }
      final words = await apiClient.fetchNewWords(
        limit: 1,
        excludeServerWordIds: excludeServerWordIds,
      );
      if (words.isNotEmpty) {
        await database.upsertWord(words.first);
        await database.pruneToMostRecent();
        return words.first;
      }
    } catch (_) {
      // Local fallback is the product behavior for offline, failed, or timed-out
      // backend requests. Telemetry is emitted by the caller.
    }
    return database.nextNewWord();
  }

  Future<VocabularyWord?> getReviewWord(DateTime now) {
    return database.nextDueReviewWord(now);
  }

  Future<void> bootstrapRecentWords() async {
    final words = await apiClient.fetchRecentWords(limit: 1000);
    for (final word in words.take(1000)) {
      await database.upsertWord(word);
    }
    await database.pruneToMostRecent();
  }

  Future<void> recordRating({
    required VocabularyWord word,
    required StudyRating rating,
    required DateTime now,
  }) async {
    final event = StudyEvent(
      clientEventId: _uuid.v4(),
      localWordId: word.localId,
      serverWordId: word.serverWordId,
      rating: rating,
      occurredAt: now,
      syncStatus: SyncStatus.pending,
    );
    await database.updateWordAfterRating(word: word, rating: rating, now: now);
    await database.insertStudyEvent(event);
  }

  Future<void> syncPendingEvents({
    required String deviceId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now().toUtc();
    final entries = await database.dueSyncEntries(effectiveNow);
    for (final entry in entries) {
      try {
        final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
        final result = await apiClient.syncStudyEvents(
          deviceId: deviceId,
          events: [payload],
        );
        for (final acceptedId in result.acceptedEventIds) {
          await database.markEventSynced(acceptedId);
        }
      } catch (_) {
        await database.scheduleRetry(entry, effectiveNow);
      }
    }
  }
}

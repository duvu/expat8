import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../models/proficiency_state.dart';
import '../models/study_event.dart';
import '../models/user_session.dart';
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

  Future<String> getOrCreateDeviceId() {
    return database.getOrCreateDeviceId(_uuid.v4);
  }

  Future<UserSession?> loadUserSession() {
    return database.loadUserSession();
  }

  Future<UserSession> registerUser({
    required String identifier,
    required String password,
    String? displayName,
  }) async {
    final deviceId = await getOrCreateDeviceId();
    final session = await apiClient.registerUser(
      identifier: identifier,
      password: password,
      displayName: displayName,
      deviceId: deviceId,
    );
    await database.saveUserSession(session);
    return session;
  }

  Future<UserSession> signInUser({
    required String identifier,
    required String password,
  }) async {
    final deviceId = await getOrCreateDeviceId();
    final session = await apiClient.signIn(
      identifier: identifier,
      password: password,
      deviceId: deviceId,
    );
    await database.saveUserSession(session);
    return session;
  }

  Future<void> signOutUser() async {
    final session = await database.loadUserSession();
    if (session == null) {
      return;
    }
    try {
      await apiClient.signOut(session: session);
    } finally {
      await database.clearUserSession();
    }
  }

  Future<ProficiencyState> fetchProficiency({required String deviceId}) async {
    final session = await database.loadUserSession();
    return apiClient.fetchProficiency(
      deviceId: deviceId,
      sessionToken: session?.sessionToken,
    );
  }

  Future<VocabularyWord?> getNewWordWithFallback({
    String? excludeServerWordId,
    String? proficiencyLevel,
    String? deviceId,
  }) async {
    return (await getNewWordWithFallbackResult(
      excludeServerWordId: excludeServerWordId,
      proficiencyLevel: proficiencyLevel,
      deviceId: deviceId,
    ))
        .word;
  }

  Future<WordLookupResult> getNewWordWithFallbackResult({
    String? excludeServerWordId,
    String? proficiencyLevel,
    String? deviceId,
  }) async {
    try {
      final excludeServerWordIds = await database.recentServerWordIds();
      if (excludeServerWordId != null &&
          excludeServerWordId.isNotEmpty &&
          !excludeServerWordIds.contains(excludeServerWordId)) {
        excludeServerWordIds.insert(0, excludeServerWordId);
      }
      final session = await database.loadUserSession();
      final words = await apiClient.fetchNewWords(
        limit: 1,
        excludeServerWordIds: excludeServerWordIds,
        proficiencyLevel: proficiencyLevel,
        deviceId: deviceId,
        sessionToken: session?.sessionToken,
      );
      if (words.isNotEmpty) {
        await database.upsertWord(words.first);
        await database.pruneToMostRecent();
        return WordLookupResult(
          word: words.first,
          source: WordLookupSource.backend,
        );
      }
      final localWord = await database.nextNewWord();
      return WordLookupResult(
        word: localWord,
        source: localWord == null
            ? WordLookupSource.none
            : WordLookupSource.localFallback,
        message: localWord == null ? 'No backend or local new word was available.' : null,
      );
    } catch (error) {
      // Local fallback is the product behavior for offline, failed, or timed-out
      // backend requests. Telemetry is emitted by the caller.
      final localWord = await database.nextNewWord();
      return WordLookupResult(
        word: localWord,
        source: localWord == null
            ? WordLookupSource.none
            : WordLookupSource.localFallback,
        message: localWord == null
            ? 'Could not reach the word feed and no local new word is available.'
            : null,
        error: error,
      );
    }
  }

  Future<VocabularyWord?> getReviewWord(DateTime now) {
    return database.nextDueReviewWord(now);
  }

  Future<VocabularyWord?> getRecentReviewWord(DateTime now) async {
    return (await getRecentReviewWordResult(now)).word;
  }

  Future<WordLookupResult> getRecentReviewWordResult(DateTime now) async {
    final recent = await database.recentlyLearnedReviewWord();
    if (recent != null) {
      return WordLookupResult(word: recent, source: WordLookupSource.recentReview);
    }
    final dueReview = await database.nextDueReviewWord(now);
    return WordLookupResult(
      word: dueReview,
      source: dueReview == null ? WordLookupSource.none : WordLookupSource.dueReview,
      message: dueReview == null ? 'No recent or due review word is available.' : null,
    );
  }

  Future<void> bootstrapRecentWords() async {
    final words = await apiClient.fetchRecentWords(limit: 1000);
    for (final word in words.take(1000)) {
      await database.upsertWord(word);
    }
    await database.pruneToMostRecent();
  }

  Future<ProficiencyState?> recordRating({
    required VocabularyWord word,
    required StudyRating rating,
    required DateTime now,
    required String deviceId,
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
    try {
      final session = await database.loadUserSession();
      final result = await apiClient.submitStudyEvent(
        deviceId: deviceId,
        event: event.toSyncJson(),
        sessionToken: session?.sessionToken,
      );
      await database.markEventSynced(event.clientEventId);
      return result.proficiency;
    } catch (_) {
      return null;
    }
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
        final session = await database.loadUserSession();
        final result = await apiClient.syncStudyEvents(
          deviceId: deviceId,
          events: [payload],
          sessionToken: session?.sessionToken,
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

enum WordLookupSource {
  backend,
  localFallback,
  recentReview,
  dueReview,
  none,
}

class WordLookupResult {
  const WordLookupResult({
    required this.word,
    required this.source,
    this.message,
    this.error,
  });

  final VocabularyWord? word;
  final WordLookupSource source;
  final String? message;
  final Object? error;

  bool get hasWord => word != null;
}

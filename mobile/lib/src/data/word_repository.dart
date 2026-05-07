import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../config.dart';
import '../logging/logger.dart';
import '../models/proficiency_state.dart';
import '../models/study_event.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';
import 'local_database.dart';

class WordRepository {
  WordRepository({
    required this.database,
    required this.apiClient,
    Logger? logger,
    Uuid? uuid,
    AppConfig? config,
  })  : _uuid = uuid ?? const Uuid(),
        _logger = logger ?? const NoopLogger(),
        _config = config ?? AppConfig.fromEnvironment();

  final LocalDatabase database;
  final BackendApiClient apiClient;
  final Logger _logger;
  final Uuid _uuid;
  final AppConfig _config;
  String? _refillDeviceId;

  Future<String> getOrCreateDeviceId() {
    return database.getOrCreateDeviceId(_uuid.v4);
  }

  /// Initializes the internal [VocabularyRefreshWorker] using the given deviceId.
  /// Must be called once the deviceId is known (e.g. during app startup).
  void initRefreshWorker(String deviceId) {
    _refillDeviceId = deviceId;
  }

  /// Checks if the first-install prefetch has been done; if not, runs it
  /// fire-and-forget in the background.
  Future<void> checkAndRunFirstInstallPrefetch() async {
    final done = await database.getSetting(LocalDatabase.keyIsPrefetchDone);
    if (done == 'true') {
      return;
    }
    unawaited(_runBackendManagedRefill(
      limit: _config.vocabPrefetchLimit,
      markPrefetchDone: true,
    ));
  }

  /// Checks if the daily refresh is due today; if so, runs it fire-and-forget.
  Future<void> checkAndRunDailyRefresh() async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final lastRefresh =
        await database.getSetting(LocalDatabase.keyLastDailyRefreshDate);
    if (lastRefresh == today) {
      return;
    }
    final unstudiedCount = await database.countUnstudiedNewWords();
    if (unstudiedCount >= 100) {
      await _logger.info(
        category: AppLogCategory.sync,
        event: 'learning_cards.daily_refresh.skipped',
        message:
            'Daily refresh skipped because local unlearned count is healthy.',
        context: {
          'unlearned_count': unstudiedCount,
          'threshold': 100,
        },
      );
      await database.setSetting(
        LocalDatabase.keyLastDailyRefreshDate,
        today,
      );
      return;
    }
    unawaited(_runBackendManagedRefill(
      limit: 100,
      markDailyRefreshDate: today,
    ));
  }

  /// Records that a word was studied, and triggers a proactive refresh if the
  /// unstudied new-word count drops below the configured threshold.
  Future<void> recordWordStudied() async {
    final raw = await database
        .getSetting(LocalDatabase.keyWordsStudiedSinceLastRefresh);
    final count = (int.tryParse(raw ?? '0') ?? 0) + 1;
    await database.setSetting(
      LocalDatabase.keyWordsStudiedSinceLastRefresh,
      '$count',
    );
    if (count % _config.vocabProactiveThreshold == 0) {
      final unstudied = await database.countUnstudiedNewWords();
      if (unstudied < _config.vocabProactiveMinNew) {
        unawaited(
            _runBackendManagedRefill(limit: _config.vocabProactiveMinNew));
      }
    }
  }

  Future<void> _runBackendManagedRefill({
    required int limit,
    bool markPrefetchDone = false,
    String? markDailyRefreshDate,
  }) async {
    final deviceId = _refillDeviceId ?? await getOrCreateDeviceId();
    try {
      await refillLearningCards(deviceId: deviceId, limit: limit);
      if (markPrefetchDone) {
        await database.setSetting(LocalDatabase.keyIsPrefetchDone, 'true');
      }
      if (markDailyRefreshDate != null) {
        await database.setSetting(
          LocalDatabase.keyLastDailyRefreshDate,
          markDailyRefreshDate,
        );
      }
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'learning_cards.refill_deferred',
        message: 'Backend-managed vocabulary refill failed.',
        context: {'error': '$error'},
      );
    }
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
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.register.success',
      message: 'User registration completed.',
      context: {
        'user_id': session.userId,
      },
    );
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
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.sign_in.success',
      message: 'User sign-in completed.',
      context: {
        'user_id': session.userId,
      },
    );
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
    await _logger.debug(
      category: AppLogCategory.session,
      event: 'proficiency.fetch',
      message: 'Fetching current proficiency.',
      context: {
        'has_session': session != null,
      },
    );
    return apiClient.fetchProficiency(
      deviceId: deviceId,
      sessionToken: session?.sessionToken,
    );
  }

  Future<VocabularyWord?> getNewWordWithFallback({
    String? deviceId,
  }) async {
    return (await getNewWordWithFallbackResult(deviceId: deviceId)).word;
  }

  Future<WordLookupResult> getNewWordWithFallbackResult({
    String? deviceId,
  }) async {
    try {
      final resolvedDeviceId = deviceId ?? await getOrCreateDeviceId();
      final unstudiedCount = await database.countUnstudiedNewWords();
      var refillAttempted = false;
      var usedBackendRefill = false;
      if (unstudiedCount < _config.vocabProactiveMinNew) {
        refillAttempted = true;
        final refilled = await refillLearningCards(
          deviceId: resolvedDeviceId,
          limit: _config.vocabProactiveMinNew,
        );
        usedBackendRefill = refilled.isNotEmpty;
      }
      final localWord = await database.nextNewWord();
      if (localWord != null) {
        final event =
            usedBackendRefill ? 'new_word.refill.hit' : 'new_word.local.hit';
        await _logger.info(
          category: AppLogCategory.api,
          event: event,
          message: usedBackendRefill
              ? 'Selected new word after backend-managed refill.'
              : 'Selected new word from local cache.',
          context: {
            'local_id': localWord.localId,
            'server_word_id': localWord.serverWordId,
            'backend_refill_used': usedBackendRefill,
          },
        );
        return WordLookupResult(
          word: localWord,
          source: usedBackendRefill
              ? WordLookupSource.backend
              : WordLookupSource.localFallback,
        );
      }
      await _logger.warning(
        category: AppLogCategory.api,
        event:
            refillAttempted ? 'new_word.refill.empty' : 'new_word.local.empty',
        message: refillAttempted
            ? 'Backend-managed refill returned no new words.'
            : 'No local new word is available.',
        context: {
          'backend_refill_attempted': refillAttempted,
        },
      );
      return WordLookupResult(
        word: localWord,
        source: localWord == null
            ? WordLookupSource.none
            : WordLookupSource.localFallback,
        message: localWord == null
            ? 'No backend or local new word was available.'
            : null,
      );
    } catch (error) {
      // Local fallback is the product behavior for offline, failed, or timed-out
      // backend requests. Telemetry is emitted by the caller.
      final localWord = await database.nextNewWord();
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'new_word.backend.error',
        message: 'Backend new-word request failed, using local fallback.',
        context: {
          'error': '$error',
          'fallback_source': localWord == null ? 'none' : 'local',
        },
      );
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

  Future<VocabularyWord?> getDifficultRelearnWord(DateTime now) {
    return database.nextDifficultRelearnWord(now);
  }

  Future<VocabularyWord?> getRecentReviewWord(DateTime now) async {
    return (await getRecentReviewWordResult(now)).word;
  }

  Future<WordLookupResult> getRecentReviewWordResult(DateTime now) async {
    final recent = await database.recentlyLearnedReviewWord();
    if (recent != null) {
      await _logger.debug(
        category: AppLogCategory.session,
        event: 'review.recent.hit',
        message: 'Selected recently learned review word.',
        context: {
          'local_id': recent.localId,
        },
      );
      return WordLookupResult(
          word: recent, source: WordLookupSource.recentReview);
    }
    final dueReview = await database.nextDueReviewWord(now);
    return WordLookupResult(
      word: dueReview,
      source: dueReview == null
          ? WordLookupSource.none
          : WordLookupSource.dueReview,
      message: dueReview == null
          ? 'No recent or due review word is available.'
          : null,
    );
  }

  Future<void> bootstrapRecentWords() async {
    final words = await apiClient.fetchRecentWords(limit: 1000);
    await database.addBatch(words.take(1000).toList());
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'bootstrap.recent_words',
      message: 'Bootstrapped recent words into local cache.',
      context: {
        'fetched_count': words.length,
      },
    );
  }

  Future<CacheInventoryResult> syncCacheInventory(
      {required String deviceId}) async {
    final session = await database.loadUserSession();
    final serverWordIds = await database.activeCachedServerWordIds();
    final result = await apiClient.syncCacheInventory(
      deviceId: deviceId,
      serverWordIds: serverWordIds,
      sessionToken: session?.sessionToken,
    );
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'cache_inventory.sync',
      message: 'Synced local cache inventory.',
      context: {
        'device_id': deviceId,
        'cached_count': serverWordIds.length,
        'stored_count': result.storedCount,
        'unknown_count': result.unknownServerWordIds.length,
      },
    );
    return result;
  }

  Future<List<VocabularyWord>> refillLearningCards({
    required String deviceId,
    int limit = 10,
  }) async {
    final session = await database.loadUserSession();
    final batch = await apiClient.fetchLearningCards(
      deviceId: deviceId,
      limit: limit.clamp(1, 100).toInt(),
      sessionToken: session?.sessionToken,
    );
    await database.addBatch(batch.items);
    await syncCacheInventory(deviceId: deviceId);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'learning_cards.refill',
      message: 'Refilled local cache from backend-selected cards.',
      context: {
        'fetched_count': batch.items.length,
        'new_count': batch.actualMix.newCount,
        'review_count': batch.actualMix.reviewCount,
      },
    );
    return batch.items;
  }

  /// Fetches a batch of vocabulary cards from the backend and persists them
  /// locally using [LocalDatabase.addBatch], which enforces the 1000-word cap.
  Future<List<VocabularyWord>> prefetchBatch({int batchSize = 100}) async {
    final deviceId = _refillDeviceId ?? await getOrCreateDeviceId();
    final session = await database.loadUserSession();
    final batch = await apiClient.fetchLearningCards(
      deviceId: deviceId,
      limit: batchSize.clamp(1, 100).toInt(),
      sessionToken: session?.sessionToken,
    );
    await database.addBatch(batch.items);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'learning_cards.prefetch_batch',
      message: 'Prefetched vocabulary batch from backend.',
      context: {
        'batch_size': batchSize,
        'fetched_count': batch.items.length,
      },
    );
    return batch.items;
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
    await database.insertStudyEvent(event);
    if (rating == StudyRating.easy) {
      await database.deleteLocalWord(word.localId);
      try {
        await syncCacheInventory(deviceId: deviceId);
      } catch (error) {
        await _logger.warning(
          category: AppLogCategory.sync,
          event: 'cache_inventory.sync_deferred',
          message: 'Cache inventory sync failed after easy deletion.',
          context: {
            'error': '$error',
          },
        );
      }
      await _logger.info(
        category: AppLogCategory.session,
        event: 'rating.easy.delete_local',
        message: 'Easy-rated word removed from local cache.',
        context: {
          'local_id': word.localId,
          'server_word_id': word.serverWordId,
        },
      );
    } else {
      await database.updateWordAfterRating(
          word: word, rating: rating, now: now);
    }
    await recordWordStudied();
    try {
      final session = await database.loadUserSession();
      final result = await apiClient.submitStudyEvent(
        deviceId: deviceId,
        event: event.toSyncJson(),
        sessionToken: session?.sessionToken,
      );
      await database.markEventSynced(event.clientEventId);
      await _logger.info(
        category: AppLogCategory.session,
        event: 'rating.sync.success',
        message: 'Rating submitted and synced immediately.',
        context: {
          'client_event_id': event.clientEventId,
          'rating': rating.name,
        },
      );
      return result.proficiency;
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'rating.sync.deferred',
        message: 'Rating persisted locally and queued for retry.',
        context: {
          'client_event_id': event.clientEventId,
          'error': '$error',
        },
      );
      return null;
    }
  }

  Future<void> markRememberedLowFrequency({
    required VocabularyWord word,
    required DateTime now,
    required String deviceId,
  }) async {
    await database.markWordRememberedLowFrequency(word: word, now: now);
    await recordWordStudied();
    await _logger.info(
      category: AppLogCategory.session,
      event: 'gesture.remembered.local_state_updated',
      message: 'Applied remembered gesture update locally.',
      context: {
        'word_id': word.serverWordId ?? word.localId,
        'relearn_frequency_percent': 10,
      },
    );
    try {
      await syncCacheInventory(deviceId: deviceId);
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'gesture.remembered.sync_deferred',
        message: 'Deferred cache sync after remembered gesture.',
        context: {'error': '$error'},
      );
    }
  }

  Future<void> markAsDifficultForRelearn({
    required VocabularyWord word,
    required DateTime now,
    required String deviceId,
  }) async {
    await database.markWordDifficultForRelearn(word: word, now: now);
    await recordWordStudied();
    await _logger.info(
      category: AppLogCategory.session,
      event: 'gesture.difficult.local_state_updated',
      message: 'Applied difficult gesture update locally.',
      context: {
        'word_id': word.serverWordId ?? word.localId,
      },
    );
    try {
      await syncCacheInventory(deviceId: deviceId);
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'gesture.difficult.sync_deferred',
        message: 'Deferred cache sync after difficult gesture.',
        context: {'error': '$error'},
      );
    }
  }

  /// Transitions a newly displayed [newWord] to [learning] status.
  ///
  /// Called fire-and-forget from the controller after a word is shown so the
  /// word pool advances and the same word is not shown again on the next swipe.
  Future<void> markWordAsLearning({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    await database.markWordAsLearning(word: word, now: now);
  }

  Future<void> syncPendingEvents({
    required String deviceId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now().toUtc();
    final entries = await database.dueSyncEntries(effectiveNow);
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'sync.batch.start',
      message: 'Sync batch started.',
      context: {
        'entries': entries.length,
      },
    );
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
      } catch (error) {
        await database.scheduleRetry(entry, effectiveNow);
        await _logger.warning(
          category: AppLogCategory.sync,
          event: 'sync.batch.retry',
          message: 'Sync entry failed and was scheduled for retry.',
          context: {
            'queue_id': entry.id,
            'error': '$error',
          },
        );
      }
    }
  }

  Future<List<LogEntry>> loadLogs({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 200,
    int offset = 0,
  }) {
    return database.queryLogs(
      minimumLevel: minimumLevel,
      category: category,
      from: from,
      to: to,
      limit: limit,
      offset: offset,
    );
  }

  Future<LogExportResult> exportLogs({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 2000,
  }) async {
    final logs = await loadLogs(
      minimumLevel: minimumLevel,
      category: category,
      from: from,
      to: to,
      limit: limit,
    );
    final payload = logs.map((entry) => entry.toJsonLine()).join('\n');
    if (kIsWeb) {
      return LogExportResult(path: null, payload: payload, count: logs.length);
    }
    final file = File(
      '${Directory.systemTemp.path}/expat8_logs_${DateTime.now().millisecondsSinceEpoch}.jsonl',
    );
    await file.writeAsString(payload);
    return LogExportResult(
        path: file.path, payload: payload, count: logs.length);
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

class LogExportResult {
  const LogExportResult({
    required this.path,
    required this.payload,
    required this.count,
  });

  final String? path;
  final String payload;
  final int count;
}

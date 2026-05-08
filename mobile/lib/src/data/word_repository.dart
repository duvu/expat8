import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../config.dart';
import '../logging/logger.dart';
import '../models/proficiency_state.dart';
import '../models/study_event.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';
import 'local_database.dart';
import 'seed_vocabulary_loader.dart';

class WordRepository {
  WordRepository({
    required this.database,
    required this.apiClient,
    Logger? logger,
    Uuid? uuid,
    AppConfig? config,
    SeedVocabularyLoader? seedLoader,
  })  : _uuid = uuid ?? const Uuid(),
        _logger = logger ?? const NoopLogger(),
        _config = config ?? AppConfig.fromEnvironment(),
        _seedLoader = seedLoader ?? const SeedVocabularyLoader();

  final LocalDatabase database;
  final BackendApiClient apiClient;
  final Logger _logger;
  final Uuid _uuid;
  final AppConfig _config;
  final SeedVocabularyLoader _seedLoader;
  String? _refillDeviceId;
  String _activeLanguage = 'en';

  Future<String> getOrCreateDeviceId() {
    return database.getOrCreateDeviceId(_uuid.v4);
  }

  void initRefreshWorker(String deviceId) {
    _refillDeviceId = deviceId;
  }

  void setActiveLanguage(String language) {
    _activeLanguage = language;
  }

  /// Seeds the local cache from the app bundle for any [languages] whose local
  /// table is empty. Returns the total number of words inserted.
  ///
  /// Designed to run synchronously during app launch so the user can start
  /// learning immediately without waiting for a backend round-trip. Languages
  /// that already have entries are skipped (idempotent on subsequent launches).
  Future<int> seedFromBundleIfEmpty({required List<String> languages}) async {
    var totalLoaded = 0;
    for (final language in languages) {
      final existing = await database.countWords(language: language);
      if (existing > 0) continue;
      final seed = await _seedLoader.loadForLanguage(language);
      if (seed.isEmpty) continue;
      await database.addBatch(seed);
      totalLoaded += seed.length;
      await _logger.info(
        category: AppLogCategory.app,
        event: 'seed_vocab.bundle_loaded',
        message: 'Seeded local vocabulary cache from app bundle.',
        context: {
          'language': language,
          'loaded_count': seed.length,
        },
      );
    }
    return totalLoaded;
  }

  /// Decides whether the local cache needs more words and acts accordingly.
  ///
  /// Rules (per active language):
  ///   1. DB empty           → load [vocabFirstInstallSize] words.
  ///   2. DB < poolFullSize  → load [vocabHourlyTopUpSize] words.
  ///   3. DB ≥ poolFullSize and unstudied < [vocabRotationUnstudiedThreshold]
  ///      → delete the oldest [vocabRotationSize] mastered words, then load
  ///        [vocabRotationSize] new words.
  ///   4. Otherwise          → no action.
  Future<TopUpResult> topUpInventoryIfNeeded() async {
    final language = _activeLanguage;
    final total = await database.countWords(language: language);
    final unstudied = await database.countUnstudiedNewWords(language: language);

    if (total == 0) {
      final loaded = await _safeRefill(
        limit: _config.vocabFirstInstallSize,
        eventTag: 'first_install',
      );
      return TopUpResult(action: TopUpAction.firstInstall, loaded: loaded);
    }

    if (total < _config.vocabPoolFullSize) {
      final loaded = await _safeRefill(
        limit: _config.vocabHourlyTopUpSize,
        eventTag: 'hourly_top_up',
      );
      return TopUpResult(action: TopUpAction.hourlyTopUp, loaded: loaded);
    }

    if (unstudied < _config.vocabRotationUnstudiedThreshold) {
      final deleted = await database.deleteOldestMasteredWords(
        language: language,
        limit: _config.vocabRotationSize,
      );
      final loaded = await _safeRefill(
        limit: _config.vocabRotationSize,
        eventTag: 'rotation',
      );
      return TopUpResult(
        action: TopUpAction.rotation,
        loaded: loaded,
        deleted: deleted,
      );
    }

    return const TopUpResult(action: TopUpAction.none);
  }

  Future<int> _safeRefill({
    required int limit,
    required String eventTag,
  }) async {
    final deviceId = _refillDeviceId ?? await getOrCreateDeviceId();
    try {
      final words = await refillLearningCards(
        deviceId: deviceId,
        limit: limit,
        language: _activeLanguage,
      );
      return words.length;
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'inventory.refill.failed',
        message: 'Vocabulary inventory refill failed.',
        context: {'tag': eventTag, 'limit': limit, 'error': '$error'},
      );
      return 0;
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

  Future<ProficiencyState> fetchProficiency({
    required String deviceId,
    String language = 'en',
  }) async {
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
      language: language,
      sessionToken: session?.sessionToken,
    );
  }

  Future<VocabularyWord?> getNewWordWithFallback(
      {String language = 'en'}) async {
    return (await getNewWordWithFallbackResult(language: language)).word;
  }

  Future<WordLookupResult> getNewWordWithFallbackResult({
    String language = 'en',
  }) async {
    final localWord = await database.nextNewWord(language: language);
    if (localWord != null) {
      await _logger.info(
        category: AppLogCategory.api,
        event: 'new_word.local.hit',
        message: 'Selected new word from local cache.',
        context: {
          'local_id': localWord.localId,
          'server_word_id': localWord.serverWordId,
        },
      );
      return WordLookupResult(
        word: localWord,
        source: WordLookupSource.localFallback,
      );
    }
    final randomWord =
        await database.randomNotMasteredWord(language: language);
    if (randomWord != null) {
      await _logger.info(
        category: AppLogCategory.api,
        event: 'new_word.random.fallback',
        message:
            'No new-word card available; serving a random non-mastered word.',
        context: {
          'local_id': randomWord.localId,
          'server_word_id': randomWord.serverWordId,
        },
      );
      return WordLookupResult(
        word: randomWord,
        source: WordLookupSource.randomFallback,
      );
    }
    final anyWord = await database.randomWord(language: language);
    if (anyWord != null) {
      await _logger.info(
        category: AppLogCategory.api,
        event: 'new_word.random_any.fallback',
        message:
            'No new or active review card available; serving any cached word.',
        context: {
          'local_id': anyWord.localId,
          'server_word_id': anyWord.serverWordId,
        },
      );
      return WordLookupResult(
        word: anyWord,
        source: WordLookupSource.randomFallback,
      );
    }
    await _logger.warning(
      category: AppLogCategory.api,
      event: 'new_word.local.empty',
      message: 'No local card is available for this language.',
    );
    return const WordLookupResult(
      word: null,
      source: WordLookupSource.none,
      message: 'No learning card is available. Check connection and try again.',
    );
  }

  Future<VocabularyWord?> getReviewWord(DateTime now,
      {String language = 'en'}) {
    return database.nextDueReviewWord(now, language: language);
  }

  Future<VocabularyWord?> getDifficultRelearnWord(DateTime now,
      {String language = 'en'}) {
    return database.nextDifficultRelearnWord(now, language: language);
  }

  Future<WordLookupResult> getReviewFallbackResult(DateTime now,
      {String language = 'en'}) async {
    final difficult =
        await database.nextDifficultRelearnWord(now, language: language);
    if (difficult != null) {
      return WordLookupResult(
        word: difficult,
        source: WordLookupSource.difficultRelearn,
      );
    }
    return getRecentReviewWordResult(now, language: language);
  }

  Future<WordLookupResult> getRecentReviewWordResult(DateTime now,
      {String language = 'en'}) async {
    final recent = await database.recentlyLearnedReviewWord(language: language);
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
    final dueReview = await database.nextDueReviewWord(now, language: language);
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
    String language = 'en',
  }) async {
    if (limit <= 0) return const [];
    final session = await database.loadUserSession();
    const apiBatchCap = 100;
    final allItems = <VocabularyWord>[];
    while (allItems.length < limit) {
      final batchLimit = (limit - allItems.length).clamp(1, apiBatchCap).toInt();
      final batch = await apiClient.fetchLearningCards(
        deviceId: deviceId,
        limit: batchLimit,
        targetLanguage: language,
        sessionToken: session?.sessionToken,
      );
      if (batch.items.isEmpty) break;
      allItems.addAll(batch.items);
    }
    await database.addBatch(allItems);
    await syncCacheInventory(deviceId: deviceId);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'learning_cards.refill',
      message: 'Refilled local cache from backend-selected cards.',
      context: {
        'requested_limit': limit,
        'fetched_count': allItems.length,
      },
    );
    return allItems;
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
    await _logger.info(
      category: AppLogCategory.session,
      event: 'gesture.remembered.local_state_updated',
      message: 'Applied remembered gesture update locally.',
      context: {
        'word_id': word.serverWordId ?? word.localId,
        'relearn_frequency_percent': 10,
      },
    );
    _syncCacheInventoryInBackground(
      deviceId: deviceId,
      event: 'gesture.remembered.sync_deferred',
      message: 'Deferred cache sync after remembered gesture.',
    );
  }

  Future<void> markAsDifficultForRelearn({
    required VocabularyWord word,
    required DateTime now,
    required String deviceId,
  }) async {
    await database.markWordDifficultForRelearn(word: word, now: now);
    await _logger.info(
      category: AppLogCategory.session,
      event: 'gesture.difficult.local_state_updated',
      message: 'Applied difficult gesture update locally.',
      context: {
        'word_id': word.serverWordId ?? word.localId,
      },
    );
    _syncCacheInventoryInBackground(
      deviceId: deviceId,
      event: 'gesture.difficult.sync_deferred',
      message: 'Deferred cache sync after difficult gesture.',
    );
  }

  void _syncCacheInventoryInBackground({
    required String deviceId,
    required String event,
    required String message,
  }) {
    unawaited(() async {
      try {
        await syncCacheInventory(deviceId: deviceId);
      } catch (error) {
        await _logger.warning(
          category: AppLogCategory.sync,
          event: event,
          message: message,
          context: {'error': '$error'},
        );
      }
    }());
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
    final exportedAt = DateTime.now().toUtc();
    final fileName = 'expat8_logs_${_fileTimestamp(exportedAt)}.txt';
    final payload = _formatLogExportPayload(logs, exportedAt);
    if (logs.isEmpty || kIsWeb) {
      return LogExportResult(
        path: null,
        payload: payload,
        count: logs.length,
        fileName: fileName,
      );
    }
    final exportDir = await _resolveLogExportDirectory();
    final file = File('${exportDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(payload);
    return LogExportResult(
      path: file.path,
      payload: payload,
      count: logs.length,
      fileName: fileName,
    );
  }

  String _formatLogExportPayload(List<LogEntry> logs, DateTime exportedAt) {
    final sanitizer = LogSanitizer();
    final lines = [
      '# Expat8 mobile logs',
      '# Exported at: ${exportedAt.toIso8601String()}',
      '# Entries: ${logs.length}',
      ...logs.map((entry) => sanitizer.sanitize(entry).toJsonLine()),
    ];
    return '${lines.join('\n')}\n';
  }

  String _fileTimestamp(DateTime value) {
    return value
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_');
  }

  Future<Directory> _resolveLogExportDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return getTemporaryDirectory();
    }
    return Directory.systemTemp;
  }
}

enum WordLookupSource {
  localFallback,
  randomFallback,
  recentReview,
  dueReview,
  difficultRelearn,
  none,
}

enum TopUpAction { none, firstInstall, hourlyTopUp, rotation }

class TopUpResult {
  const TopUpResult({
    required this.action,
    this.loaded = 0,
    this.deleted = 0,
  });

  final TopUpAction action;
  final int loaded;
  final int deleted;
}

class WordLookupResult {
  const WordLookupResult({
    required this.word,
    required this.source,
    this.message,
  });

  final VocabularyWord? word;
  final WordLookupSource source;
  final String? message;
}

class LogExportResult {
  const LogExportResult({
    required this.path,
    required this.payload,
    required this.count,
    required this.fileName,
    this.mimeType = 'text/plain',
  });

  final String? path;
  final String payload;
  final int count;
  final String fileName;
  final String mimeType;
}

import 'dart:async';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/config.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('falls back to local new words when backend fails', () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_fallback.db',
    );
    final localWord = _word('local_word');
    await database.upsertWord(localWord);
    final repository = WordRepository(
      database: database,
      apiClient: _FailingApiClient(),
    );

    final word = await repository.getNewWordWithFallback();
    expect(word?.localId, localWord.localId);
  });

  test('emits local-hit log even when backend fails', () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_logging_fallback.db',
    );
    final localWord = _word('local_word_log');
    await database.upsertWord(localWord);
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final repository = WordRepository(
      database: database,
      apiClient: _FailingApiClient(),
      logger: logger,
    );

    final result = await repository.getNewWordWithFallbackResult();

    expect(result.word?.localId, localWord.localId);
    expect(
      entries.any((entry) => entry.event == 'new_word.local.hit'),
      true,
    );
  });

  test('logs local cache hit without labeling it backend success', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_local_hit_log_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final localWord = _word('local_hit_word');
    await database.upsertWord(localWord);
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      logger: logger,
      config: _testConfig(proactiveMinNew: 1),
    );

    final result = await repository.getNewWordWithFallbackResult(
      deviceId: 'device_local_hit',
    );

    expect(result.word?.localId, localWord.localId);
    expect(entries.any((entry) => entry.event == 'new_word.local.hit'), true);
    expect(
      entries.any((entry) => entry.event == 'new_word.backend.success'),
      false,
    );
  });

  test('returns null from empty local cache even when backend has words',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_refill_hit_log_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(
        learningCardItems: [_word('refill_hit_word')],
      ),
      config: _testConfig(proactiveMinNew: 10),
    );

    final result = await repository.getNewWordWithFallbackResult(
      deviceId: 'device_refill_hit',
    );

    // Backend refill fires in background; local cache is empty so no word yet.
    expect(result.word, isNull);
    expect(result.source, WordLookupSource.none);
  });

  test('logs local-empty when local cache is empty', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_refill_empty_log_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      logger: logger,
      config: _testConfig(proactiveMinNew: 10),
    );

    final result = await repository.getNewWordWithFallbackResult(
      deviceId: 'device_refill_empty',
    );

    expect(result.word, isNull);
    expect(entries.any((entry) => entry.event == 'new_word.local.empty'), true);
  });

  test('logs local-hit when local word exists despite failing backend',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_error_fallback_log_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final localWord = _word('error_fallback_word');
    await database.upsertWord(localWord);
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final repository = WordRepository(
      database: database,
      apiClient: _FailingApiClient(),
      logger: logger,
    );

    final result = await repository.getNewWordWithFallbackResult(
      deviceId: 'device_error_fallback',
    );

    expect(result.word?.localId, localWord.localId);
    expect(entries.any((entry) => entry.event == 'new_word.local.hit'), true);
  });

  test('reports local fallback source when backend fails but local word exists',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_fallback_result.db',
    );
    final localWord = _word('local_word_result');
    await database.upsertWord(localWord);
    final repository = WordRepository(
      database: database,
      apiClient: _FailingApiClient(),
    );

    final result = await repository.getNewWordWithFallbackResult();

    expect(result.word?.localId, localWord.localId);
    expect(result.source, WordLookupSource.localFallback);
  });

  test('reports miss source when backend fails and no local word exists',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_fallback_miss.db',
    );
    final repository = WordRepository(
      database: database,
      apiClient: _FailingApiClient(),
    );

    final result = await repository.getNewWordWithFallbackResult();

    expect(result.word, isNull);
    expect(result.source, WordLookupSource.none);
    expect(result.message,
        'No learning card is available. Check connection and try again.');
  });

  test('requests learning card batch without server word exclusions', () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_exclusion.db',
    );
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
    );

    await repository.getNewWordWithFallback(deviceId: 'anonymous_repo');
    await pumpEventQueue();

    expect(apiClient.lastLearningCardsDeviceId, 'anonymous_repo');
    expect(apiClient.lastLearningCardsLimit, 10);
  });

  test('returns server proficiency after immediate rating submission',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_rating.db',
    );
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
    );
    final word = _word('server_word');
    await database.upsertWord(word);

    final proficiency = await repository.recordRating(
      word: word,
      rating: StudyRating.tooEasy,
      now: DateTime.utc(2026, 5, 4),
      deviceId: 'device_repo',
    );

    expect(proficiency?.level, 'A2');
  });

  test(
      'easy rating queues study event, deletes local word, and syncs cache inventory',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_easy_delete_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = _RecordingApiClient(failSubmit: true);
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
    );
    final word = _word('easy_word');
    await database.upsertWord(word);

    await repository.recordRating(
      word: word,
      rating: StudyRating.easy,
      now: DateTime.utc(2026, 5, 4),
      deviceId: 'device_repo',
    );

    final remaining = await database.nextNewWord();
    final dueEntries = await database.dueSyncEntries(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );

    expect(remaining, isNull);
    expect(dueEntries.single.payload, contains('"server_word_id":"easy_word"'));
    expect(apiClient.lastSyncedCachedServerWordIds, isEmpty);
  });

  test('syncs cache inventory from local active words', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_inventory_sync_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(database: database, apiClient: apiClient);
    await database.upsertWord(_word('cached_1'));
    await database.upsertWord(_word('cached_2'));

    await repository.syncCacheInventory(deviceId: 'device_repo');

    expect(apiClient.lastSyncedDeviceId, 'device_repo');
    expect(apiClient.lastSyncedCachedServerWordIds,
        containsAll(['cached_1', 'cached_2']));
  });

  test(
      'registers user, persists session, and sends session token on learning requests',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_user_session.db',
    );
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(database: database, apiClient: apiClient);

    final session = await repository.registerUser(
      identifier: 'learner@example.com',
      password: 'correct-password',
      displayName: 'Learner',
    );
    await repository.getNewWordWithFallback(deviceId: 'device_repo');

    final loaded = await repository.loadUserSession();

    expect(session.userId, 'user_1');
    expect(loaded?.sessionToken, 'session_recording');
    expect(apiClient.lastSessionToken, 'session_recording');
  });

  test(
      'clears local session on sign out and keeps anonymous learning available',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_sign_out.db',
    );
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(database: database, apiClient: apiClient);

    await repository.signInUser(
      identifier: 'learner@example.com',
      password: 'correct-password',
    );
    await repository.signOutUser();
    await repository.getNewWordWithFallback(deviceId: 'device_repo');

    expect(await repository.loadUserSession(), isNull);
    expect(apiClient.signOutCalled, true);
    expect(apiClient.lastSessionToken, isNull);
  });

  test('sync pending events logs retry on failure', () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_sync_retry_log.db',
    );
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final repository = WordRepository(
      database: database,
      apiClient: _SyncFailingApiClient(),
      logger: logger,
    );

    final now = DateTime.now().toUtc();
    await database.insertStudyEvent(
      StudyEvent(
        clientEventId: 'evt_sync_1',
        localWordId: 'local_sync_1',
        serverWordId: 'server_sync_1',
        rating: StudyRating.easy,
        occurredAt: now,
        syncStatus: SyncStatus.pending,
      ),
    );

    await repository.syncPendingEvents(
      deviceId: 'device_repo',
      now: now.add(const Duration(minutes: 1)),
    );

    expect(entries.any((entry) => entry.event == 'sync.batch.retry'), true);
  });

  test('exports logs as JSONL payload', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_export_logs_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 10, 0),
        level: AppLogLevel.error,
        category: AppLogCategory.api,
        event: 'api.error',
        message: 'Request failed',
        context: const {'status_code': 500},
      ),
    );
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      logger: const NoopLogger(),
    );

    final exported =
        await repository.exportLogs(minimumLevel: AppLogLevel.warning);

    expect(exported.count, 1);
    expect(exported.payload.contains('api.error'), true);
  });

  test('checkAndRunFirstInstallPrefetch skips when prefetch already done',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_prefetch_skip_$ts.db',
    );
    await database.setSetting(LocalDatabase.keyIsPrefetchDone, 'true');
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    await repository.checkAndRunFirstInstallPrefetch();

    expect(apiClient.fetchRecentWordsCalled, false);
  });

  test(
      'checkAndRunFirstInstallPrefetch completes without error when not yet done',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_prefetch_run_$ts.db',
    );
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    // Should not throw
    await repository.checkAndRunFirstInstallPrefetch();

    // prefetch is running in background; its result is tested in vocabulary_refresh_worker_test
    expect(apiClient, isNotNull);
  });

  test('checkAndRunDailyRefresh skips when already refreshed today', () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_daily_skip_$ts.db',
    );
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await database.setSetting(LocalDatabase.keyLastDailyRefreshDate, today);
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    await repository.checkAndRunDailyRefresh();

    expect(apiClient.fetchRecentWordsCalled, false);
  });

  test(
      'checkAndRunDailyRefresh requests 100-card top-up when unlearned is below 100',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_daily_topup_$ts.db',
    );
    for (var i = 0; i < 20; i++) {
      await database.upsertWord(_word('daily_topup_$i'));
    }
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    await repository.checkAndRunDailyRefresh();
    await Future<void>.delayed(Duration.zero);

    expect(apiClient.lastLearningCardsLimit, 100);
  });

  test('checkAndRunDailyRefresh skips top-up when unlearned is at least 100',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_daily_no_topup_$ts.db',
    );
    for (var i = 0; i < 120; i++) {
      await database.upsertWord(_word('daily_no_topup_$i'));
    }
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    await repository.checkAndRunDailyRefresh();

    expect(apiClient.lastLearningCardsLimit, isNull);
  });

  test('recordWordStudied increments words_studied counter in settings',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_proactive_trigger_$ts.db',
    );
    await database.upsertWord(_word('word_1'));

    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(proactiveThreshold: 5, proactiveMinNew: 5),
    );
    repository.initRefreshWorker('device_test');

    // Study 3 words; counter should be 3, no threshold reached yet
    for (var i = 0; i < 3; i++) {
      await repository.recordWordStudied();
    }

    final raw = await database
        .getSetting(LocalDatabase.keyWordsStudiedSinceLastRefresh);
    expect(int.parse(raw!), 3);
  });

  test('_prefetchInFlight debounces concurrent low-watermark prefetch triggers',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'controller_test_debounce_$ts.db',
    );
    // Insert exactly 3 words — at the <= 3 watermark threshold
    for (var i = 0; i < 3; i++) {
      await database.upsertWord(_word('debounce_word_$i'));
    }

    final prefetchCompleter = Completer<void>();
    var prefetchCallCount = 0;

    final slowRepository = _SlowPrefetchRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      onPrefetch: () {
        prefetchCallCount += 1;
        return prefetchCompleter.future;
      },
    );
    slowRepository.initRefreshWorker('device_debounce');

    final controller = LearningSessionController(repository: slowRepository);

    // Trigger the low-watermark logic directly by calling
    // _triggerPrefetchIfNeeded twice before the first prefetch resolves.
    // We do this by inserting a "current" word and calling rateCurrent.
    await database.upsertWord(_word('current_word'));
    await controller.showNewWord();

    // First rateCurrent call: triggers prefetchBatch (prefetchCallCount → 1)
    // Don't await — keeps the slow prefetch in flight
    unawaited(controller.rateCurrent(StudyRating.hard));

    // Drain microtasks so _triggerPrefetchIfNeeded runs and sets _prefetchInFlight
    await Future<void>.delayed(Duration.zero);

    // Second trigger while first is still in flight should be suppressed
    controller.rateCurrent(StudyRating.hard);
    await Future<void>.delayed(Duration.zero);

    expect(prefetchCallCount, lessThanOrEqualTo(1),
        reason: '_prefetchInFlight should prevent concurrent prefetch calls');

    // Release the first prefetch
    prefetchCompleter.complete();
    await Future<void>.delayed(Duration.zero);
  });
}

class _SlowPrefetchRepository extends WordRepository {
  _SlowPrefetchRepository({
    required super.database,
    required super.apiClient,
    required Future<void> Function() onPrefetch,
  }) : _onPrefetch = onPrefetch;

  final Future<void> Function() _onPrefetch;

  @override
  Future<List<VocabularyWord>> prefetchBatch({int batchSize = 100}) async {
    await _onPrefetch();
    return const [];
  }
}

class _FailingApiClient extends BackendApiClient {
  _FailingApiClient()
      : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  @override
  Future<LearningCardBatch> fetchLearningCards({
    required String deviceId,
    int limit = 20,
    String targetLanguage = 'en',
    String? sessionToken,
  }) {
    throw BackendApiException('forced failure');
  }
}

class _RecordingApiClient extends BackendApiClient {
  _RecordingApiClient({
    this.failSubmit = false,
    this.learningCardItems = const [],
  }) : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  final bool failSubmit;
  final List<VocabularyWord> learningCardItems;
  String? lastLearningCardsDeviceId;
  int? lastLearningCardsLimit;
  String? lastSessionToken;
  bool signOutCalled = false;
  bool fetchRecentWordsCalled = false;
  String? lastSyncedDeviceId;
  List<String> lastSyncedCachedServerWordIds = const [];

  @override
  Future<List<VocabularyWord>> fetchRecentWords({
    int limit = 1000,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    List<String> excludeIds = const [],
    String? deviceId,
  }) async {
    fetchRecentWordsCalled = true;
    return [];
  }

  @override
  Future<CacheInventoryResult> syncCacheInventory({
    required String deviceId,
    required List<String> serverWordIds,
    DateTime? observedAt,
    String? sessionToken,
  }) async {
    lastSyncedDeviceId = deviceId;
    lastSyncedCachedServerWordIds = serverWordIds;
    lastSessionToken = sessionToken;
    return CacheInventoryResult(
      storedCount: serverWordIds.length,
      unknownServerWordIds: const [],
    );
  }

  @override
  Future<LearningCardBatch> fetchLearningCards({
    required String deviceId,
    int limit = 20,
    String targetLanguage = 'en',
    String? sessionToken,
  }) async {
    lastLearningCardsDeviceId = deviceId;
    lastLearningCardsLimit = limit;
    lastSessionToken = sessionToken;
    return LearningCardBatch(
      items: learningCardItems.take(limit).toList(),
      targetMix: LearningCardMix(newCount: limit, reviewCount: 0),
      actualMix: LearningCardMix(
        newCount: learningCardItems.take(limit).length,
        reviewCount: 0,
      ),
    );
  }

  @override
  Future<StudyEventResult> submitStudyEvent({
    required String deviceId,
    required Map<String, dynamic> event,
    String language = 'en',
    String? sessionToken,
  }) async {
    lastSessionToken = sessionToken;
    if (failSubmit) {
      throw BackendApiException('forced submit failure');
    }
    return StudyEventResult(
      success: true,
      eventId: event['client_event_id'] as String,
      idempotent: false,
      proficiency: const ProficiencyState(
        scale: 'cefr',
        level: 'A2',
        levelIndex: 1,
        levelChanged: true,
        previousLevel: 'A1',
      ),
    );
  }

  @override
  Future<UserSession> registerUser({
    required String identifier,
    required String password,
    String? displayName,
    String? deviceId,
  }) async {
    return const UserSession(
      userId: 'user_1',
      identifier: 'learner@example.com',
      displayName: 'Learner',
      sessionToken: 'session_recording',
    );
  }

  @override
  Future<UserSession> signIn({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    return const UserSession(
      userId: 'user_1',
      identifier: 'learner@example.com',
      displayName: 'Learner',
      sessionToken: 'session_recording',
    );
  }

  @override
  Future<void> signOut({required UserSession session}) async {
    signOutCalled = true;
  }
}

class _SyncFailingApiClient extends BackendApiClient {
  _SyncFailingApiClient()
      : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  @override
  Future<SyncResult> syncStudyEvents({
    required String deviceId,
    required List<Map<String, dynamic>> events,
    String? sessionToken,
  }) {
    throw BackendApiException('forced sync failure');
  }
}

VocabularyWord _word(String id) {
  final now = DateTime.utc(2026, 5, 4);
  return VocabularyWord(
    localId: id,
    serverWordId: id,
    term: id,
    language: 'en',
    meaningVi: 'meaning',
    partOfSpeech: 'noun',
    ipa: '/wɜːd/',
    vietnamesePronunciation: 'word',
    example: 'A sample word.',
    exampleVi: 'A sample meaning.',
    difficulty: 'A1',
    topics: const ['sample'],
    status: WordStatus.newWord,
    createdAt: now,
    updatedAt: now,
  );
}

AppConfig _testConfig(
    {int proactiveThreshold = 100, int proactiveMinNew = 15}) {
  return AppConfig(
    backendBaseUrl: 'http://unused',
    newWordTimeout: Duration.zero,
    appCredentialAppId: 'test-app',
    appCredentialSecret: 'test-secret',
    defaultLearningLanguage: 'en',
    supportedLearningLanguages: const ['en', 'zh', 'vi'],
    logLevel: 'info',
    logMaxEntries: 100,
    logRetentionDays: 1,
    vocabPrefetchLimit: 100,
    vocabDailyRefreshCount: 20,
    vocabProactiveThreshold: proactiveThreshold,
    vocabProactiveMinNew: proactiveMinNew,
  );
}

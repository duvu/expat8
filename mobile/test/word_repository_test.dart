import 'dart:convert';
import 'dart:io';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/config.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/seed_vocabulary_loader.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
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
      config: _testConfig(),
    );

    final result = await repository.getNewWordWithFallbackResult();

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
      config: _testConfig(),
    );

    final result = await repository.getNewWordWithFallbackResult();

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
      config: _testConfig(),
    );

    final result = await repository.getNewWordWithFallbackResult();

    expect(result.word, isNull);
    expect(entries.any((entry) => entry.event == 'new_word.local.empty'), true);
  });

  test('falls back to a random non-mastered word when new pool is empty',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_random_fallback_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.now().toUtc();
    final learned = _word('random_fallback_learned', base);
    await database.upsertWord(learned);
    await database.markWordAsLearning(word: learned, now: base);
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      logger: logger,
      config: _testConfig(),
    );

    final result = await repository.getNewWordWithFallbackResult();

    expect(result.word?.localId, 'random_fallback_learned');
    expect(result.source, WordLookupSource.randomFallback);
    expect(
      entries.any((entry) => entry.event == 'new_word.random.fallback'),
      true,
    );
  });

  test('random fallback returns a mastered word when it is the only local card',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_random_mastered_only_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.now().toUtc();
    final mastered = _word('mastered_word', base);
    await database.upsertWord(mastered);
    await database.markWordRememberedLowFrequency(word: mastered, now: base);
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      config: _testConfig(),
    );

    final result = await repository.getNewWordWithFallbackResult();

    expect(result.word?.localId, 'mastered_word');
    expect(result.source, WordLookupSource.randomFallback);
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

    final result = await repository.getNewWordWithFallbackResult();

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

  test('remembered gesture queues too_easy event and marks word mastered',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_remembered_gesture_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = _RecordingApiClient(failSubmit: true);
    final repository = WordRepository(database: database, apiClient: apiClient);
    final now = DateTime.utc(2026, 5, 4);
    final word = _word('remembered_gesture_word');
    await database.upsertWord(word);

    await repository.recordRememberedGesture(
      word: word,
      now: now,
      deviceId: 'device_repo',
    );

    final dueEntries = await database.dueSyncEntries(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
    final payload =
        jsonDecode(dueEntries.single.payload) as Map<String, dynamic>;

    expect(payload['rating'], 'too_easy');
    expect(await database.randomNotMasteredWord(), isNull);
  });

  test('difficult gesture queues too_hard event and schedules relearn',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_difficult_gesture_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = _RecordingApiClient(failSubmit: true);
    final repository = WordRepository(database: database, apiClient: apiClient);
    final now = DateTime.utc(2026, 5, 4);
    final word = _word('difficult_gesture_word');
    await database.upsertWord(word);

    await repository.recordDifficultGesture(
      word: word,
      now: now,
      deviceId: 'device_repo',
    );

    final dueEntries = await database.dueSyncEntries(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
    final payload =
        jsonDecode(dueEntries.single.payload) as Map<String, dynamic>;
    final dueDifficult = await database.nextDifficultRelearnWord(
      now.add(const Duration(minutes: 11)),
    );

    expect(payload['rating'], 'too_hard');
    expect(dueDifficult?.localId, 'difficult_gesture_word');
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
    await repository.topUpInventoryIfNeeded();

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
    await repository.topUpInventoryIfNeeded();

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

  test('exports logs as a sanitized UTF-8 text file with metadata', () async {
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
        message: 'Request failed with Bearer secret-token',
        context: const {
          'status_code': 500,
          'app_secret': 'secret-value',
          'nested': {'token': 'nested-token'},
        },
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
    expect(exported.fileName, endsWith('.txt'));
    expect(exported.mimeType, 'text/plain');
    expect(exported.path, isNotNull);
    expect(exported.payload.contains('# Expat8 mobile logs'), true);
    expect(exported.payload.contains('api.error'), true);
    expect(exported.payload.contains('secret-token'), false);
    expect(exported.payload.contains('secret-value'), false);
    expect(exported.payload.contains('nested-token'), false);
    final lines = exported.payload.split('\n');
    final jsonLine = lines.firstWhere((line) => line.startsWith('{'));
    final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
    expect(decoded['context']['app_secret'], LogSanitizer.redacted);
    expect(decoded['context']['nested']['token'], LogSanitizer.redacted);
    expect(File(exported.path!).readAsStringSync(), exported.payload);
  });

  test('returns empty export metadata without creating a file', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'word_repository_test_export_logs_empty_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      logger: const NoopLogger(),
    );

    final exported =
        await repository.exportLogs(minimumLevel: AppLogLevel.warning);

    expect(exported.count, 0);
    expect(exported.path, isNull);
    expect(exported.fileName, endsWith('.txt'));
    expect(exported.payload.contains('# Entries: 0'), true);
  });

  test('topUpInventoryIfNeeded loads threshold batch when DB is empty',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_topup_first_install_$ts.db',
    );
    final apiClient = _RecordingApiClient(
      learningCardItems: List.generate(20, (i) => _word('first_install_$i')),
    );
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    final result = await repository.topUpInventoryIfNeeded();

    expect(result.action, TopUpAction.thresholdTopUp);
    expect(result.loaded, 100);
    expect(apiClient.lastLearningCardsLimit, 20);
  });

  test('topUpInventoryIfNeeded loads threshold batch when unstudied is low',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_topup_hourly_$ts.db',
    );
    for (var i = 0; i < 5; i++) {
      await database.upsertWord(_word('seed_$i'));
    }
    final apiClient = _RecordingApiClient(
      learningCardItems: List.generate(3, (i) => _word('hourly_$i')),
    );
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    final result = await repository.topUpInventoryIfNeeded();

    expect(result.action, TopUpAction.thresholdTopUp);
    expect(result.loaded, 100);
    expect(apiClient.lastLearningCardsLimit, 1);
  });

  test(
      'topUpInventoryIfNeeded does nothing when pool full and unstudied healthy',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_topup_idle_$ts.db',
    );
    for (var i = 0; i < 100; i++) {
      await database.upsertWord(_word('idle_$i'));
    }
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );

    final result = await repository.topUpInventoryIfNeeded();

    expect(result.action, TopUpAction.none);
    expect(apiClient.lastLearningCardsLimit, isNull);
  });

  test(
      'topUpInventoryIfNeeded threshold top-up does not report rotation deletes',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_topup_rotation_$ts.db',
    );
    final base = DateTime.utc(2026, 5, 1);
    // 10 mastered words (oldest first)
    for (var i = 0; i < 10; i++) {
      final w = _word('mastered_$i', base.add(Duration(minutes: i)));
      await database.upsertWord(w);
      await database.markWordRememberedLowFrequency(
        word: w,
        now: base.add(Duration(minutes: i)),
      );
    }
    // Pad to reach poolFullSize=15 with no unstudied words.
    for (var i = 0; i < 5; i++) {
      final w = _word('learning_$i', base.add(Duration(hours: i + 1)));
      await database.upsertWord(w);
      await database.markWordAsLearning(
        word: w,
        now: base.add(Duration(hours: i + 1)),
      );
    }

    final apiClient = _RecordingApiClient(
      learningCardItems: List.generate(3, (i) => _word('new_$i')),
    );
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
      config: _testConfig(),
    );
    repository.initRefreshWorker('device_test');

    final result = await repository.topUpInventoryIfNeeded();

    expect(result.action, TopUpAction.thresholdTopUp);
    expect(result.deleted, 0);
    expect(result.loaded, 100);
    expect(apiClient.lastLearningCardsLimit, 1);
  });

  test('seedFromBundleIfEmpty inserts words for empty languages only',
      () async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_seed_$ts.db',
    );
    // English language already has data — should be skipped.
    await database.upsertWord(_word('existing_en_word'));
    final repository = WordRepository(
      database: database,
      apiClient: _RecordingApiClient(),
      seedLoader: _StubSeedLoader({
        'en': [_word('seed_en_skip_me')],
        'zh': [
          _word('seed_zh_a', null, 'zh'),
          _word('seed_zh_b', null, 'zh'),
        ],
        'vi': const [],
      }),
      config: _testConfig(),
    );

    final loaded =
        await repository.seedFromBundleIfEmpty(languages: ['en', 'zh', 'vi']);

    expect(loaded, 2);
    expect(await database.countWords(language: 'en'), 1,
        reason: 'existing en data is preserved');
    expect(await database.countWords(language: 'zh'), 2);
  });
}

class _StubSeedLoader extends SeedVocabularyLoader {
  _StubSeedLoader(this._wordsByLanguage) : super();

  final Map<String, List<VocabularyWord>> _wordsByLanguage;

  @override
  Future<List<VocabularyWord>> loadForLanguage(String language) async {
    return _wordsByLanguage[language] ?? const [];
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
  String? lastSyncedDeviceId;
  List<String> lastSyncedCachedServerWordIds = const [];

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

VocabularyWord _word(String id, [DateTime? timestamp, String language = 'en']) {
  final ts = timestamp ?? DateTime.utc(2026, 5, 4);
  return VocabularyWord(
    localId: id,
    serverWordId: id,
    term: id,
    language: language,
    meaningVi: 'meaning',
    partOfSpeech: 'noun',
    ipa: '/wɜːd/',
    vietnamesePronunciation: 'word',
    example: 'A sample word.',
    exampleVi: 'A sample meaning.',
    difficulty: 'A1',
    topics: const ['sample'],
    status: WordStatus.newWord,
    createdAt: ts,
    updatedAt: ts,
  );
}

AppConfig _testConfig() {
  return AppConfig(
    backendBaseUrl: 'http://unused',
    newWordTimeout: Duration.zero,
    appCredentialAppId: 'test-app',
    appCredentialSecret: 'test-secret',
    defaultLearningLanguage: 'en',
    supportedLearningLanguages: const ['en', 'zh', 'vi'],
    speakingFoundationEnabled: false,
    logLevel: 'info',
    logMaxEntries: 100,
  );
}

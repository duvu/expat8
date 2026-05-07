import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/config.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/vocabulary_refresh_worker.dart';
import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('runPrefetch marks prefetch done and upserts words', () async {
    final database = await LocalDatabase.open(
      databaseName: 'vocab_refresh_test_prefetch.db',
    );
    final apiClient = _RecordingApiClient(wordsToReturn: [
      _word('word_1'),
      _word('word_2'),
    ]);
    final worker = VocabularyRefreshWorker(
      database: database,
      apiClient: apiClient,
      deviceId: 'device_1',
      config: _testConfig(),
    );

    await worker.runPrefetch();

    final done = await database.getSetting(LocalDatabase.keyIsPrefetchDone);
    expect(done, 'true');
    final count = await database.countUnstudiedNewWords();
    expect(count, 2);
  });

  test('runPrefetch does not mark done when API fails', () async {
    final database = await LocalDatabase.open(
      databaseName: 'vocab_refresh_test_prefetch_fail.db',
    );
    final apiClient = _FailingApiClient();
    final worker = VocabularyRefreshWorker(
      database: database,
      apiClient: apiClient,
      deviceId: 'device_1',
      config: _testConfig(),
    );

    await worker.runPrefetch();

    final done = await database.getSetting(LocalDatabase.keyIsPrefetchDone);
    expect(done, isNull);
  });

  test('runDailyRefresh updates last_daily_refresh_date and upserts words', () async {
    final database = await LocalDatabase.open(
      databaseName: 'vocab_refresh_test_daily.db',
    );
    final apiClient = _RecordingApiClient(wordsToReturn: [_word('word_daily_1')]);
    final worker = VocabularyRefreshWorker(
      database: database,
      apiClient: apiClient,
      deviceId: 'device_1',
      config: _testConfig(),
    );

    await worker.runDailyRefresh();

    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final lastRefresh = await database.getSetting(LocalDatabase.keyLastDailyRefreshDate);
    expect(lastRefresh, today);
    final count = await database.countUnstudiedNewWords();
    expect(count, greaterThan(0));
  });

  test('runDailyRefresh does not update date when API fails', () async {
    final database = await LocalDatabase.open(
      databaseName: 'vocab_refresh_test_daily_fail.db',
    );
    final apiClient = _FailingApiClient();
    final worker = VocabularyRefreshWorker(
      database: database,
      apiClient: apiClient,
      deviceId: 'device_1',
      config: _testConfig(),
    );

    await worker.runDailyRefresh();

    final lastRefresh = await database.getSetting(LocalDatabase.keyLastDailyRefreshDate);
    expect(lastRefresh, isNull);
  });

  test('runProactiveRefresh upserts requested number of words', () async {
    final database = await LocalDatabase.open(
      databaseName: 'vocab_refresh_test_proactive.db',
    );
    final apiClient = _RecordingApiClient(
      wordsToReturn: List.generate(10, (i) => _word('proactive_$i')),
    );
    final worker = VocabularyRefreshWorker(
      database: database,
      apiClient: apiClient,
      deviceId: 'device_1',
      config: _testConfig(),
    );

    await worker.runProactiveRefresh(10);

    expect(apiClient.lastLimit, 10);
    final count = await database.countUnstudiedNewWords();
    expect(count, 10);
  });

  test('runProactiveRefresh logs warning and does not throw when API fails', () async {
    final database = await LocalDatabase.open(
      databaseName: 'vocab_refresh_test_proactive_fail.db',
    );
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final apiClient = _FailingApiClient();
    final worker = VocabularyRefreshWorker(
      database: database,
      apiClient: apiClient,
      deviceId: 'device_1',
      config: _testConfig(),
      logger: logger,
    );

    // Should not throw
    await worker.runProactiveRefresh(5);

    expect(
      entries.any((e) => e.event == 'vocab_refresh.proactive.error'),
      true,
    );
  });
}

AppConfig _testConfig() {
  return const AppConfig(
    backendBaseUrl: 'http://unused',
    newWordTimeout: Duration(seconds: 5),
    appCredentialAppId: 'test-app',
    appCredentialSecret: 'test-secret',
    defaultLearningLanguage: 'en',
    supportedLearningLanguages: ['en', 'zh', 'vi'],
    logLevel: 'info',
    logMaxEntries: 100,
    logRetentionDays: 1,
    vocabPrefetchLimit: 100,
    vocabDailyRefreshCount: 20,
    vocabProactiveThreshold: 100,
    vocabProactiveMinNew: 15,
  );
}

class _RecordingApiClient extends BackendApiClient {
  _RecordingApiClient({required this.wordsToReturn})
      : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  final List<VocabularyWord> wordsToReturn;
  int lastLimit = 0;
  List<String> lastExcludeIds = const [];

  @override
  Future<List<VocabularyWord>> fetchRecentWords({
    required String deviceId,
    int limit = 1000,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    List<String> excludeIds = const [],
  }) async {
    lastLimit = limit;
    lastExcludeIds = excludeIds;
    return wordsToReturn.take(limit).toList();
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
  Future<List<VocabularyWord>> fetchRecentWords({
    required String deviceId,
    int limit = 1000,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    List<String> excludeIds = const [],
  }) {
    throw BackendApiException('forced failure');
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

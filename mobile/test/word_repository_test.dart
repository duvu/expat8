import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('falls back to local new words when backend fails', () async {
    final database = await LocalDatabase.open();
    final localWord = _word('local_word');
    await database.upsertWord(localWord);
    final repository = WordRepository(
      database: database,
      apiClient: _FailingApiClient(),
    );

    final word = await repository.getNewWordWithFallback();
    expect(word?.localId, localWord.localId);
  });

  test('passes excluded server word id to backend when requesting another new word', () async {
    final database = await LocalDatabase.open();
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
    );

    await repository.getNewWordWithFallback(excludeServerWordId: 'word_1');

    expect(apiClient.lastExcludedServerWordId, 'word_1');
  });
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
  Future<List<VocabularyWord>> fetchNewWords({
    int limit = 1,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    String? excludeServerWordId,
  }) {
    throw BackendApiException('forced failure');
  }
}

class _RecordingApiClient extends BackendApiClient {
  _RecordingApiClient()
    : super(
        baseUrl: 'http://unused',
        timeout: Duration.zero,
        appId: 'test-app',
        appSecret: 'test-secret',
      );

  String? lastExcludedServerWordId;

  @override
  Future<List<VocabularyWord>> fetchNewWords({
    int limit = 1,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    String? excludeServerWordId,
  }) async {
    lastExcludedServerWordId = excludeServerWordId;
    return [];
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

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
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

  test('reports local fallback source when backend fails but local word exists', () async {
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

  test('reports miss source when backend fails and no local word exists', () async {
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
    expect(result.message, 'Could not reach the word feed and no local new word is available.');
    expect(result.error, isA<BackendApiException>());
  });

  test('passes excluded server word id to backend when requesting another new word', () async {
    final database = await LocalDatabase.open(
      databaseName: 'word_repository_test_exclusion.db',
    );
    final apiClient = _RecordingApiClient();
    final repository = WordRepository(
      database: database,
      apiClient: apiClient,
    );

    await repository.getNewWordWithFallback(excludeServerWordId: 'word_1');

    expect(apiClient.lastExcludedServerWordIds, contains('word_1'));
  });

  test('returns server proficiency after immediate rating submission', () async {
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

  test('registers user, persists session, and sends session token on learning requests', () async {
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

  test('clears local session on sign out and keeps anonymous learning available', () async {
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
    List<String> excludeServerWordIds = const [],
    String? proficiencyLevel,
    String? deviceId,
    String? sessionToken,
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

  List<String> lastExcludedServerWordIds = const [];
  String? lastSessionToken;
  bool signOutCalled = false;

  @override
  Future<List<VocabularyWord>> fetchNewWords({
    int limit = 1,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    List<String> excludeServerWordIds = const [],
    String? proficiencyLevel,
    String? deviceId,
    String? sessionToken,
  }) async {
    lastExcludedServerWordIds = excludeServerWordIds;
    lastSessionToken = sessionToken;
    return [];
  }

  @override
  Future<StudyEventResult> submitStudyEvent({
    required String deviceId,
    required Map<String, dynamic> event,
    String language = 'en',
    String? sessionToken,
  }) async {
    lastSessionToken = sessionToken;
    return StudyEventResult(
      success: true,
      eventId: event['client_event_id'] as String,
      idempotent: false,
      proficiency: const ProficiencyState(
        level: 'A2',
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

import 'dart:async';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registration success exposes feedback and active user', () async {
    final controller = LearningSessionController(
      repository: await _repository(_ControllerApiClient()),
    );

    await controller.register(
      identifier: 'learner@example.com',
      password: 'correct-password',
      displayName: 'Learner',
    );

    expect(controller.isAuthInProgress, false);
    expect(controller.userSession?.identifier, 'learner@example.com');
    expect(controller.userDisplayLabel, 'Learner');
    expect(controller.authSuccessMessage, 'Registered as Learner.');
    expect(controller.takeUserFeedbackMessage(), 'Registered as Learner.');
  });

  test(
      'registration failure leaves previous session and exposes error feedback',
      () async {
    final apiClient = _ControllerApiClient(
      registerError: BackendApiException(
        'Registration failed: 409',
        statusCode: 409,
        backendError: 'user_exists',
      ),
    );
    final controller = LearningSessionController(
      repository: await _repository(apiClient),
    );

    await controller.register(
      identifier: 'learner@example.com',
      password: 'correct-password',
    );

    expect(controller.isAuthInProgress, false);
    expect(controller.userSession, isNull);
    expect(controller.authErrorMessage,
        'An account already exists for this email.');
    expect(
      controller.takeUserFeedbackMessage(),
      'An account already exists for this email.',
    );
  });

  test('registration bad request maps to entered-details guidance', () async {
    final controller = LearningSessionController(
      repository: await _repository(
        _ControllerApiClient(
          registerError: BackendApiException(
            'Registration failed: 400',
            statusCode: 400,
            backendError: 'bad_request',
          ),
        ),
      ),
    );

    await controller.register(
      identifier: 'learner@example.com',
      password: 'short',
    );

    expect(
      controller.authErrorMessage,
      'The request was rejected. Check the entered details and try again.',
    );
  });

  test('sign-in success exposes feedback and active user', () async {
    final controller = LearningSessionController(
      repository: await _repository(_ControllerApiClient()),
    );

    await controller.signIn(
      identifier: 'learner@example.com',
      password: 'correct-password',
    );

    expect(controller.isAuthInProgress, false);
    expect(controller.userSession?.sessionToken, 'session_controller');
    expect(controller.authSuccessMessage, 'Signed in as Learner.');
    expect(controller.takeUserFeedbackMessage(), 'Signed in as Learner.');
  });

  test(
      'sign-in failure preserves previous valid session and exposes error feedback',
      () async {
    final apiClient = _ControllerApiClient();
    final controller = LearningSessionController(
      repository: await _repository(apiClient),
    );
    await controller.signIn(
      identifier: 'learner@example.com',
      password: 'correct-password',
    );
    apiClient.signInError = BackendApiException(
      'Sign-in failed: 401',
      statusCode: 401,
      backendError: 'invalid_credentials',
    );

    await controller.signIn(
      identifier: 'other@example.com',
      password: 'wrong-password',
    );

    expect(controller.isAuthInProgress, false);
    expect(controller.userSession?.identifier, 'learner@example.com');
    expect(controller.authErrorMessage, 'Email or password is incorrect.');
    expect(controller.takeUserFeedbackMessage(),
        'Email or password is incorrect.');
  });

  test(
      'sign-out failure still reports local sign-out when session is cleared locally',
      () async {
    final apiClient = _ControllerApiClient();
    final controller = LearningSessionController(
      repository: await _repository(apiClient),
    );
    await controller.signIn(
      identifier: 'learner@example.com',
      password: 'correct-password',
    );
    apiClient.signOutError =
        BackendApiException('Sign-out failed: 503', statusCode: 503);

    await controller.signOut();

    expect(controller.userSession, isNull);
    expect(
      controller.authErrorMessage,
      'Signed out locally. Server sign-out could not be confirmed.',
    );
    expect(
      controller.takeUserFeedbackMessage(),
      'Signed out locally. Server sign-out could not be confirmed.',
    );
  });

  test('new-word fallback miss clears stale current word', () async {
    final controller = LearningSessionController(
      repository: await _repository(
        _ControllerApiClient(
            fetchLearningCardsError: TimeoutException('timeout')),
      ),
    );
    controller.currentWord = _word('stale_word');

    await controller.showNewWord();

    expect(controller.isLoading, false);
    expect(controller.currentWord, isNull);
    expect(
      controller.statusMessage,
      'No learning card is available. Check connection and try again.',
    );
  });

  test('recent-review miss clears stale current word when no fallback exists',
      () async {
    final controller = LearningSessionController(
      repository: await _repository(
        _ControllerApiClient(
            fetchLearningCardsError: TimeoutException('timeout')),
      ),
    );
    controller.currentWord = _word('stale_word');

    await controller.showRecentReview();

    expect(controller.isLoading, false);
    expect(controller.currentWord, isNull);
    expect(
      controller.statusMessage,
      'No learning card is available. Check connection and try again.',
    );
  });

  test(
      'showNewWord triggers prefetch when unstudied count is below threshold',
      () async {
    // Seed the database with 5 new words (well below threshold of 100).
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_test_prefetch_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final now = DateTime.utc(2026, 5, 5);
    for (var i = 0; i < 5; i++) {
      await database.upsertWord(_word('seed_$i'));
    }
    final prefetchCalled = Completer<void>();
    final apiClient = _ControllerApiClient(
      onFetchLearningCards: () => prefetchCalled.complete(),
    );
    final controller = LearningSessionController(
      repository: WordRepository(database: database, apiClient: apiClient),
    );

    await controller.showNewWord();

    // Allow the async prefetch callback to fire.
    await prefetchCalled.future.timeout(const Duration(seconds: 3));
    expect(prefetchCalled.isCompleted, isTrue);
  });

  test('consecutive showNewWord calls show distinct words', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_test_distinct_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    // Seed 3 new words with distinct timestamps so order is deterministic.
    for (var i = 0; i < 3; i++) {
      await database.upsertWord(
        _wordAt('seed_distinct_$i', base.add(Duration(seconds: i))),
      );
    }
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(),
      ),
    );

    await controller.showNewWord();
    final first = controller.currentWord?.localId;

    await controller.showNewWord();
    final second = controller.currentWord?.localId;

    await controller.showNewWord();
    final third = controller.currentWord?.localId;

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(third, isNotNull);
    expect({first, second, third}.length, 3,
        reason: 'Each swipe should reveal a distinct new word');
  });
}

int _databaseCounter = 0;

Future<WordRepository> _repository(_ControllerApiClient apiClient) async {
  final database = await LocalDatabase.open(
    databaseName:
        'learning_session_controller_${DateTime.now().microsecondsSinceEpoch}_${_databaseCounter++}.db',
  );
  return WordRepository(database: database, apiClient: apiClient);
}

class _ControllerApiClient extends BackendApiClient {
  _ControllerApiClient({
    this.registerError,
    this.fetchLearningCardsError,
    this.onFetchLearningCards,
  }) : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  Object? registerError;
  Object? signInError;
  Object? signOutError;
  Object? fetchLearningCardsError;
  void Function()? onFetchLearningCards;

  @override
  Future<LearningCardBatch> fetchLearningCards({
    required String deviceId,
    int limit = 20,
    String targetLanguage = 'en',
    String? sessionToken,
  }) async {
    onFetchLearningCards?.call();
    final error = fetchLearningCardsError;
    if (error != null) {
      throw error;
    }
    return const LearningCardBatch(
      items: [],
      targetMix: LearningCardMix(newCount: 10, reviewCount: 0),
      actualMix: LearningCardMix(newCount: 0, reviewCount: 0),
    );
  }

  @override
  Future<ProficiencyState> fetchProficiency({
    required String deviceId,
    String language = 'en',
    String? sessionToken,
  }) async {
    return ProficiencyState.initial();
  }

  @override
  Future<UserSession> registerUser({
    required String identifier,
    required String password,
    String? displayName,
    String? deviceId,
  }) async {
    final error = registerError;
    if (error != null) {
      throw error;
    }
    return UserSession(
      userId: 'user_controller',
      identifier: identifier,
      displayName: displayName ?? 'Learner',
      sessionToken: 'session_controller',
    );
  }

  @override
  Future<UserSession> signIn({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    final error = signInError;
    if (error != null) {
      throw error;
    }
    return UserSession(
      userId: 'user_controller',
      identifier: identifier,
      displayName: 'Learner',
      sessionToken: 'session_controller',
    );
  }

  @override
  Future<void> signOut({required UserSession session}) async {
    final error = signOutError;
    if (error != null) {
      throw error;
    }
  }
}

VocabularyWord _word(String id) {
  final now = DateTime.utc(2026, 5, 5);
  return VocabularyWord(
    localId: id,
    serverWordId: id,
    term: id,
    language: 'en',
    meaningVi: 'meaning',
    partOfSpeech: 'noun',
    ipa: '/word/',
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

VocabularyWord _wordAt(String id, DateTime at) {
  return _word(id).copyWith(createdAt: at, updatedAt: at);
}

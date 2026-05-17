import 'dart:async';
import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:expat8_language_app/src/models/learning_progress.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/session/card_selection.dart';
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

  test('sign-in missing account suggests registration', () async {
    final controller = LearningSessionController(
      repository: await _repository(
        _ControllerApiClient(
          signInError: BackendApiException(
            'Sign-in failed: 401',
            statusCode: 401,
            backendError: 'invalid_credentials',
            backendReason: 'user_not_found',
          ),
        ),
      ),
    );

    await controller.signIn(
      identifier: 'missing@example.com',
      password: 'wrong-password',
    );

    expect(controller.authErrorMessage, 'No account found. Please register.');
    expect(
      controller.takeUserFeedbackMessage(),
      'No account found. Please register.',
    );
  });

  test('auth rate-limit failure uses plain-language feedback', () async {
    final controller = LearningSessionController(
      repository: await _repository(
        _ControllerApiClient(
          signInError: BackendApiException(
            'Sign-in failed: 429',
            statusCode: 429,
            backendError: 'too_many_requests',
          ),
        ),
      ),
    );

    await controller.signIn(
      identifier: 'learner@example.com',
      password: 'correct-password',
    );

    expect(
      controller.authErrorMessage,
      'Too many attempts. Please wait a moment and try again.',
    );
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

  test('new-word fallback miss still triggers inventory top-up', () async {
    final apiClient = _ControllerApiClient(
      fetchLearningCardsError: TimeoutException('timeout'),
    );
    final controller = LearningSessionController(
      repository: await _repository(apiClient),
    );

    await controller.showNewWord();
    await Future<void>.delayed(Duration.zero);

    expect(apiClient.fetchLearningCardsCallCount, 1);
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

  test('loadInitial shows a local word without waiting for proficiency fetch',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_nonblocking_load_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.upsertWord(_word('startup_local_word'));
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(
          proficiencyFuture: Completer<ProficiencyState>().future,
        ),
      ),
    );
    addTearDown(controller.dispose);

    await controller.loadInitial().timeout(const Duration(milliseconds: 500));

    expect(controller.isLoading, false);
    expect(controller.currentWord?.localId, 'startup_local_word');
  });

  test('remembered swipe advances to next local word without waiting for sync',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_nonblocking_swipe_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    await database.upsertWord(_wordAt('older_word', base));
    await database.upsertWord(
      _wordAt('newest_word', base.add(const Duration(seconds: 1))),
    );
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(
          cacheInventoryFuture: Completer<CacheInventoryResult>().future,
        ),
      ),
    );

    await controller.showNewWord();
    expect(controller.currentWord?.localId, 'newest_word');

    await controller
        .onSwipeBottomToTop()
        .timeout(const Duration(milliseconds: 500));

    expect(controller.isLoading, false);
    expect(controller.currentWord?.localId, 'older_word');
  });

  test('new-word selection falls back to learned review card and logs path',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_learned_fallback_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.now().toUtc();
    final learned = _wordAt('learned_fallback', base);
    await database.upsertWord(learned);
    await database.markWordAsLearning(word: learned, now: base);
    final entries = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => entries.add(entry),
    );
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(),
        logger: logger,
      ),
      logger: logger,
    );

    await controller.showNewWord();

    expect(controller.currentWord?.localId, 'learned_fallback');
    expect(
      entries.any((entry) => entry.event == 'session.card_selection.start'),
      true,
    );
    expect(
      entries.any(
        (entry) =>
            entry.event == 'session.card_selection.fallback' &&
            entry.context['from'] == 'new' &&
            entry.context['to'] == 'review',
      ),
      true,
    );
    expect(
      entries.any((entry) => entry.event == 'session.card_selection.selected'),
      true,
    );
  });

  test('isLoading always resets even when card-selection logging fails',
      () async {
    final throwingLogger = _ThrowingLogger();
    final controller = LearningSessionController(
      repository: await _repository(_ControllerApiClient()),
      logger: throwingLogger,
    );

    // No words anywhere — selection returns null. Logger throws on every call.
    // Without try/finally on isLoading, this would leave the controller stuck
    // and the gesture surface frozen.
    await controller.showNewWord();

    expect(controller.isLoading, false);
    expect(controller.currentWord, isNull);
  });

  test('back-to-back showNewWord calls keep gesture surface unblocked',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_back_to_back_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(),
      ),
    );

    for (var i = 0; i < 5; i += 1) {
      await controller.showNewWord();
      expect(controller.isLoading, false,
          reason: 'isLoading must reset after every selection (iter $i)');
    }
  });

  // Threshold tests (4.1–4.3): verify the unstudied < 100 fetch condition.

  test('topUpInventoryIfNeeded does NOT fetch when unstudied count is 100',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'threshold_no_fetch_100_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    for (var i = 0; i < 100; i++) {
      await database.upsertWord(
          _wordAt('threshold_100_$i', base.add(Duration(seconds: i))));
    }
    final apiClient = _ControllerApiClient();
    final repository = WordRepository(database: database, apiClient: apiClient);

    await repository.topUpInventoryIfNeeded();

    expect(apiClient.fetchLearningCardsCallCount, 0,
        reason: 'exactly 100 unstudied words should not trigger a fetch');
  });

  test('topUpInventoryIfNeeded DOES fetch when unstudied count is 99',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'threshold_fetch_99_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    for (var i = 0; i < 99; i++) {
      await database.upsertWord(
          _wordAt('threshold_99_$i', base.add(Duration(seconds: i))));
    }
    final apiClient = _ControllerApiClient();
    final repository = WordRepository(database: database, apiClient: apiClient);

    await repository.topUpInventoryIfNeeded();

    expect(apiClient.fetchLearningCardsCallCount, 1,
        reason:
            '99 unstudied words is below threshold and should trigger a fetch');
  });

  test(
      'topUpInventoryIfNeeded does NOT fetch when 200 unstudied words exist even if total < old pool size',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'threshold_no_fetch_200_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    for (var i = 0; i < 200; i++) {
      await database.upsertWord(
          _wordAt('threshold_200_$i', base.add(Duration(seconds: i))));
    }
    final apiClient = _ControllerApiClient();
    final repository = WordRepository(database: database, apiClient: apiClient);
    // total = 200, which is below the old vocabPoolFullSize of 1000,
    // but with the new condition only unstudied count matters.

    await repository.topUpInventoryIfNeeded();

    expect(apiClient.fetchLearningCardsCallCount, 0,
        reason:
            '200 unstudied words exceeds threshold; no fetch despite total < 1000');
  });

  test(
      'threshold check fires after markWordAsLearning: showing 100th word triggers a refill',
      () async {
    // Set up exactly 100 unstudied words. After showing one, count drops to 99,
    // which is below threshold, so a fetch should be triggered.
    final database = await LocalDatabase.open(
      databaseName:
          'threshold_sequencing_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    for (var i = 0; i < 100; i++) {
      await database
          .upsertWord(_wordAt('seq_word_$i', base.add(Duration(seconds: i))));
    }
    final apiClient = _ControllerApiClient();
    final controller = LearningSessionController(
      repository: WordRepository(database: database, apiClient: apiClient),
    );

    await controller.showNewWord();
    // Flush microtasks: markWordAsLearning → then → _triggerInventoryTopUp
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(apiClient.fetchLearningCardsCallCount, 1,
        reason:
            'showing the 100th word drops unstudied to 99, triggering a refill');
  });

  test('backend timeout during refill does not surface as card-selection error',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'threshold_timeout_resilience_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.upsertWord(_word('resilience_word'));
    final apiClient = _ControllerApiClient(
      fetchLearningCardsError: TimeoutException('network timeout'),
    );
    final controller = LearningSessionController(
      repository: WordRepository(database: database, apiClient: apiClient),
    );

    // Should show the local word even though refill fails.
    await controller.showNewWord();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isLoading, false);
    expect(controller.currentWord?.localId, 'resilience_word',
        reason: 'local word must be shown despite backend timeout');
    expect(controller.statusMessage, isNull,
        reason:
            'backend timeout during refill must not surface as a status message');
  });

  test('remembered swipe records too_easy event and advances locally',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_remembered_event_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    await database.upsertWord(_wordAt('older_word', base));
    await database.upsertWord(
      _wordAt('remembered_word', base.add(const Duration(seconds: 1))),
    );
    final apiClient = _ControllerApiClient();
    final controller = LearningSessionController(
      repository: WordRepository(database: database, apiClient: apiClient),
    );

    await controller.showNewWord();
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentWord?.localId, 'remembered_word');

    await controller.onSwipeBottomToTop();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.currentWord?.localId, 'older_word');
    expect(apiClient.submittedEvents.single['rating'], 'too_easy');
    final notMastered = await database.randomNotMasteredWord();
    expect(notMastered?.localId, 'older_word');
  });

  test('difficult swipe records too_hard event and advances locally', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_difficult_event_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    await database.upsertWord(_wordAt('older_word', base));
    await database.upsertWord(
      _wordAt('difficult_word', base.add(const Duration(seconds: 1))),
    );
    final apiClient = _ControllerApiClient();
    final controller = LearningSessionController(
      repository: WordRepository(database: database, apiClient: apiClient),
    );

    await controller.showNewWord();
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentWord?.localId, 'difficult_word');

    await controller.onSwipeTopToBottom();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.currentWord?.localId, 'older_word');
    expect(apiClient.submittedEvents.single['rating'], 'too_hard');
    final dueDifficult = await database.nextDifficultRelearnWord(
      DateTime.now().toUtc().add(const Duration(minutes: 11)),
    );
    expect(dueDifficult?.localId, 'difficult_word');
  });

  test('gesture study-event proficiency updates session state', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_gesture_proficiency_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.upsertWord(_word('gesture_proficiency_word'));
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(
          submitProficiency: const ProficiencyState(
            scale: 'cefr',
            level: 'A2',
            levelIndex: 1,
            levelChanged: true,
            previousLevel: 'A1',
          ),
        ),
      ),
    );

    await controller.showNewWord();
    await Future<void>.delayed(Duration.zero);
    await controller.onSwipeBottomToTop();
    for (var i = 0; i < 4; i += 1) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(controller.proficiency.level, 'A2');
    expect(controller.takeLevelChangeMessage(), 'Level changed: A1 -> A2');
  });

  test('offline gesture study-event stays queued and does not block next card',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_session_gesture_offline_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    await database.upsertWord(_wordAt('older_word', base));
    await database.upsertWord(
      _wordAt('offline_word', base.add(const Duration(seconds: 1))),
    );
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(
          submitStudyEventError: TimeoutException('offline'),
        ),
      ),
    );

    await controller.showNewWord();
    await Future<void>.delayed(Duration.zero);

    await controller
        .onSwipeBottomToTop()
        .timeout(const Duration(milliseconds: 500));
    await Future<void>.delayed(Duration.zero);

    expect(controller.currentWord?.localId, 'older_word');
    final dueEntries = await database.dueSyncEntries(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
    final payload =
        jsonDecode(dueEntries.single.payload) as Map<String, dynamic>;
    expect(payload['rating'], 'too_easy');
  });

  test('onSwipeRightToLeft persists learned state and advances locally',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'swipe_rtl_beyond_3_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    for (var i = 0; i < 5; i++) {
      await database.upsertWord(
          _wordAt('rtl_word_$i', base.add(Duration(seconds: i))));
    }
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(),
      ),
    );

    await controller.showNewWord();
    final before = controller.currentWord;

    await controller.onSwipeRightToLeft();

    expect(before, isNotNull);
    expect(controller.isLoading, false);
    expect(controller.currentWord, isNotNull);
    expect(controller.currentWord?.localId, isNot(before?.localId));
    final history = await database.getLearningHistory();
    expect(history, hasLength(1));
    expect(history.single.snapshot.localId, before!.localId);
    expect(history.single.state, LearningItemState.learned);
  });

  test('onSwipeLeftToRight keeps the current word and does not mutate state',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'swipe_rtl_fallback_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final word = _word('fallback_rtl_word');
    await database.upsertWord(word);
    await database.markWordAsLearning(
        word: word, now: DateTime.utc(2026, 5, 5));
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(),
      ),
    );

    await controller.showNewWord();
    final before = controller.currentWord;
    await controller.onSwipeLeftToRight();

    expect(controller.isLoading, false);
    expect(controller.currentWord?.localId, before?.localId);
    expect(await database.getLearningHistory(), isEmpty);
  });

  test('local history preserves the learned swipe order', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_history_order_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 5);
    await database.upsertWord(_wordAt('history_word_1', base));
    await database.upsertWord(_wordAt('history_word_2', base.add(const Duration(seconds: 1))));
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ControllerApiClient(),
      ),
    );

    await controller.showNewWord();
    final first = controller.currentWord!;
    await controller.onSwipeRightToLeft();
    final second = controller.currentWord!;
    await controller.onSwipeRightToLeft();

    final history = await database.getLearningHistory();
    expect(history, hasLength(2));
    expect(history[0].snapshot.localId, first.localId);
    expect(history[1].snapshot.localId, second.localId);
  });

  test('progress totals reflect learned remembered and difficult states', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_totals_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final now = DateTime.utc(2026, 5, 5);
    final learned = _wordAt('totals_learned', now);
    final remembered = _wordAt('totals_remembered', now);
    final difficult = _wordAt('totals_difficult', now);
    await database.upsertWord(learned);
    await database.upsertWord(remembered);
    await database.upsertWord(difficult);
    await database.markWordLearned(word: learned, now: now);
    await database.markWordRememberedLowFrequency(word: remembered, now: now);
    await database.markWordDifficultForRelearn(word: difficult, now: now);

    final totals = await database.getLearningProgressTotals();

    expect(totals.learned, 1);
    expect(totals.remembered, 1);
    expect(totals.difficult, 1);
    expect(totals.total, 3);
  });

  // canFitb tests — only depend on the VocabularyWord passed in, no async I/O
  group('canFitb', () {
    late LearningSessionController controller;

    setUp(() async {
      controller = LearningSessionController(
        repository: await _repository(_ControllerApiClient()),
      );
    });

    VocabularyWord _reviewWord({
      String term = 'reliable',
      String example =
          'She is a very reliable and trustworthy teammate at work.',
      String entryType = 'word',
      String? blankWord,
    }) {
      final now = DateTime.utc(2026, 5, 12);
      return VocabularyWord(
        localId: 'w1',
        term: term,
        language: 'en',
        meaningVi: 'đáng tin cậy',
        partOfSpeech: 'adjective',
        ipa: '/rɪˈlaɪəbl/',
        vietnamesePronunciation: 'ri-lai-uh-bol',
        example: example,
        exampleVi: 'Cô ấy là một đồng đội đáng tin cậy.',
        difficulty: 'B1',
        topics: const ['work'],
        status: WordStatus.review,
        createdAt: now,
        updatedAt: now,
        cardType: LearningCardType.review,
        entryType: entryType,
        explanation: '',
        blankWord: blankWord,
      );
    }

    test('10.1a returns false for a new card', () {
      final word = _reviewWord().copyWith(cardType: LearningCardType.newCard);
      expect(controller.canFitb(word), false);
    });

    test('10.1b returns false when example has fewer than 8 words', () {
      final word = _reviewWord(example: 'She is reliable here.');
      expect(controller.canFitb(word), false);
    });

    test('10.1c returns false when example does not contain the term', () {
      final word = _reviewWord(
        term: 'diligent',
        example: 'She is a very reliable and trustworthy teammate at work.',
      );
      expect(controller.canFitb(word), false);
    });

    test('10.1d returns false for phrase with null blankWord', () {
      final word = _reviewWord(
        entryType: 'phrase',
        term: 'break the ice',
        example: 'He told a joke to break the ice at the meeting today.',
        blankWord: null,
      );
      expect(controller.canFitb(word), false);
    });

    test('10.1e returns false for idiom with empty blankWord', () {
      final word = _reviewWord(
        entryType: 'idiom',
        term: 'break the ice',
        example: 'He told a joke to break the ice at the meeting today.',
        blankWord: '',
      );
      expect(controller.canFitb(word), false);
    });

    test('10.1f returns true for a local review word with null cardType', () {
      final word = _reviewWord().copyWith(cardType: null);
      expect(controller.canFitb(word), true);
    });

    test('10.1g returns true for a phrase with non-null blankWord', () {
      final word = _reviewWord(
        entryType: 'phrase',
        term: 'break the ice',
        example: 'He told a joke to break the ice at the meeting today.',
        blankWord: 'break the ice',
      );
      expect(controller.canFitb(word), true);
    });

    test(
        '10.1h returns true for a review selection even when cached status is learning',
        () {
      final word = _reviewWord().copyWith(status: WordStatus.learning);
      expect(controller.canFitb(word, cardKind: CardKind.review), true);
      expect(controller.canFitb(word, cardKind: CardKind.newWord), false);
    });
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
    this.signInError,
    this.signOutError,
    this.fetchLearningCardsError,
    this.submitStudyEventError,
    this.submitProficiency,
    this.proficiencyFuture,
    this.cacheInventoryFuture,
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
  Object? submitStudyEventError;
  int fetchLearningCardsCallCount = 0;
  final List<Map<String, dynamic>> submittedEvents = [];
  ProficiencyState? submitProficiency;
  Future<ProficiencyState>? proficiencyFuture;
  Future<CacheInventoryResult>? cacheInventoryFuture;

  @override
  Future<LearningCardBatch> fetchLearningCards({
    required String deviceId,
    int limit = 20,
    String targetLanguage = 'en',
    String? sessionToken,
  }) async {
    fetchLearningCardsCallCount += 1;
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
    final pending = proficiencyFuture;
    if (pending != null) {
      return await pending;
    }
    return ProficiencyState.initial();
  }

  @override
  Future<CacheInventoryResult> syncCacheInventory({
    required String deviceId,
    required List<String> serverWordIds,
    DateTime? observedAt,
    String? sessionToken,
  }) async {
    final pending = cacheInventoryFuture;
    if (pending != null) {
      return await pending;
    }
    return CacheInventoryResult(
      storedCount: serverWordIds.length,
      unknownServerWordIds: const [],
    );
  }

  @override
  Future<StudyEventResult> submitStudyEvent({
    required String deviceId,
    required Map<String, dynamic> event,
    String language = 'en',
    String? sessionToken,
  }) async {
    submittedEvents.add(event);
    final error = submitStudyEventError;
    if (error != null) {
      throw error;
    }
    return StudyEventResult(
      success: true,
      eventId: event['client_event_id'] as String?,
      idempotent: false,
      proficiency: submitProficiency ?? ProficiencyState.initial(),
    );
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

class _ThrowingLogger extends Logger {
  @override
  Future<void> log({
    required AppLogLevel level,
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  }) async {
    throw StateError('logger forced failure');
  }
}

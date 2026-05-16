import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/exam/exam_session_controller.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _ReadinessInterceptClient extends http.BaseClient {
  _ReadinessInterceptClient(
    this._delegate, {
    this.readinessResponse,
  });

  final http.Client _delegate;
  final http.Response Function(http.Request request)? readinessResponse;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request &&
        request.method == 'GET' &&
        request.url.path == '/health/ready') {
      final response = readinessResponse?.call(request) ??
          http.Response(
            jsonEncode({'ok': true, 'db': 'ok'}),
            200,
            headers: {'content-type': 'application/json'},
          );
      return http.StreamedResponse(
        Stream<List<int>>.value(response.bodyBytes),
        response.statusCode,
        contentLength: response.contentLength,
        request: request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    }
    return _delegate.send(request);
  }
}

String _makeSubmitResponse({bool passed = true}) {
  return jsonEncode({
    'attempt_id': 'att_1',
    'session_id': 'sess_1',
    'topic': 'travel',
    'language': 'en',
    'difficulty_level': null,
    'total_questions': 2,
    'correct_count': passed ? 2 : 0,
    'score_pct': passed ? 100.0 : 0.0,
    'passed': passed,
    'certificate_id': passed ? 'cert-uuid' : null,
    'created_at': '2026-05-11T12:00:00.000Z',
  });
}

String _makeStartResponse({int questionCount = 2}) {
  return jsonEncode({
    'session_id': 'sess_1',
    'topic': 'travel',
    'language': 'en',
    'question_count': questionCount,
    'expires_at': '2099-01-01T00:00:00.000Z',
    'questions': List.generate(
      questionCount,
      (i) => {
        'question_id': 'q${i + 1}',
        'ordinal': i,
        'prompt_word': 'word$i',
        'choices': ['a', 'b', 'c', 'd'],
      },
    ),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── helpers ─────────────────────────────────────────────────────────────

  final _session = const UserSession(
    sessionToken: 'tok',
    identifier: 'u@test.com',
    displayName: 'Tester',
    userId: 'uid',
  );

  Future<ExamSessionController> _makeController(
    http.Client httpClient, {
    http.Response Function(http.Request request)? readinessResponse,
  }) async {
    final database = await LocalDatabase.open(
      databaseName:
          'exam_ctrl_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = BackendApiClient(
      baseUrl: 'http://unused',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: _ReadinessInterceptClient(
        httpClient,
        readinessResponse: readinessResponse,
      ),
    );
    return ExamSessionController(apiClient: apiClient, database: database);
  }

  test('startSession sets idle state and retryable error when readiness fails',
      () async {
    var startCalled = false;
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/start')) {
        startCalled = true;
        return http.Response(
          _makeStartResponse(questionCount: 2),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 500);
    });
    final ctrl = await _makeController(
      client,
      readinessResponse: (_) => http.Response('', 503),
    );

    await ctrl.startSession(userSession: _session, language: 'en');

    expect(ctrl.state, ExamState.idle);
    expect(ctrl.errorMessage, 'Backend unavailable. Please try again.');
    expect(ctrl.session, isNull);
    expect(startCalled, false);
  });

  // ─── startSession ─────────────────────────────────────────────────────────

  test('startSession transitions to active state with questions', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'session_id': 'sess_1',
            'topic': 'travel',
            'language': 'en',
            'question_count': 2,
            'expires_at': '2099-01-01T00:00:00.000Z',
            'questions': [
              {
                'question_id': 'q1',
                'ordinal': 0,
                'prompt_word': 'journey',
                'choices': ['chuyến đi', 'bữa ăn', 'công việc', 'gia đình'],
              },
              {
                'question_id': 'q2',
                'ordinal': 1,
                'prompt_word': 'hotel',
                'choices': ['khách sạn', 'trường học', 'bệnh viện', 'chợ'],
              },
            ],
          }),
          201,
          headers: {'content-type': 'application/json'},
        ));
    final ctrl = await _makeController(client);

    expect(ctrl.state, ExamState.idle);

    await ctrl.startSession(
        userSession: _session, language: 'en');

    expect(ctrl.state, ExamState.active);
    expect(ctrl.session?.sessionId, 'sess_1');
    expect(ctrl.totalQuestions, 2);
    expect(ctrl.currentQuestionIndex, 0);
    expect(ctrl.currentQuestion?.promptWord, 'journey');
    expect(ctrl.errorMessage, isNull);
  });

  test('startSession sets idle state and error on INSUFFICIENT_WORDS',
      () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'error': 'INSUFFICIENT_WORDS',
            'message': 'Found 3, need at least 5.',
          }),
          422,
          headers: {'content-type': 'application/json'},
        ));
    final ctrl = await _makeController(client);

    await ctrl.startSession(
        userSession: _session, language: 'en');

    expect(ctrl.state, ExamState.idle);
    expect(ctrl.errorMessage, isNotNull);
    expect(ctrl.session, isNull);
  });

  test('startSession sets idle state and error on network failure', () async {
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/start')) {
        return http.Response('', 500);
      }
      return http.Response(
        jsonEncode({'ok': true, 'db': 'ok'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final ctrl = await _makeController(client);

    await ctrl.startSession(
        userSession: _session, language: 'en');

    expect(ctrl.state, ExamState.idle);
    expect(ctrl.errorMessage, 'Backend unavailable. Please try again.');
  });

  test('startSession can recover after the backend becomes healthy', () async {
    var backendReady = false;
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/start')) {
        return http.Response(
          _makeStartResponse(questionCount: 1),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 500);
    });
    final ctrl = await _makeController(
      client,
      readinessResponse: (_) => backendReady
          ? http.Response(
              jsonEncode({'ok': true, 'db': 'ok'}),
              200,
              headers: {'content-type': 'application/json'},
            )
          : http.Response('', 503),
    );

    // First attempt: readiness probe fails.
    await ctrl.startSession(userSession: _session, language: 'en');
    expect(ctrl.state, ExamState.idle);
    expect(ctrl.errorMessage, 'Backend unavailable. Please try again.');

    // Second attempt: probe succeeds, start session should proceed normally.
    backendReady = true;
    await ctrl.startSession(userSession: _session, language: 'en');

    expect(ctrl.state, ExamState.active);
    expect(ctrl.session?.sessionId, 'sess_1');
    expect(ctrl.errorMessage, isNull);
  });

  // ─── submitAnswer ─────────────────────────────────────────────────────────

  test('submitAnswer records answer for current question', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'session_id': 'sess_1',
            'topic': 'travel',
            'language': 'en',
            'question_count': 1,
            'expires_at': '2099-01-01T00:00:00.000Z',
            'questions': [
              {
                'question_id': 'q1',
                'ordinal': 0,
                'prompt_word': 'journey',
                'choices': ['chuyến đi', 'bữa ăn', 'công việc', 'gia đình'],
              },
            ],
          }),
          201,
          headers: {'content-type': 'application/json'},
        ));
    final ctrl = await _makeController(client);
    await ctrl.startSession(
        userSession: _session, language: 'en');

    expect(ctrl.hasAnsweredCurrent, false);
    ctrl.submitAnswer(2);
    expect(ctrl.hasAnsweredCurrent, true);
    expect(ctrl.currentAnswer?.selectedChoice, 2);
  });

  test('submitAnswer ignores a second call for the same question', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'session_id': 'sess_1',
            'topic': 'travel',
            'language': 'en',
            'question_count': 1,
            'expires_at': '2099-01-01T00:00:00.000Z',
            'questions': [
              {
                'question_id': 'q1',
                'ordinal': 0,
                'prompt_word': 'journey',
                'choices': ['a', 'b', 'c', 'd'],
              },
            ],
          }),
          201,
          headers: {'content-type': 'application/json'},
        ));
    final ctrl = await _makeController(client);
    await ctrl.startSession(
        userSession: _session, language: 'en');
    ctrl.submitAnswer(1);
    ctrl.submitAnswer(3); // second call — ignored
    expect(ctrl.answers.length, 1);
    expect(ctrl.currentAnswer?.selectedChoice, 1);
  });

  // ─── advance + submitSession ──────────────────────────────────────────────

  test('advance moves to next question when not on last', () async {
    int callCount = 0;
    final client = MockClient((req) async {
      callCount++;
      return http.Response(
        _makeStartResponse(questionCount: 2),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final ctrl = await _makeController(client);
    await ctrl.startSession(
        userSession: _session, language: 'en');
    ctrl.submitAnswer(0);
    await ctrl.advance(userSession: _session);
    expect(ctrl.currentQuestionIndex, 1);
    expect(ctrl.state, ExamState.active);
  });

  test('advance on last question triggers submitSession', () async {
    int callCount = 0;
    final client = MockClient((req) async {
      callCount++;
      if (req.method == 'POST' && req.url.path.endsWith('/start')) {
        return http.Response(
          _makeStartResponse(questionCount: 1),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      // submit
      return http.Response(
        _makeSubmitResponse(passed: true),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final ctrl = await _makeController(client);
    await ctrl.startSession(userSession: _session, language: 'en');
    ctrl.submitAnswer(0);
    await ctrl.advance(userSession: _session);

    // State transitions to results immediately (local-first).
    expect(ctrl.state, ExamState.results);

    // Allow the background backend call to complete.
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.result?.passed, true);
    expect(ctrl.result?.certificateId, 'cert-uuid');
  });

  test('submitSession transitions to results with fail result', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(
          _makeStartResponse(questionCount: 1),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        _makeSubmitResponse(passed: false),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final ctrl = await _makeController(client);
    await ctrl.startSession(userSession: _session, language: 'en');
    ctrl.submitAnswer(0);
    await ctrl.submitSession(userSession: _session);

    expect(ctrl.state, ExamState.results);

    // Allow the background backend call to complete.
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.result?.passed, false);
    expect(ctrl.result?.certificateId, isNull);
  });

  test('submitSession persists attempt to local database', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(
          _makeStartResponse(questionCount: 1),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        _makeSubmitResponse(passed: true),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final database = await LocalDatabase.open(
      databaseName:
          'exam_persist_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = BackendApiClient(
      baseUrl: 'http://unused',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: _ReadinessInterceptClient(client),
    );
    final ctrl =
        ExamSessionController(apiClient: apiClient, database: database);

    await ctrl.startSession(userSession: _session, language: 'en');
    ctrl.submitAnswer(0);
    await ctrl.submitSession(userSession: _session);

    expect(ctrl.state, ExamState.results);

    // Allow the background backend call to complete and update the local record.
    await Future<void>.delayed(Duration.zero);

    final stored = database.getExamAttempt('att_1');
    expect(stored, isNotNull);
    expect(stored?.passed, 1);
    expect(stored?.certificateId, 'cert-uuid');
    expect(stored?.syncStatus, 'synced');
  });

  test('submitSession marks attempt as pending before background sync completes',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'exam_pending_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(
          _makeStartResponse(questionCount: 1),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        _makeSubmitResponse(passed: true),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final apiClient = BackendApiClient(
      baseUrl: 'http://unused',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: _ReadinessInterceptClient(client),
    );
    final ctrl =
        ExamSessionController(apiClient: apiClient, database: database);

    await ctrl.startSession(userSession: _session, language: 'en');
    ctrl.submitAnswer(0);
    await ctrl.submitSession(userSession: _session);

    // Immediately after submitSession returns, state is results — user is not blocked.
    expect(ctrl.state, ExamState.results);

    // The local record already exists with syncStatus='pending';
    // the background backend call has not yet completed.
    final attempts = database.getAllExamAttempts();
    expect(attempts.length, 1);
    expect(attempts.first.syncStatus, 'pending');
    expect(ctrl.result, isNull);
  });

  test('local attempt survives a backend failure with syncStatus pending',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'exam_failure_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(
          _makeStartResponse(questionCount: 1),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      // Simulate a backend error — attempt must survive for retry.
      return http.Response('Internal Server Error', 500);
    });
    final apiClient = BackendApiClient(
      baseUrl: 'http://unused',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: _ReadinessInterceptClient(client),
    );
    final ctrl =
        ExamSessionController(apiClient: apiClient, database: database);

    await ctrl.startSession(userSession: _session, language: 'en');
    ctrl.submitAnswer(0);
    await ctrl.submitSession(userSession: _session);

    expect(ctrl.state, ExamState.results);

    // Allow the background call to fail.
    await Future<void>.delayed(Duration.zero);

    // Record is preserved with syncStatus='pending' so the retry worker can pick it up.
    final attempts = database.getAllExamAttempts();
    expect(attempts.length, 1);
    expect(attempts.first.syncStatus, 'pending');
    // No score data from backend.
    expect(ctrl.result, isNull);
  });

  // ─── reset ────────────────────────────────────────────────────────────────

  test('reset returns controller to idle state', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(
          _makeStartResponse(questionCount: 1),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        _makeSubmitResponse(passed: true),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final ctrl = await _makeController(client);
    await ctrl.startSession(userSession: _session, language: 'en');
    ctrl.submitAnswer(0);
    await ctrl.submitSession(userSession: _session);
    expect(ctrl.state, ExamState.results);

    ctrl.reset();

    expect(ctrl.state, ExamState.idle);
    expect(ctrl.session, isNull);
    expect(ctrl.result, isNull);
    expect(ctrl.answers, isEmpty);
    expect(ctrl.errorMessage, isNull);
  });
}

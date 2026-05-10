import 'dart:async';
import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/exam/exam_results_screen.dart';
import 'package:expat8_language_app/src/exam/exam_session_controller.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── helpers ─────────────────────────────────────────────────────────────

  const _session = UserSession(
    sessionToken: 'tok',
    identifier: 'u@test.com',
    displayName: 'Tester',
    userId: 'uid',
  );

  Future<ExamSessionController> _makeController(http.Client httpClient) async {
    final database = await LocalDatabase.open(
      databaseName:
          'results_screen_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = BackendApiClient(
      baseUrl: 'http://unused',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: httpClient,
    );
    return ExamSessionController(apiClient: apiClient, database: database);
  }

  String _makeStartResponse() => jsonEncode({
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
      });

  String _makeSubmitResponse({bool passed = true}) => jsonEncode({
        'attempt_id': 'att_1',
        'session_id': 'sess_1',
        'topic': 'travel',
        'language': 'en',
        'difficulty_level': null,
        'total_questions': 1,
        'correct_count': passed ? 1 : 0,
        'score_pct': passed ? 100.0 : 0.0,
        'passed': passed,
        'certificate_id': passed ? 'cert-uuid' : null,
        'created_at': '2026-05-11T12:00:00.000Z',
      });

  const _jsonHeaders = {'content-type': 'application/json'};

  // ─── 4.1: Reactive render ────────────────────────────────────────────────

  testWidgets(
      'results UI appears reactively when controller result arrives after build',
      (tester) async {
    // The results UI has enough widgets to overflow the default test viewport
    // (752 × 496). Set a phone-sized surface so the full Column fits.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final submitCompleter = Completer<http.Response>();

    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(_makeStartResponse(), 201,
            headers: _jsonHeaders);
      }
      // Submit hangs until we complete the Completer.
      return submitCompleter.future;
    });

    final controller = await _makeController(client);
    await controller.startSession(userSession: _session, topic: 'travel');
    controller.submitAnswer(0);

    // Fire submitSession without awaiting so state goes to submitting
    // immediately while the HTTP response is pending.
    // ignore: unawaited_futures
    controller.submitSession(userSession: _session);
    expect(controller.state, ExamState.submitting);

    await tester.pumpWidget(MaterialApp(
      home: ExamResultsScreen(controller: controller, userSession: _session),
    ));
    await tester.pump();

    // Spinner shown — result is not yet available.
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    expect(find.text('Exam Results'), findsNothing);

    // Complete the HTTP submit — controller sets result and notifies listeners.
    submitCompleter.complete(
        http.Response(_makeSubmitResponse(passed: true), 200,
            headers: _jsonHeaders));
    await tester.pumpAndSettle();

    // Results UI now shown without any hot-reload.
    expect(find.text('Exam Results'), findsOneWidget);
    expect(find.text('You passed!'), findsOneWidget);
  });

  // ─── 4.2: Timeout ────────────────────────────────────────────────────────

  testWidgets('timeout error UI appears after 20 seconds without a result',
      (tester) async {
    // This Completer never resolves — simulates a permanently hung submission.
    final neverCompleter = Completer<http.Response>();
    final client = MockClient((_) => neverCompleter.future);
    final controller = await _makeController(client);

    await tester.pumpWidget(MaterialApp(
      home: ExamResultsScreen(controller: controller, userSession: _session),
    ));
    await tester.pump();

    // Initially a spinner is shown (result is null, not timed out).
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    expect(find.text('Try Again'), findsNothing);

    // Advance the fake clock past the 20-second timeout.
    await tester.pump(const Duration(seconds: 21));

    // Timeout error UI must now be visible.
    expect(find.text('Exam submission timed out. Please try again.'),
        findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    // Cleanup: resolve the stalled future so the test runner is not left with
    // a pending microtask queue.
    neverCompleter.complete(http.Response('', 503));
  });

  // ─── 4.3: Submission failure error state ─────────────────────────────────

  testWidgets(
      'error UI shown when controller has submission failure (state active + errorMessage)',
      (tester) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(_makeStartResponse(), 201, headers: _jsonHeaders);
      }
      // Submit fails with a server error.
      return http.Response(
        jsonEncode({'error': 'SERVER_ERROR', 'message': 'Boom'}),
        500,
        headers: _jsonHeaders,
      );
    });

    final controller = await _makeController(client);
    await controller.startSession(userSession: _session, topic: 'travel');
    controller.submitAnswer(0);
    await controller.submitSession(userSession: _session);

    // Controller is now: state == active, errorMessage != null, result == null.
    expect(controller.state, ExamState.active);
    expect(controller.errorMessage, isNotNull);
    final errorMsg = controller.errorMessage!;

    await tester.pumpWidget(MaterialApp(
      home: ExamResultsScreen(controller: controller, userSession: _session),
    ));
    await tester.pump();

    // Error message and "Try Again" button must be visible.
    expect(find.text(errorMsg), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    // Spinner must not be shown.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ─── 4.4: Retry tap ──────────────────────────────────────────────────────

  testWidgets('tapping Try Again resets controller and pops the route',
      (tester) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(_makeStartResponse(), 201, headers: _jsonHeaders);
      }
      return http.Response(
        jsonEncode({'error': 'SERVER_ERROR', 'message': 'Boom'}),
        500,
        headers: _jsonHeaders,
      );
    });

    final controller = await _makeController(client);
    await controller.startSession(userSession: _session, topic: 'travel');
    controller.submitAnswer(0);
    await controller.submitSession(userSession: _session);

    expect(controller.state, ExamState.active);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('Home')),
    ));

    // Push ExamResultsScreen on top of the home route.
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) =>
            ExamResultsScreen(controller: controller, userSession: _session),
      ),
    );
    await tester.pumpAndSettle();

    // Error UI is showing; home is hidden beneath.
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    // Tap the retry button.
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    // Should have popped back to the home route.
    expect(find.text('Home'), findsOneWidget);
    // Controller must have been reset.
    expect(controller.state, ExamState.idle);
    expect(controller.errorMessage, isNull);
    expect(controller.result, isNull);
  });
}

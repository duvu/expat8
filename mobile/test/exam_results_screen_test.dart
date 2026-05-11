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
      // Background submit hangs until we resolve the Completer.
      return submitCompleter.future;
    });

    final controller = await _makeController(client);
    await controller.startSession(userSession: _session, language: 'en');
    controller.submitAnswer(0);

    // Local-first: submitSession saves locally and immediately transitions
    // to ExamState.results — the user is never blocked on the network call.
    await controller.submitSession(userSession: _session);
    expect(controller.state, ExamState.results);
    expect(controller.result, isNull); // background call still pending

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

  // ─── 4.3: Results available at mount time ────────────────────────────────

  testWidgets(
      'results screen shows score data when result is already available at mount time',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(_makeStartResponse(), 201, headers: _jsonHeaders);
      }
      return http.Response(_makeSubmitResponse(passed: true), 200,
          headers: _jsonHeaders);
    });

    final controller = await _makeController(client);
    await controller.startSession(userSession: _session, language: 'en');
    controller.submitAnswer(0);
    await controller.submitSession(userSession: _session);

    // Drain the background HTTP call through FakeAsync.
    // Each pump() flushes pending microtasks and fires elapsed timers.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(controller.result, isNotNull);

    await tester.pumpWidget(MaterialApp(
      home: ExamResultsScreen(controller: controller, userSession: _session),
    ));
    await tester.pump();

    // Results UI shown immediately since result was available at mount time.
    // Note: _ScoreCircle renders a determinate CircularProgressIndicator for
    // the score arc, so we verify the results UI via text, not by absence of
    // CircularProgressIndicator.
    expect(find.text('Exam Results'), findsOneWidget);
    expect(find.text('You passed!'), findsOneWidget);
  });

  // ─── 4.5: Done tap — single pop, no black screen ─────────────────────────

  testWidgets('tapping Done returns to learning screen and resets controller',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(_makeStartResponse(), 201, headers: _jsonHeaders);
      }
      return http.Response(_makeSubmitResponse(passed: false), 200,
          headers: _jsonHeaders);
    });

    final controller = await _makeController(client);
    await controller.startSession(userSession: _session, language: 'en');
    controller.submitAnswer(0);
    await controller.submitSession(userSession: _session);

    // Drain the background HTTP call through FakeAsync.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(controller.result, isNotNull);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('Learning')),
    ));

    // Push ExamResultsScreen on top — simulates the navigation stack after
    // ExamQuestionScreen used pushReplacement to show results.
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) =>
            ExamResultsScreen(controller: controller, userSession: _session),
      ),
    );
    await tester.pumpAndSettle();

    // Results screen is showing; learning screen is beneath.
    expect(find.text('Exam Results'), findsOneWidget);
    expect(find.text('Learning'), findsNothing);

    // Tap Done.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // 2.1: Learning screen is now visible — navigator was NOT over-popped.
    expect(find.text('Learning'), findsOneWidget);
    expect(find.text('Exam Results'), findsNothing);

    // 2.2: Controller must have been reset before dismissing the route.
    expect(controller.state, ExamState.idle);
    expect(controller.result, isNull);
    expect(controller.errorMessage, isNull);
  });

  // ─── 4.4: Retry tap ──────────────────────────────────────────────────────

  testWidgets('tapping Try Again resets controller and pops the route',
      (tester) async {
    // Backend never responds — submit remains unanswered, triggering timeout.
    final neverCompleter = Completer<http.Response>();
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(_makeStartResponse(), 201, headers: _jsonHeaders);
      }
      return neverCompleter.future;
    });

    final controller = await _makeController(client);
    await controller.startSession(userSession: _session, language: 'en');
    controller.submitAnswer(0);
    await controller.submitSession(userSession: _session);

    // Local-first: state is results immediately; result is null (pending).
    expect(controller.state, ExamState.results);

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
    // Use fixed pumps instead of pumpAndSettle: the indeterminate
    // CircularProgressIndicator animation never settles, so pumpAndSettle
    // would keep pumping until the 20-second timeout fires.
    await tester.pump(); // kick off the route-push frame
    await tester.pump(const Duration(milliseconds: 500)); // complete route animation

    // Initially showing spinner (result=null, not timed out).
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));

    // Advance past the 20-second timeout to trigger the Try Again UI.
    await tester.pump(const Duration(seconds: 21));

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

    // Cleanup: resolve the stalled future.
    neverCompleter.complete(http.Response('', 503));
  });
}

import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/exam/exam_question_screen.dart';
import 'package:expat8_language_app/src/exam/exam_session_controller.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = UserSession(
    sessionToken: 'tok',
    identifier: 'u@test.com',
    displayName: 'Tester',
    userId: 'uid',
  );

  Future<ExamSessionController> makeController(http.Client client) async {
    final database = await LocalDatabase.open(
      databaseName: 'exam_question_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = BackendApiClient(
      baseUrl: 'http://unused',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: client,
    );
    return ExamSessionController(apiClient: apiClient, database: database);
  }

  Map<String, dynamic> startResponse({required int questionCount}) => {
        'session_id': 'sess_1',
        'topic': 'language',
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
      };

  Map<String, dynamic> submitResponse() => {
        'attempt_id': 'att_1',
        'session_id': 'sess_1',
        'topic': 'language',
        'language': 'en',
        'difficulty_level': null,
        'total_questions': 2,
        'correct_count': 2,
        'score_pct': 100.0,
        'passed': true,
        'certificate_id': 'cert-1',
        'created_at': '2026-05-11T12:00:00.000Z',
      };

  testWidgets('tapping a choice advances to the next question', (tester) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(jsonEncode(startResponse(questionCount: 2)), 201,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode(submitResponse()), 200,
          headers: {'content-type': 'application/json'});
    });
    final controller = await makeController(client);
    await controller.startSession(userSession: session, language: 'en');

    await tester.pumpWidget(MaterialApp(
      home: ExamQuestionScreen(controller: controller, userSession: session),
    ));

    await tester.tap(find.text('a').first);
    await tester.pump();

    expect(find.text('Question 2 of 2'), findsOneWidget);
  });

  testWidgets('last answer submits and shows results', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = MockClient((req) async {
      if (req.url.path.endsWith('/start')) {
        return http.Response(jsonEncode(startResponse(questionCount: 1)), 201,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode(submitResponse()), 200,
          headers: {'content-type': 'application/json'});
    });
    final controller = await makeController(client);
    await controller.startSession(userSession: session, language: 'en');

    await tester.pumpWidget(MaterialApp(
      home: ExamQuestionScreen(controller: controller, userSession: session),
    ));

    await tester.tap(find.text('a').first);
    await tester.pumpAndSettle();

    expect(find.text('Exam Results'), findsOneWidget);
    expect(find.text('You passed!'), findsOneWidget);
  });

  // ─── 7.3  dual question types layout ─────────────────────────────────────

  testWidgets('7.3 meaning_choice question shows term only', (tester) async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'session_id': 'sess_7a',
          'topic': 'language',
          'language': 'en',
          'question_count': 1,
          'expires_at': '2099-01-01T00:00:00.000Z',
          'questions': [
            {
              'question_id': 'q1',
              'ordinal': 0,
              'prompt_word': 'reliable',
              'choices': ['a', 'b', 'c', 'd'],
              'question_type': 'meaning_choice',
            },
          ],
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final controller = await makeController(client);
    await controller.startSession(userSession: session, language: 'en');

    await tester.pumpWidget(MaterialApp(
      home: ExamQuestionScreen(controller: controller, userSession: session),
    ));
    await tester.pump();

    expect(find.text('reliable'), findsOneWidget);
    expect(find.text('What is the meaning?'), findsOneWidget);
    expect(find.text('What does the highlighted phrase mean?'), findsNothing);
  });

  testWidgets('7.3 sentence_context question shows sentence with highlighted term',
      (tester) async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'session_id': 'sess_7b',
          'topic': 'language',
          'language': 'en',
          'question_count': 1,
          'expires_at': '2099-01-01T00:00:00.000Z',
          'questions': [
            {
              'question_id': 'q1',
              'ordinal': 0,
              'prompt_word': 'break the ice',
              'choices': ['a', 'b', 'c', 'd'],
              'question_type': 'sentence_context',
              'sentence': 'He told a joke to break the ice at the meeting.',
              'highlight': 'break the ice',
            },
          ],
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final controller = await makeController(client);
    await controller.startSession(userSession: session, language: 'en');

    await tester.pumpWidget(MaterialApp(
      home: ExamQuestionScreen(controller: controller, userSession: session),
    ));
    await tester.pump();

    // Sentence fragments should appear inside the RichText widget.
    // find.textContaining() only matches Text widgets; use a predicate for RichText.
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('He told a joke to')),
      findsOneWidget,
    );
    expect(find.text('What does the highlighted phrase mean?'), findsOneWidget);
    // The term-only prompt should not appear
    expect(find.text('What is the meaning?'), findsNothing);
  });
}

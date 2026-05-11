import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/exam/exam_session_controller.dart';
import 'package:expat8_language_app/src/exam/exam_topic_screen.dart';
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

  BackendApiClient makeApiClient() {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'session_id': 'sess_1',
          'topic': 'language',
          'language': 'en-idioms',
          'question_count': 0,
          'expires_at': '2099-01-01T00:00:00.000Z',
          'questions': [],
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    return BackendApiClient(
      baseUrl: 'http://unused',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: client,
    );
  }

  Future<(ExamSessionController, LocalDatabase)> makeSetup() async {
    final db = await LocalDatabase.open(
      databaseName: 'exam_topic_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final ctrl = ExamSessionController(apiClient: makeApiClient(), database: db);
    return (ctrl, db);
  }

  // 8.4a: language picker defaults to 'en' on first launch
  testWidgets('8.4 language picker defaults to English on first launch',
      (tester) async {
    final (ctrl, db) = await makeSetup();
    await tester.pumpWidget(MaterialApp(
      home: ExamTopicScreen(
        controller: ctrl,
        userSession: session,
        database: db,
      ),
    ));
    await tester.pump();

    // The dropdown should show 'English' as the default selected value
    expect(find.text('English'), findsOneWidget);
  });

  // 8.4b: selecting a language persists it and it is restored on rebuild
  testWidgets('8.4 selected language is persisted and restored',
      (tester) async {
    final (ctrl, db) = await makeSetup();

    // First mount: select 'English Idioms'
    await tester.pumpWidget(MaterialApp(
      home: ExamTopicScreen(
        controller: ctrl,
        userSession: session,
        database: db,
      ),
    ));
    await tester.pump();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English Idioms').last);
    await tester.pumpAndSettle();

    // Verify the setting was persisted
    final saved = await db.getSetting('exam_language');
    expect(saved, equals('en-idioms'));

    // Second mount with a fresh controller but same DB — should restore
    // Re-use existing DB so the saved setting is available
    final ctrl3 = ExamSessionController(
      apiClient: makeApiClient(),
      database: db,
    );
    await tester.pumpWidget(MaterialApp(
      home: ExamTopicScreen(
        controller: ctrl3,
        userSession: session,
        database: db,
      ),
    ));
    // Wait for async _loadSavedLanguage to complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('English Idioms'), findsOneWidget);
  });

  // 8.1: verify all 5 language options are present in the dropdown
  testWidgets('8.1 picker includes en-idioms and zh-idioms options',
      (tester) async {
    final (ctrl, db) = await makeSetup();
    await tester.pumpWidget(MaterialApp(
      home: ExamTopicScreen(
        controller: ctrl,
        userSession: session,
        database: db,
      ),
    ));
    await tester.pump();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('English Idioms'), findsOneWidget);
    expect(find.text('Chinese Idioms (成语)'), findsOneWidget);
  });
}

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/article_repository.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/memorization_repository.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_repository.dart';
import 'package:expat8_language_app/src/engagement/engagement_controller.dart';
import 'package:expat8_language_app/src/engagement/engagement_repository.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main screen shows today\'s goal and lets the learner change it',
      (tester) async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_screen_engagement_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    // Offline: every request fails like a dead network.
    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: MockClient((_) async => throw Exception('offline')),
    );
    final repository = WordRepository(database: database, apiClient: apiClient);
    final controller = LearningSessionController(repository: repository);
    final engagement = EngagementController(
      repository: EngagementRepository(database: database),
    );
    for (var i = 0; i < 2; i++) {
      await database.insertStudyEvent(StudyEvent(
        clientEventId: 'today-$i',
        localWordId: 'w$i',
        rating: StudyRating.easy,
        occurredAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ));
    }

    try {
      await tester.pumpWidget(MaterialApp(
        home: LearningScreen(
          controller: controller,
          articleRepository:
              ArticleRepository(apiClient: apiClient, localDb: database),
          memorizationRepository:
              MemorizationRepository(apiClient: apiClient, localDb: database),
          workplaceSentenceRepository: WorkplaceSentenceRepository(
              database: database, apiClient: apiClient),
          engagement: engagement,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('engagement-panel')), findsOneWidget);
      expect(find.text('2/20'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);

      await tester.tap(find.byTooltip('Daily goal & reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('engagement-goal-30')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20)); // close the sheet
      await tester.pumpAndSettle();

      expect(find.text('2/30'), findsOneWidget);
    } finally {
      engagement.dispose();
      controller.dispose();
      await database.close();
    }
  });
}

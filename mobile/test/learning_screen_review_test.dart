import 'dart:math';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/article_repository.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/memorization_repository.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_repository.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:expat8_language_app/src/ui/review_exercise_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

VocabularyWord _word(String term, DateTime at) => VocabularyWord(
      localId: term,
      serverWordId: term,
      term: term,
      language: 'en',
      meaningVi: 'nghĩa $term',
      ipa: '',
      vietnamesePronunciation: '',
      example: '',
      exampleVi: '',
      difficulty: 'A2',
      topics: const [],
      status: WordStatus.newWord,
      createdAt: at,
      updatedAt: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a review exercise is answered, not swiped or rated twice',
      (tester) async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_screen_review_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: MockClient((_) async => throw Exception('offline')),
    );
    final repository = WordRepository(database: database, apiClient: apiClient);
    final controller =
        LearningSessionController(repository: repository, random: Random(2));
    final past = DateTime.now().toUtc().subtract(const Duration(days: 3));
    for (final term in ['river', 'apple', 'brave', 'quiet', 'lemon']) {
      await database.upsertWord(_word(term, past));
    }
    await database.updateWordAfterRating(
        word: _word('lemon', past), rating: StudyRating.easy, now: past);

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
        ),
      ));
      await tester.pumpAndSettle();
      // The screen loads its own first card; then bring up the due review.
      await tester.runAsync(controller.showRecentReview);
      await tester.pump();

      expect(controller.currentExercise, isNotNull);
      expect(find.byType(ReviewExerciseView), findsOneWidget);
      for (final key in ['study-difficult', 'study-remembered', 'study-next']) {
        final button = tester.widget(find.byKey(ValueKey(key))) as dynamic;
        expect(button.onPressed, isNull, reason: '$key is disabled');
      }
    } finally {
      controller.dispose();
      await database.close();
    }
  });
}

import 'dart:math';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/article_repository.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/memorization_repository.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_repository.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/review/review_exercise.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:expat8_language_app/src/ui/review_exercise_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

/// Long Vietnamese text on purpose: the tallest realistic card.
VocabularyWord _word(String term, DateTime at) => VocabularyWord(
      localId: term,
      serverWordId: term,
      term: term,
      language: 'en',
      meaningVi: 'một nghĩa tiếng Việt khá dài của từ $term để thử xuống dòng',
      ipa: '/x/',
      vietnamesePronunciation: '',
      example: 'She stayed very $term during the whole long project at work.',
      exampleVi:
          'Cô ấy rất $term trong suốt dự án dài ở chỗ làm việc của mình.',
      difficulty: 'B1',
      topics: const [],
      status: WordStatus.newWord,
      createdAt: at,
      updatedAt: at,
    );

/// A learning screen offline with five cached words, one due for review.
Future<(LearningSessionController, LocalDatabase)> _open(
    WidgetTester tester) async {
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
  await tester.pumpWidget(MaterialApp(
    home: LearningScreen(
      controller: controller,
      articleRepository:
          ArticleRepository(apiClient: apiClient, localDb: database),
      memorizationRepository:
          MemorizationRepository(apiClient: apiClient, localDb: database),
      workplaceSentenceRepository:
          WorkplaceSentenceRepository(database: database, apiClient: apiClient),
    ),
  ));
  await tester.pumpAndSettle();
  return (controller, database);
}

/// Shows due reviews until one is a [kind] exercise.
Future<void> _showExercise(WidgetTester tester,
    LearningSessionController controller, ReviewExerciseKind kind) async {
  for (var i = 0; i < 300 && controller.currentExercise?.kind != kind; i++) {
    await tester.runAsync(controller.showRecentReview);
  }
  await tester.pump();
  expect(controller.currentExercise?.kind, kind);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a review exercise is answered, not swiped or rated twice',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 891));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (controller, database) = await _open(tester);
    try {
      await _showExercise(tester, controller, ReviewExerciseKind.chooseMeaning);
      expect(find.byType(ReviewExerciseView), findsOneWidget);
      // Rating buttons make no sense mid-question: Continue takes their place,
      // locked until the question is answered.
      for (final key in ['study-difficult', 'study-remembered', 'study-next']) {
        expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
      }
      final continueButton = find.byKey(const ValueKey('review-continue'));
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      expect(find.text('Choose an answer'), findsOneWidget);

      final exercise = controller.currentExercise!;
      final right = exercise.choices.indexOf(exercise.answer);
      await tester.tap(find.byKey(ValueKey('review-choice-$right')));
      await tester.pump();
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
      expect(find.text('Continue'), findsOneWidget);

      // Only the first answer counts.
      await tester
          .tap(find.byKey(ValueKey('review-choice-${(right + 1) % 4}')));
      await tester.pump();
      expect(controller.exerciseAnswered, isTrue);

      // Continue moves on to another card.
      final shown = controller.currentWord;
      await tester.runAsync(() async {
        await tester.tap(continueButton);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      expect(controller.exerciseAnswered, isFalse);
      expect(controller.currentWord, isNotNull);
      expect(
          identical(controller.currentWord, shown) &&
              controller.currentExercise != null &&
              controller.exerciseAnswered,
          isFalse);
    } finally {
      controller.dispose();
      await database.close();
    }
  });

  // Regression: the card area does not scroll for plain cards, so after an
  // answer the feedback and the way forward (Continue) once ended up below
  // the screen and the learner was stuck. Checked on a small and a typical
  // phone, with the tallest exercise kinds and a wrong answer (longest
  // feedback).
  for (final size in const [Size(375, 667), Size(411, 891)]) {
    for (final kind in [
      ReviewExerciseKind.chooseMeaning,
      ReviewExerciseKind.fillBlank,
    ]) {
      testWidgets('Continue and the feedback stay reachable ($kind, $size)',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final (controller, database) = await _open(tester);
        try {
          await _showExercise(tester, controller, kind);
          final exercise = controller.currentExercise!;
          final wrong =
              exercise.choices.indexWhere((c) => c != exercise.answer);
          // The choices themselves must be reachable too.
          final choice = find.byKey(ValueKey('review-choice-$wrong'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();

          final screen = Offset.zero & size;
          final continueRect =
              tester.getRect(find.byKey(const ValueKey('review-continue')));
          expect(screen.contains(continueRect.center), isTrue,
              reason: 'Continue is on screen: $continueRect');
          final feedback =
              tester.getRect(find.byKey(const ValueKey('review-feedback')));
          final area = tester.getRect(find.byType(SingleChildScrollView).first);
          expect(feedback.top, greaterThanOrEqualTo(area.top - 1),
              reason: 'feedback scrolled into view: $feedback in $area');
          expect(feedback.top, lessThan(area.bottom),
              reason: 'feedback scrolled into view: $feedback in $area');
        } finally {
          controller.dispose();
          await database.close();
        }
      });
    }
  }
}

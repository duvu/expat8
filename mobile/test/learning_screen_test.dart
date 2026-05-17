import 'dart:async';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/article_repository.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_repository.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/exam/exam_question_screen.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/article.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:expat8_language_app/src/ui/articles_screen.dart';
import 'package:expat8_language_app/src/ui/learning_gesture_surface.dart';
import 'package:expat8_language_app/src/ui/learning_history_screen.dart';
import 'package:expat8_language_app/src/ui/learning_progress_stats_screen.dart';
import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:expat8_language_app/src/ui/vocabulary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders vocabulary card content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabularyCardView(word: _word()),
        ),
      ),
    );

    expect(find.text('reliable'), findsOneWidget);
    expect(find.text('dang tin cay'), findsOneWidget);
    expect(find.text('/rɪˈlaɪəbl/'), findsOneWidget);
    expect(find.text('She is a reliable teammate.'), findsOneWidget);
  });

  testWidgets('shows top-right proficiency label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              ProficiencyLevelLabel(scale: 'cefr', level: 'B1'),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Level B1'), findsOneWidget);
    expect(find.text('Easy'), findsNothing);
    expect(find.text('Too Easy'), findsNothing);
    expect(find.text('Hard'), findsNothing);
    expect(find.text('Too Hard'), findsNothing);
  });

  testWidgets('renders HSK proficiency label for Chinese learning state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              ProficiencyLevelLabel(scale: 'hsk', level: 'HSK3'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Level HSK3'), findsOneWidget);
  });

  testWidgets('language selector shows current learning language prominently',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningLanguageSelector(
            currentLanguage: 'zh',
            supportedLanguages: const ['en', 'zh', 'vi'],
            isLoading: false,
            onChanged: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Learning language'), findsOneWidget);
    expect(find.text('Chinese'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('language selector opens choices and reports selection changes',
      (tester) async {
    String? selectedLanguage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningLanguageSelector(
            currentLanguage: 'en',
            supportedLanguages: const ['en', 'zh', 'vi'],
            isLoading: false,
            onChanged: (language) async => selectedLanguage = language,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(find.text('Choose learning language'), findsOneWidget);
    expect(find.text('Chinese'), findsOneWidget);

    await tester.tap(find.text('Chinese'));
    await tester.pumpAndSettle();

    expect(selectedLanguage, 'zh');
  });

  testWidgets('drawer shows vocabulary and anonymous identity actions',
      (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: LearningDrawer(
            isSignedIn: false,
            onVocabulary: () {},
            onWorkplaceSentences: () {},
            onLogs: () {},
            onArticles: () {},
            onHistory: () {},
            onStats: () {},
            onRegister: () {},
            onSignIn: () {},
            onSignOut: () {},
          ),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Vocabulary'), findsOneWidget);
    expect(find.text('Sentences'), findsOneWidget);
    expect(find.text('Articles'), findsNothing);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('drawer shows sign out when signed in', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: LearningDrawer(
            isSignedIn: true,
            userSession: const UserSession(
              userId: 'user_1',
              identifier: 'learner@example.com',
              displayName: 'Learner',
              sessionToken: 'session_1',
            ),
            onVocabulary: () {},
            onWorkplaceSentences: () {},
            onLogs: () {},
            onArticles: () {},
            onHistory: () {},
            onStats: () {},
            onRegister: () {},
            onSignIn: () {},
            onSignOut: () {},
          ),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Learner'), findsOneWidget);
    expect(find.text('learner@example.com'), findsOneWidget);
    expect(find.text('Sentences'), findsOneWidget);
    expect(find.text('Articles'), findsOneWidget);
    expect(find.text('Register'), findsNothing);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('Take Exam stays on learning screen when backend is down',
      (tester) async {
    var startCalled = false;
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/health/ready') {
        return http.Response('', 503);
      }
      if (request.method == 'POST' && request.url.path == '/v1/exam/start') {
        startCalled = true;
        fail('Exam start should not run when readiness fails.');
      }
      fail('Unexpected request: ${request.method} ${request.url.path}');
    });

    final database = await LocalDatabase.open(
      databaseName:
          'learning_screen_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = _LearningScreenRepository(
      database: database,
      httpClient: httpClient,
    );
    final workplaceSentenceRepository = WorkplaceSentenceRepository(
      database: database,
      apiClient: repository.apiClient,
    );
    final controller = LearningSessionController(repository: repository);

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: LearningScreen(
            controller: controller,
            articleRepository: _TestArticleRepository(),
            workplaceSentenceRepository: workplaceSentenceRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Exam'));
      await tester.pumpAndSettle();

      expect(startCalled, isFalse);
      expect(find.byType(ExamQuestionScreen), findsNothing);
      expect(find.text('Backend unavailable. Please try again.'),
          findsOneWidget);
    } finally {
      controller.dispose();
      await database.close();
    }
  });

  testWidgets('drawer opens article management flow', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final articleRepository = _TestArticleRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            key: scaffoldKey,
            drawer: LearningDrawer(
              isSignedIn: true,
              userSession: const UserSession(
                userId: 'user_1',
                identifier: 'learner@example.com',
                displayName: 'Learner',
                sessionToken: 'session_1',
              ),
              onVocabulary: () {},
              onWorkplaceSentences: () {},
              onLogs: () {},
              onArticles: () {
                Navigator.of(context).maybePop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleManagementScreen(
                      repository: articleRepository,
                      sessionToken: 'session_1',
                      initialLanguage: 'en',
                      supportedLanguages: const ['en', 'zh', 'vi'],
                    ),
                  ),
                );
              },
              onHistory: () {},
              onStats: () {},
              onRegister: () {},
              onSignIn: () {},
              onSignOut: () {},
            ),
          ),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Articles'));
    await tester.pumpAndSettle();

    expect(find.text('Drawer article'), findsOneWidget);
  });

  testWidgets(
      'horizontal card gestures route right-to-left and left-to-right intents',
      (tester) async {
    var rightToLeftCount = 0;
    var leftToRightCount = 0;
    var bottomToTopCount = 0;
    var topToBottomCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LearningCardGestureSurface(
          onSwipeRightToLeft: () async => rightToLeftCount += 1,
          onSwipeLeftToRight: () async => leftToRightCount += 1,
          onSwipeBottomToTop: () async => bottomToTopCount += 1,
          onSwipeTopToBottom: () async => topToBottomCount += 1,
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    );

    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();

    expect(rightToLeftCount, 1);
    expect(leftToRightCount, 1);
    expect(bottomToTopCount, 0);
    expect(topToBottomCount, 0);
  });

  testWidgets(
      'vertical card gestures route bottom-to-top and top-to-bottom intents',
      (tester) async {
    var rightToLeftCount = 0;
    var leftToRightCount = 0;
    var bottomToTopCount = 0;
    var topToBottomCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LearningCardGestureSurface(
          onSwipeRightToLeft: () async => rightToLeftCount += 1,
          onSwipeLeftToRight: () async => leftToRightCount += 1,
          onSwipeBottomToTop: () async => bottomToTopCount += 1,
          onSwipeTopToBottom: () async => topToBottomCount += 1,
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    );

    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(0, -320), 1200);
    await tester.pumpAndSettle();
    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(0, 320), 1200);
    await tester.pumpAndSettle();

    expect(rightToLeftCount, 0);
    expect(leftToRightCount, 0);
    expect(bottomToTopCount, 1);
    expect(topToBottomCount, 1);
  });

  testWidgets(
      'gesture surface ignores duplicate swipes while callback is active',
      (tester) async {
    var rightToLeftCount = 0;
    final firstGesture = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: LearningCardGestureSurface(
          onSwipeRightToLeft: () async {
            rightToLeftCount += 1;
            await firstGesture.future;
          },
          onSwipeLeftToRight: () async {},
          onSwipeBottomToTop: () async {},
          onSwipeTopToBottom: () async {},
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    );

    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(-300, 0), 1200);
    await tester.pump();
    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(-300, 0), 1200);
    await tester.pump();

    expect(rightToLeftCount, 1);

    firstGesture.complete();
    await tester.pumpAndSettle();

    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();

    expect(rightToLeftCount, 2);
  });

  testWidgets('gesture surface recovers after async callback failure',
      (tester) async {
    var rightToLeftCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LearningCardGestureSurface(
          onSwipeRightToLeft: () async {
            rightToLeftCount += 1;
            throw StateError('forced gesture failure');
          },
          onSwipeLeftToRight: () async {},
          onSwipeBottomToTop: () async {},
          onSwipeTopToBottom: () async {},
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    );

    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(-300, 0), 1200);
    await tester.pump();
    await tester.fling(
        find.byType(LearningCardGestureSurface), const Offset(-300, 0), 1200);
    await tester.pump();

    expect(rightToLeftCount, 2);
  });

  testWidgets('drawer disables auth actions while auth is in progress',
      (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    var registerCount = 0;
    var signInCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: LearningDrawer(
            isSignedIn: false,
            isAuthInProgress: true,
            onVocabulary: () {},
            onWorkplaceSentences: () {},
            onLogs: () {},
            onArticles: () {},
            onHistory: () {},
            onStats: () {},
            onRegister: () => registerCount += 1,
            onSignIn: () => signInCount += 1,
            onSignOut: () {},
          ),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register'));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(registerCount, 0);
    expect(signInCount, 0);
  });

  testWidgets('identity dialog validates input before submitting auth',
      (tester) async {
    var submitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: IdentityDialog(
              title: 'Register',
              includeDisplayName: true,
              onSubmit: (_) => submitCount += 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(
        find.text('Password must be at least 8 characters.'), findsOneWidget);
    expect(submitCount, 0);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'not-an-email');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), '1234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(
        find.text('Password must be at least 8 characters.'), findsOneWidget);
    expect(submitCount, 0);
  });

  testWidgets('identity dialog submits valid input once', (tester) async {
    IdentityCredentials? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: IdentityDialog(
              title: 'Sign in',
              onSubmit: (credentials) => submitted = credentials,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'Learner@Example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'correct-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(submitted?.identifier, 'learner@example.com');
    expect(submitted?.password, 'correct-password');
  });

  testWidgets(
      'auth progress indicator is visible only while auth is in progress',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthProgressIndicator(isVisible: true),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthProgressIndicator(isVisible: false),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('gesture surface does not render action buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningCardGestureSurface(
            onSwipeRightToLeft: () async {},
            onSwipeLeftToRight: () async {},
            onSwipeBottomToTop: () async {},
            onSwipeTopToBottom: () async {},
            child: const SizedBox(width: 300, height: 300),
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('learning history screen shows empty state', (tester) async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_history_screen_empty_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LearningHistoryScreen(database: database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No learned items yet.'), findsOneWidget);
  });

  testWidgets('learning progress stats screen shows zero totals', (tester) async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_stats_screen_empty_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LearningProgressStatsScreen(database: database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learned'), findsOneWidget);
    expect(find.text('Remembered'), findsOneWidget);
    expect(find.text('Difficult'), findsOneWidget);
  });

  testWidgets('learning history screen preserves learned order', (tester) async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_history_screen_order_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final first = _word().copyWith(
      localId: 'history_first',
      serverWordId: 'history_first',
      term: 'alpha',
      meaningVi: 'Alpha',
    );
    final second = _word().copyWith(
      localId: 'history_second',
      serverWordId: 'history_second',
      term: 'beta',
      meaningVi: 'Beta',
    );
    await database.upsertWord(first);
    await database.upsertWord(second);
    await database.markWordLearned(word: first, now: DateTime.utc(2026, 5, 5, 1));
    await database.markWordLearned(word: second, now: DateTime.utc(2026, 5, 5, 2));

    await tester.pumpWidget(
      MaterialApp(
        home: LearningHistoryScreen(database: database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(tester.getTopLeft(find.text('alpha')).dy,
        lessThan(tester.getTopLeft(find.text('beta')).dy));
  });

  testWidgets('learning progress stats screen shows aggregated counts',
      (tester) async {
    final database = await LocalDatabase.open(
      databaseName:
          'learning_stats_screen_counts_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final learned = _word().copyWith(
      localId: 'stats_learned',
      serverWordId: 'stats_learned',
      term: 'learned',
      meaningVi: 'Learned',
    );
    final remembered = _word().copyWith(
      localId: 'stats_remembered',
      serverWordId: 'stats_remembered',
      term: 'remembered',
      meaningVi: 'Remembered',
    );
    final difficult = _word().copyWith(
      localId: 'stats_difficult',
      serverWordId: 'stats_difficult',
      term: 'difficult',
      meaningVi: 'Difficult',
    );
    await database.upsertWord(learned);
    await database.upsertWord(remembered);
    await database.upsertWord(difficult);
    await database.markWordLearned(word: learned, now: DateTime.utc(2026, 5, 5, 1));
    await database.markWordRememberedLowFrequency(
      word: remembered,
      now: DateTime.utc(2026, 5, 5, 2),
    );
    await database.markWordDifficultForRelearn(
      word: difficult,
      now: DateTime.utc(2026, 5, 5, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LearningProgressStatsScreen(database: database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learned'), findsOneWidget);
    expect(find.text('Remembered'), findsOneWidget);
    expect(find.text('Difficult'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(3));
  });
}

class _TestArticleRepository extends ArticleRepository {
  _TestArticleRepository()
      : super(
          apiClient: BackendApiClient(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'test-app',
            appSecret: 'test-secret',
          ),
        );

  @override
  Future<List<ManagedArticle>> listArticles({required String sessionToken}) async {
    return [
      ManagedArticle(
        id: 'article_1',
        title: 'Drawer article',
        sourceUrl: 'https://example.com',
        language: 'en',
        visibility: 'private',
        status: 'processed',
        createdAt: DateTime.utc(2026, 5, 10),
        updatedAt: DateTime.utc(2026, 5, 10),
      ),
    ];
  }

  @override
  Future<ManagedArticle> createArticle({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
    String? sourceUrl,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ManagedArticle> getArticle({
    required String sessionToken,
    required String articleId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ArticleVocabularyResponse> getArticleVocabulary({
    required String sessionToken,
    required String articleId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteArticle({
    required String sessionToken,
    required String articleId,
  }) {
    throw UnimplementedError();
  }
}

class _LearningScreenRepository extends WordRepository {
  _LearningScreenRepository({
    required LocalDatabase database,
    required http.Client httpClient,
  }) : super(
          database: database,
          apiClient: BackendApiClient(
            baseUrl: 'https://example.com',
            timeout: const Duration(seconds: 5),
            appId: 'test-app',
            appSecret: 'test-secret',
            httpClient: httpClient,
          ),
        );

  @override
  Future<String> getOrCreateDeviceId() async {
    return 'device_1';
  }

  @override
  Future<UserSession?> loadUserSession() async {
    return const UserSession(
      userId: 'user_1',
      identifier: 'learner@example.com',
      displayName: 'Learner',
      sessionToken: 'session_1',
    );
  }

  @override
  Future<WordLookupResult> getNewWordWithFallbackResult({
    String language = 'en',
  }) async {
    return const WordLookupResult(
      word: null,
      source: WordLookupSource.none,
      message: 'No learning card is available. Check connection and try again.',
    );
  }

  @override
  Future<ProficiencyState> fetchProficiency({
    required String deviceId,
    String language = 'en',
  }) async {
    return ProficiencyState.initial();
  }

  @override
  Future<TopUpResult> topUpInventoryIfNeeded() async {
    return const TopUpResult(action: TopUpAction.none);
  }
}

VocabularyWord _word() {
  final now = DateTime.utc(2026, 5, 4);
  return VocabularyWord(
    localId: 'word_1',
    serverWordId: 'word_1',
    term: 'reliable',
    language: 'en',
    meaningVi: 'dang tin cay',
    partOfSpeech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamesePronunciation: 'ri-lai-uh-bol',
    example: 'She is a reliable teammate.',
    exampleVi: 'Co ay la mot dong doi dang tin cay.',
    difficulty: 'B1',
    topics: const ['work'],
    status: WordStatus.newWord,
    createdAt: now,
    updatedAt: now,
  );
}

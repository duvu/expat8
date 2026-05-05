import 'dart:async';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:expat8_language_app/src/ui/vocabulary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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

  testWidgets('shows top-right proficiency label and four equal-width rating buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              ProficiencyLevelLabel(level: 'B1'),
            ],
          ),
          body: RatingButtonBar(
            onEasy: () {},
            onTooEasy: () {},
            onHard: () {},
            onTooHard: () {},
          ),
        ),
      ),
    );

    expect(find.text('Level B1'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Too Easy'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Too Hard'), findsOneWidget);

    final easyWidth = tester.getSize(find.widgetWithText(FilledButton, 'Easy')).width;
    final tooEasyWidth = tester.getSize(find.widgetWithText(FilledButton, 'Too Easy')).width;
    final hardWidth = tester.getSize(find.widgetWithText(FilledButton, 'Hard')).width;
    final tooHardWidth = tester.getSize(find.widgetWithText(FilledButton, 'Too Hard')).width;

    expect((easyWidth - tooEasyWidth).abs(), lessThan(1));
    expect((easyWidth - hardWidth).abs(), lessThan(1));
    expect((easyWidth - tooHardWidth).abs(), lessThan(1));
  });

  testWidgets('drawer shows vocabulary and anonymous identity actions', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: LearningDrawer(
            isSignedIn: false,
            onVocabulary: () {},
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
    expect(find.text('Register'), findsNothing);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('stored session renders signed-in user info on app start', (tester) async {
    final database = await LocalDatabase.open(databaseName: _databaseName('stored_session'));
    await database.saveUserSession(
      const UserSession(
        userId: 'user_1',
        identifier: 'learner@example.com',
        displayName: 'Learner',
        sessionToken: 'session_1',
      ),
    );
    final controller = LearningSessionController(
      repository: WordRepository(
        database: database,
        apiClient: _ScreenApiClient(),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: LearningScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Learner'), findsOneWidget);
    expect(find.text('learner@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('horizontal card gestures route right-to-left and left-to-right intents', (tester) async {
    var newWordCount = 0;
    var recentReviewCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LearningCardGestureSurface(
          onNewWordSwipe: () async => newWordCount += 1,
          onRecentReviewSwipe: () async => recentReviewCount += 1,
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    );

    await tester.fling(find.byType(LearningCardGestureSurface), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(LearningCardGestureSurface), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();

    expect(newWordCount, 1);
    expect(recentReviewCount, 1);
  });

  testWidgets('slow horizontal drags route to the same swipe intents', (tester) async {
    var newWordCount = 0;
    var recentReviewCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LearningCardGestureSurface(
          onNewWordSwipe: () async => newWordCount += 1,
          onRecentReviewSwipe: () async => recentReviewCount += 1,
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    );

    await tester.drag(find.byType(LearningCardGestureSurface), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(LearningCardGestureSurface), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(newWordCount, 1);
    expect(recentReviewCount, 1);
  });

  testWidgets('learning action bar exposes new word and review actions', (tester) async {
    var newWordCount = 0;
    var reviewCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningActionBar(
            isLoading: false,
            onNewWord: () async => newWordCount += 1,
            onReview: () async => reviewCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('Swipe left for a new word. Swipe right for review.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'New Word'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Review'));

    expect(newWordCount, 1);
    expect(reviewCount, 1);
  });

  testWidgets('registration success shows a SnackBar message', (tester) async {
    final controller = LearningSessionController(
      repository: await _repository(_ScreenApiClient()),
    );

    await tester.pumpWidget(MaterialApp(home: LearningScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'learner@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Learner');
    await tester.enterText(find.byType(TextField).at(2), 'correct-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Registered as Learner.'), findsOneWidget);
  });

  testWidgets('registration failure shows a SnackBar message', (tester) async {
    final controller = LearningSessionController(
      repository: await _repository(
        _ScreenApiClient(
          registerError: BackendApiException(
            'Registration failed: 409',
            statusCode: 409,
            backendError: 'user_exists',
          ),
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: LearningScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'learner@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'correct-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('An account already exists for this email.'), findsOneWidget);
  });

  testWidgets('stale cards do not hide no-card feedback', (tester) async {
    final controller = LearningSessionController(
      repository: await _repository(
        _ScreenApiClient(fetchNewWordsError: TimeoutException('timeout')),
      ),
    )..currentWord = _word();

    await tester.pumpWidget(MaterialApp(home: LearningScreen(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('reliable'), findsNothing);
    expect(
      find.text('Could not reach the word feed and no local new word is available.'),
      findsOneWidget,
    );
  });
}

int _databaseCounter = 0;

String _databaseName(String prefix) {
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_databaseCounter++}.db';
}

Future<WordRepository> _repository(_ScreenApiClient apiClient) async {
  final database = await LocalDatabase.open(databaseName: _databaseName('learning_screen'));
  return WordRepository(database: database, apiClient: apiClient);
}

class _ScreenApiClient extends BackendApiClient {
  _ScreenApiClient({
    this.registerError,
    this.fetchNewWordsError,
  }) : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  Object? registerError;
  Object? fetchNewWordsError;

  @override
  Future<List<VocabularyWord>> fetchNewWords({
    int limit = 1,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    List<String> excludeServerWordIds = const [],
    String? proficiencyLevel,
    String? deviceId,
    String? sessionToken,
  }) async {
    final error = fetchNewWordsError;
    if (error != null) {
      throw error;
    }
    return [];
  }

  @override
  Future<ProficiencyState> fetchProficiency({
    required String deviceId,
    String language = 'en',
    String? sessionToken,
  }) async {
    return ProficiencyState.initial();
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
      userId: 'user_1',
      identifier: identifier,
      displayName: displayName ?? 'Learner',
      sessionToken: 'session_1',
    );
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

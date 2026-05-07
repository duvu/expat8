import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
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
              ProficiencyLevelLabel(scale: 'cefr', level: 'B1'),
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

  testWidgets('rating buttons trigger callbacks on tap', (tester) async {
    var easyCount = 0;
    var tooEasyCount = 0;
    var hardCount = 0;
    var tooHardCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingButtonBar(
            onEasy: () => easyCount += 1,
            onTooEasy: () => tooEasyCount += 1,
            onHard: () => hardCount += 1,
            onTooHard: () => tooHardCount += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Easy'));
    await tester.tap(find.widgetWithText(FilledButton, 'Too Easy'));
    await tester.tap(find.widgetWithText(FilledButton, 'Hard'));
    await tester.tap(find.widgetWithText(FilledButton, 'Too Hard'));
    await tester.pump();

    expect(easyCount, 1);
    expect(tooEasyCount, 1);
    expect(hardCount, 1);
    expect(tooHardCount, 1);
  });

  testWidgets('renders HSK proficiency label for Chinese learning state', (tester) async {
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

  testWidgets('language selector shows current learning language prominently', (tester) async {
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
    expect(find.widgetWithText(FilledButton, 'Change'), findsOneWidget);
  });

  testWidgets('language selector opens choices and reports selection changes', (tester) async {
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

    await tester.tap(find.widgetWithText(FilledButton, 'Change'));
    await tester.pumpAndSettle();

    expect(find.text('Choose learning language'), findsOneWidget);
    expect(find.text('Chinese'), findsOneWidget);

    await tester.tap(find.text('Chinese'));
    await tester.pumpAndSettle();

    expect(selectedLanguage, 'zh');
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
            onLogs: () {},
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
            onLogs: () {},
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
    await tester.tap(find.text('New Word'));
    await tester.pump();
    await tester.tap(find.text('Review'));
    await tester.pump();

    expect(newWordCount, 1);
    expect(reviewCount, 1);
  });

  testWidgets('drawer disables auth actions while auth is in progress', (tester) async {
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
            onLogs: () {},
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

  testWidgets('identity dialog validates input before submitting auth', (tester) async {
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
    expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
    expect(submitCount, 0);

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'not-an-email');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), '1234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
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

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'Learner@Example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(submitted?.identifier, 'learner@example.com');
    expect(submitted?.password, 'correct-password');
  });

  testWidgets('auth progress indicator is visible only while auth is in progress', (tester) async {
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

  testWidgets('learning action bar disables buttons while loading', (tester) async {
    var newWordCount = 0;
    var reviewCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningActionBar(
            isLoading: true,
            onNewWord: () async => newWordCount += 1,
            onReview: () async => reviewCount += 1,
          ),
        ),
      ),
    );

    final buttonFinder = find.byWidgetPredicate((widget) => widget is OutlinedButton);
    final newWordButton = tester.widget<OutlinedButton>(buttonFinder.at(0));
    final reviewButton = tester.widget<OutlinedButton>(buttonFinder.at(1));
    expect(newWordButton.onPressed, isNull);
    expect(reviewButton.onPressed, isNull);
    expect(newWordCount, 0);
    expect(reviewCount, 0);
  });
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

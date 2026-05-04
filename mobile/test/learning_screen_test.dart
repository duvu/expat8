import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:expat8_language_app/src/ui/vocabulary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

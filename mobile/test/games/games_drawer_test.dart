import 'package:expat8_language_app/src/ui/learning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('drawer shows Games for signed-out users and opens it',
      (tester) async {
    var opened = 0;
    void noop() {}
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: LearningDrawer(
            isSignedIn: false,
            onVocabulary: noop,
            onWorkplaceSentences: noop,
            onLogs: noop,
            onArticles: noop,
            onMemorization: noop,
            onSubmittedWords: noop,
            onHistory: noop,
            onStats: noop,
            onRegister: noop,
            onSignIn: noop,
            onSignOut: noop,
            onGames: () => opened++,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Games'), findsOneWidget);

    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}

import 'package:expat8_language_app/src/widgets/study_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buttons trigger the study actions', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: StudyActionBar(
          enabled: true,
          onDifficult: () async => calls.add('difficult'),
          onRemembered: () async => calls.add('remembered'),
          onNext: () async => calls.add('next'),
          swipeHint: 'You can also swipe the card.',
        ),
      ),
    ));

    await tester.tap(find.text('Difficult'));
    await tester.tap(find.text('Remembered'));
    await tester.tap(find.text('Next'));
    expect(calls, ['difficult', 'remembered', 'next']);
    expect(find.text('You can also swipe the card.'), findsOneWidget);
  });

  testWidgets('buttons are disabled when there is no card', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: StudyActionBar(
          enabled: false,
          onDifficult: () async => called = true,
          onRemembered: () async => called = true,
          onNext: () async => called = true,
        ),
      ),
    ));
    await tester.tap(find.text('Next'));
    expect(called, isFalse);
  });
}

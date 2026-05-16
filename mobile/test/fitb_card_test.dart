import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/ui/fitb_card.dart';

VocabularyWord _reviewWord({
  String term = 'reliable',
  String example =
      'She is a very reliable and trustworthy teammate at work.',
  String exampleVi = 'Cô ấy là một đồng đội đáng tin cậy.',
  String? blankWord,
}) {
  final now = DateTime.utc(2026, 5, 12);
  return VocabularyWord(
    localId: 'fitb_w1',
    term: term,
    language: 'en',
    meaningVi: 'đáng tin cậy',
    partOfSpeech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamesePronunciation: 'ri-lai-uh-bol',
    example: example,
    exampleVi: exampleVi,
    difficulty: 'B1',
    topics: const ['work'],
    status: WordStatus.review,
    createdAt: now,
    updatedAt: now,
    cardType: LearningCardType.review,
    entryType: 'word',
    explanation: '',
    blankWord: blankWord,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  testWidgets('10.2a blanked sentence shows ___ before reveal', (tester) async {
    final word = _reviewWord();
    await tester.pumpWidget(_wrap(FitbCard(word: word)));

    // Blanked sentence text contains ___
    expect(find.textContaining('___'), findsOneWidget);
    // Term is shown
    expect(find.text('reliable'), findsWidgets);
  });

  testWidgets('10.2b exampleVi is hidden before reveal', (tester) async {
    final word = _reviewWord();
    await tester.pumpWidget(_wrap(FitbCard(word: word)));

    expect(find.text(word.exampleVi), findsNothing);
    expect(find.text('Tap to reveal'), findsOneWidget);
  });

  testWidgets('10.2c tapping reveals blank target in bold and shows exampleVi',
      (tester) async {
    final word = _reviewWord();
    await tester.pumpWidget(_wrap(FitbCard(word: word)));

    // Tap anywhere on the card
    await tester.tap(find.byType(FitbCard));
    await tester.pump();

    // exampleVi now visible
    expect(find.text(word.exampleVi), findsOneWidget);
    // Tap-to-reveal hint is gone
    expect(find.text('Tap to reveal'), findsNothing);
    // Bold span with the blank target appears inside a RichText
    final richTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((rt) => rt.text.toPlainText().contains('reliable'))
        .toList();
    expect(richTexts, isNotEmpty,
        reason: 'revealed sentence RichText should contain the blank target');
    final boldSpans = <TextSpan>[];
    void collectBold(InlineSpan span) {
      if (span is TextSpan) {
        if (span.style?.fontWeight == FontWeight.bold &&
            span.text != null &&
            span.text!.contains('reliable')) {
          boldSpans.add(span);
        }
        span.children?.forEach(collectBold);
      }
    }

    for (final rt in richTexts) {
      collectBold(rt.text);
    }
    expect(boldSpans, isNotEmpty,
        reason: 'blank target should be rendered bold after reveal');
  });

  testWidgets('10.2d blank uses blankWord for phrase entry', (tester) async {
    final word = _reviewWord(
      term: 'break the ice',
      example:
          'He told a joke to break the ice at the meeting today to help.',
      exampleVi: 'Anh ấy kể một câu chuyện cười.',
      blankWord: 'break the ice',
    );
    await tester.pumpWidget(_wrap(FitbCard(word: word)));

    expect(find.textContaining('___'), findsOneWidget);
    expect(find.text(word.exampleVi), findsNothing);
  });
}

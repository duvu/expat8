import 'package:expat8_language_app/src/models/vocabulary_word.dart';
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

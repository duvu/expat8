import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/ui/vocabulary_card.dart';

VocabularyWord _wordCard() {
  final now = DateTime.utc(2026, 5, 4);
  return VocabularyWord(
    localId: 'word_1',
    serverWordId: 'word_1',
    term: 'reliable',
    language: 'en',
    meaningVi: 'đáng tin cậy',
    partOfSpeech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamesePronunciation: 'ri-lai-uh-bol',
    example: 'She is a reliable teammate.',
    exampleVi: 'Cô ấy là một đồng đội đáng tin cậy.',
    difficulty: 'B1',
    topics: const ['work'],
    status: WordStatus.newWord,
    createdAt: now,
    updatedAt: now,
    entryType: 'word',
    explanation: '',
  );
}

VocabularyWord _phraseCard() {
  final now = DateTime.utc(2026, 5, 4);
  return VocabularyWord(
    localId: 'phrase_1',
    serverWordId: 'phrase_1',
    term: 'break the ice',
    language: 'en',
    meaningVi: 'phá vỡ bầu không khí ngại ngùng',
    partOfSpeech: '',
    ipa: '',
    vietnamesePronunciation: '',
    example: 'He told a joke to break the ice at the meeting.',
    exampleVi: '',
    difficulty: 'B2',
    topics: const [],
    status: WordStatus.newWord,
    createdAt: now,
    updatedAt: now,
    entryType: 'phrase',
    explanation: 'Dùng khi muốn tạo không khí thoải mái ở đầu buổi gặp mặt.',
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  testWidgets('6.3 word card renders IPA and POS', (tester) async {
    await tester.pumpWidget(_wrap(VocabularyCardView(word: _wordCard())));

    expect(find.text('/rɪˈlaɪəbl/'), findsOneWidget);
    expect(find.text('adjective'), findsOneWidget);
    expect(find.text('IPA'), findsOneWidget);
    expect(find.text('Vietnamese reading'), findsOneWidget);
  });

  testWidgets('6.3 phrase card does not render IPA or POS', (tester) async {
    await tester.pumpWidget(_wrap(VocabularyCardView(word: _phraseCard())));

    expect(find.text('IPA'), findsNothing);
    expect(find.text('Vietnamese reading'), findsNothing);
    // POS label row should not appear (empty string means isPhrase hides it)
    expect(find.text('adjective'), findsNothing);
  });

  testWidgets('6.3 phrase card shows explanation prominently', (tester) async {
    await tester.pumpWidget(_wrap(VocabularyCardView(word: _phraseCard())));

    expect(
      find.text('Dùng khi muốn tạo không khí thoải mái ở đầu buổi gặp mặt.'),
      findsOneWidget,
    );
  });
}

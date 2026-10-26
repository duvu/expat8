import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/article.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/ui/article_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ArticleVocabularyItem _item(String term, {String? wordId}) =>
    ArticleVocabularyItem.fromJson({
      'term_id': 't_$term',
      'display_term': term,
      'meaning_vi': 'nghĩa của $term',
      'ipa': '/x/',
      'level': 'B1',
      'status': 'approved',
      if (wordId != null)
        'word': {
          'server_word_id': wordId,
          'term': term,
          'language': 'en',
          'meaning_vi': 'nghĩa của $term',
          'ipa': '/x/',
          'vietnamese_pronunciation': '',
          'example': 'A $term example.',
          'example_vi': '',
          'difficulty': 'B1',
          'topics': <String>[],
          'created_at': '2026-01-01T00:00:00.000Z',
        },
    });

class _NoNetwork extends BackendApiClient {
  _NoNetwork()
      : super(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'a',
            appSecret: 's');

  @override
  Future<CacheInventoryResult> syncCacheInventory({
    required String deviceId,
    required List<String> serverWordIds,
    DateTime? observedAt,
    String? sessionToken,
  }) =>
      throw StateError('offline');
}

void main() {
  test('finds whole-word, case-insensitive terms; phrases win, no overlaps',
      () {
    const text = 'Take over the Resilient team. Overtake is not take over.';
    final matches = findTermMatches(
        text, [_item('take'), _item('take over'), _item('resilient')]);
    expect([for (final m in matches) text.substring(m.start, m.end)],
        ['Take over', 'Resilient', 'take over']);
    // "Overtake" contains "take" but is a different word.
    expect(matches.every((m) => m.item.displayTerm != 'take'), isTrue);
  });

  testWidgets('tapping a highlighted word adds it to review', (tester) async {
    final added = <VocabularyWord>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArticleBody(
          text: 'She stayed resilient.',
          vocabulary: [_item('resilient', wordId: 'word_resilient')],
          onAddToReview: (word) async => added.add(word),
        ),
      ),
    ));

    // Tap the highlighted term (the end of the sentence).
    final body = tester.getRect(find.byKey(const Key('article_detail_body')));
    await tester.tapAt(Offset(body.right - 30, body.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('nghĩa của resilient'), findsOneWidget);

    await tester.tap(find.byKey(const Key('article_word_add_review')));
    await tester.pumpAndSettle();
    expect(added.single.serverWordId, 'word_resilient');
    expect(find.text('Added to review'), findsOneWidget);
  });

  test('an added word is due for review right away, even offline', () async {
    final db = await LocalDatabase.open(
        databaseName:
            'article_add_${DateTime.now().microsecondsSinceEpoch}.db');
    addTearDown(db.close);
    final repo = WordRepository(database: db, apiClient: _NoNetwork());
    final now = DateTime.utc(2026, 3, 1, 9);

    await repo.addWordForReview(
        _item('resilient', wordId: 'word_resilient').word!,
        now: now);

    final due = await db.nextDueReviewWord(now);
    expect(due?.serverWordId, 'word_resilient');
    expect(due?.status, WordStatus.learning);
  });
}

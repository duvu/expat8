import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_blaster_mode.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_blaster_stats.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';

import 'word_blaster_fixtures.dart';

class _Api extends BackendApiClient {
  _Api()
      : super(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'a',
            appSecret: 's');
}

void main() {
  test('practice answers are queued and rescheduled without removing words',
      () async {
    final db = await LocalDatabase.open(
      databaseName: 'wb_learning_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    addTearDown(db.close);
    final newWord = vocab('curious', 'tò mò');
    final reviewWord = vocab('brave', 'dũng cảm', status: WordStatus.review);
    await db.addBatch([newWord, reviewWord]);
    final repo = WordRepository(database: db, apiClient: _Api());
    final now = DateTime.utc(2026, 9, 28, 12);

    await repo.recordPracticeAnswer(
        word: newWord, correct: true, source: 'game_word_blaster', now: now);
    await repo.recordPracticeAnswer(
        word: reviewWord,
        correct: false,
        source: 'game_word_blaster',
        now: now);

    final words = {for (final w in await db.wordsForLanguage('en')) w.term: w};
    expect(words, hasLength(2), reason: 'games never delete local words');
    expect(words['curious']!.status, WordStatus.learning);
    expect(words['curious']!.nextReviewAt, now.add(const Duration(days: 1)));
    expect(words['brave']!.status, WordStatus.review);
    expect(words['brave']!.nextReviewAt, now.add(const Duration(days: 1)));

    final queued = await db.dueSyncEntries(now.add(const Duration(days: 30)));
    final payloads = [
      for (final e in queued) jsonDecode(e.payload) as Map<String, dynamic>
    ];
    expect(payloads.map((p) => p['rating']), ['easy', 'hard']);
    expect(
        payloads.every(
            (p) => p['source'] == 'game_word_blaster' && p['language'] == 'en'),
        isTrue);
  });

  test('stats aggregate rounds, 7-day accuracy and most-missed words',
      () async {
    final store = WordBlasterStatsStore(InMemoryGameStorage());
    final today = DateTime(2026, 9, 28, 10);
    WordBlasterRoundSummary round(
            int correct, int answered, List<String> missed,
            {DateTime? at, int combo = 3}) =>
        WordBlasterRoundSummary(
          clientRoundId: 'r${at ?? today}$correct',
          mode: WordBlasterMode.classic,
          score: correct * 100,
          correct: correct,
          answered: answered,
          bestCombo: combo,
          wave: 1,
          durationMs: 60000,
          language: 'en',
          completedAt: (at ?? today).toUtc(),
          missedTerms: missed,
        );

    await store.recordRound(round(8, 10, ['brave', 'curious']));
    await store.recordRound(round(5, 10, ['brave'], combo: 9));
    await store.recordRound(
        round(3, 4, [], at: today.subtract(const Duration(days: 2))));

    final stats = await store.load(now: today);
    expect(stats.roundsPlayed, 3);
    expect(stats.roundsByMode[WordBlasterMode.classic], 3);
    expect(stats.totalCorrect, 16);
    expect(stats.totalAnswered, 24);
    expect(stats.bestCombo, 9);
    expect(stats.daily, hasLength(7));
    expect(stats.daily.last.answered, 20);
    expect(stats.daily[4].answered, 4);
    expect(stats.mostMissed.first.key, 'brave');
    expect(stats.mostMissed.first.value, 2);
  });

  test('round summary sync JSON matches the backend contract', () {
    final json = WordBlasterRoundSummary(
      clientRoundId: 'abc',
      mode: WordBlasterMode.timeAttack,
      score: 1200,
      correct: 10,
      answered: 12,
      bestCombo: 5,
      wave: 2,
      durationMs: 60000,
      language: 'en',
      completedAt: DateTime.utc(2026, 9, 28),
      missedTerms: const ['x'],
    ).toSyncJson();
    expect(json, {
      'client_round_id': 'abc',
      'game': 'word_blaster',
      'mode': 'timeAttack',
      'language': 'en',
      'score': 1200,
      'correct_count': 10,
      'answered_count': 12,
      'best_combo': 5,
      'wave': 2,
      'duration_ms': 60000,
      'completed_at': '2026-09-28T00:00:00.000Z',
    });
  });
}

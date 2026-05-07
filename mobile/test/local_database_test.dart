import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists words and prunes to 1000 most recent', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_prune.db',
    );
    final now = DateTime.utc(2026, 5, 4);

    for (var i = 0; i < 1001; i++) {
      await database
          .upsertWord(_word('word_$i', now.add(Duration(minutes: i))));
    }

    final removed = await database.pruneToMostRecent();
    expect(removed, 1);
    expect(await database.nextNewWord(), isNotNull);
  });

  test('stores pending study events before sync', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_sync.db',
    );
    final now = DateTime.utc(2026, 5, 4);
    await database.insertStudyEvent(
      StudyEvent(
        clientEventId: 'evt_1',
        localWordId: 'local_1',
        serverWordId: 'server_1',
        rating: StudyRating.easy,
        occurredAt: now,
        syncStatus: SyncStatus.pending,
      ),
    );

    final dueEntries = await database.dueSyncEntries(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
    expect(dueEntries, isNotEmpty);
  });

  test('persists a generated anonymous device id', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_device_id_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final first = await database.getOrCreateDeviceId(() => 'uuid_generated');
    final second = await database.getOrCreateDeviceId(() => 'device_other');

    expect(first, 'anonymous_uuid_generated');
    expect(second, 'anonymous_uuid_generated');
  });

  test('normalizes an existing raw device id to anonymous format', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_device_id_normalize.db',
    );

    await database.setSetting('device_id', 'raw_uuid');

    final value = await database.getOrCreateDeviceId(() => 'unused_uuid');

    expect(value, 'anonymous_raw_uuid');
  });

  test('persists and clears active user session', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_user_session.db',
    );
    const session = UserSession(
      userId: 'user_1',
      identifier: 'learner@example.com',
      displayName: 'Learner',
      sessionToken: 'session_1',
    );

    await database.saveUserSession(session);
    final loaded = await database.loadUserSession();
    await database.clearUserSession();
    final cleared = await database.loadUserSession();

    expect(loaded?.userId, 'user_1');
    expect(loaded?.sessionToken, 'session_1');
    expect(cleared, isNull);
  });

  test('returns the most recently learned word before due-review fallback',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_recent_review.db',
    );
    final now = DateTime.utc(2026, 5, 4);
    await database.upsertWord(
      _word('older', now.subtract(const Duration(minutes: 3))).copyWith(
        status: WordStatus.review,
        lastSeenAt: now.subtract(const Duration(minutes: 3)),
        nextReviewAt: now.add(const Duration(days: 1)),
      ),
    );
    await database.upsertWord(
      _word('newer', now.subtract(const Duration(minutes: 1))).copyWith(
        status: WordStatus.learning,
        lastSeenAt: now.subtract(const Duration(minutes: 1)),
        nextReviewAt: now.add(const Duration(days: 1)),
      ),
    );

    final word = await database.recentlyLearnedReviewWord();

    expect(word?.localId, 'newer');
  });

  test('persists logs across restart and supports filtering', () async {
    final dbName =
        'local_database_test_logs_${DateTime.now().microsecondsSinceEpoch}.db';
    final first = await LocalDatabase.open(databaseName: dbName);
    await first.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 10, 0),
        level: AppLogLevel.info,
        category: AppLogCategory.api,
        event: 'api.request',
        message: 'Request started',
        traceId: 'trace_1',
        context: const {'uri': '/v1/learning/cards'},
      ),
    );
    await first.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 10, 1),
        level: AppLogLevel.error,
        category: AppLogCategory.sync,
        event: 'sync.error',
        message: 'Sync failed',
        traceId: 'trace_2',
        context: const {'code': 500},
      ),
    );

    await first.close();
    final second = await LocalDatabase.open(databaseName: dbName);
    final filtered = await second.queryLogs(
      minimumLevel: AppLogLevel.warning,
      category: AppLogCategory.sync,
      limit: 20,
    );

    expect(filtered.length, 1);
    expect(filtered.single.event, 'sync.error');
  });

  test('prunes logs by age and max entries', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_log_prune.db',
    );

    await database.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 1),
        level: AppLogLevel.info,
        category: AppLogCategory.app,
        event: 'old_event',
        message: 'old',
        context: const {},
      ),
    );
    await database.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 12, 0),
        level: AppLogLevel.info,
        category: AppLogCategory.app,
        event: 'new_event_1',
        message: 'new',
        context: const {},
      ),
    );
    await database.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 12, 1),
        level: AppLogLevel.info,
        category: AppLogCategory.app,
        event: 'new_event_2',
        message: 'new',
        context: const {},
      ),
    );

    final removed = await database.pruneLogs(
      maxEntries: 1,
      maxAge: const Duration(days: 2),
      now: DateTime.utc(2026, 5, 6),
    );
    final remaining = await database.queryLogs(limit: 20);

    expect(removed, greaterThanOrEqualTo(2));
    expect(remaining.length, 1);
    expect(remaining.single.event, 'new_event_2');
  });

  test('prunes logs older than the 60-minute retention window', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_log_prune_60_minutes_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    await database.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 10, 59, 59),
        level: AppLogLevel.info,
        category: AppLogCategory.app,
        event: 'expired_event',
        message: 'expired',
        context: const {},
      ),
    );
    await database.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 11),
        level: AppLogLevel.info,
        category: AppLogCategory.app,
        event: 'retained_event',
        message: 'retained',
        context: const {},
      ),
    );

    final removed = await database.pruneLogs(
      maxEntries: 5000,
      maxAge: const Duration(minutes: 60),
      now: DateTime.utc(2026, 5, 5, 12),
    );
    final remaining = await database.queryLogs(limit: 20);

    expect(removed, 1);
    expect(remaining.length, 1);
    expect(remaining.single.event, 'retained_event');
  });

  test('getSetting returns null for unknown key', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_get_setting_null.db',
    );

    final value = await database.getSetting('unknown_key');
    expect(value, isNull);
  });

  test('setSetting stores and getSetting retrieves a value', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_set_get_setting.db',
    );

    await database.setSetting('my_key', 'my_value');
    final value = await database.getSetting('my_key');

    expect(value, 'my_value');
  });

  test('setSetting replaces existing value for the same key', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_set_replace_setting.db',
    );

    await database.setSetting('my_key', 'first');
    await database.setSetting('my_key', 'second');
    final value = await database.getSetting('my_key');

    expect(value, 'second');
  });

  test('countUnstudiedNewWords returns 0 for empty database', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_count_new_empty.db',
    );

    final count = await database.countUnstudiedNewWords();
    expect(count, 0);
  });

  test('countUnstudiedNewWords counts only new_word status entries', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_count_new.db',
    );
    final now = DateTime.utc(2026, 5, 4);
    await database.upsertWord(_word('new_1', now));
    await database.upsertWord(_word('new_2', now));
    await database.upsertWord(
      _word('review_1', now).copyWith(status: WordStatus.review),
    );

    final count = await database.countUnstudiedNewWords();
    expect(count, 2);
  });

  test('lists active cached server ids and deletes local words by id',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_active_cache_delete.db',
    );
    final now = DateTime.utc(2026, 5, 4);
    await database.upsertWord(_word('server_1', now));
    await database.upsertWord(_word('server_2', now));

    final beforeDelete = await database.activeCachedServerWordIds();
    final deleted = await database.deleteLocalWord('server_1');
    final afterDelete = await database.activeCachedServerWordIds();

    expect(beforeDelete, containsAll(['server_1', 'server_2']));
    expect(deleted, true);
    expect(afterDelete, ['server_2']);
  });
  test('addBatch prunes to 990 before inserting when count is at 995',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_add_batch_prune.db',
    );
    final base = DateTime.utc(2026, 5, 4);

    // Insert 995 words with distinct timestamps so pruning order is deterministic
    for (var i = 0; i < 995; i++) {
      await database
          .upsertWord(_word('existing_$i', base.add(Duration(minutes: i))));
    }

    final batch = List.generate(
      10,
      (i) => _word('new_batch_$i', base.add(Duration(minutes: 1000 + i))),
    );
    await database.addBatch(batch);

    final total = await database.countUnstudiedNewWords();
    expect(total, lessThanOrEqualTo(1000));
    // The newest 10 batch words must be present
    for (final _ in batch) {
      expect(await database.nextNewWord(), isNotNull);
    }
  });

  test('addBatch inserts all words without pruning when count is low',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_add_batch_no_prune.db',
    );
    final base = DateTime.utc(2026, 5, 4);

    for (var i = 0; i < 5; i++) {
      await database
          .upsertWord(_word('existing_$i', base.add(Duration(minutes: i))));
    }

    final batch = List.generate(
      10,
      (i) => _word('batch_$i', base.add(Duration(minutes: 100 + i))),
    );
    await database.addBatch(batch);

    final total = await database.countUnstudiedNewWords();
    expect(total, 15);
  });

  test('addBatch caps total at 1000 when adding 100 words to 950 existing',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_add_batch_950_100_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 4);

    for (var i = 0; i < 950; i++) {
      await database
          .upsertWord(_word('existing_950_$i', base.add(Duration(minutes: i))));
    }

    final batch = List.generate(
      100,
      (i) => _word('new_950_batch_$i', base.add(Duration(minutes: 1000 + i))),
    );
    await database.addBatch(batch);

    final activeIds = await database.activeCachedServerWordIds(limit: 1100);
    expect(activeIds.length, 1000);
    expect(activeIds, containsAll(batch.map((word) => word.serverWordId)));
  });

  test('addBatch caps total at 1000 when adding 100 words to 990 existing',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_add_batch_990_100_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 4);

    for (var i = 0; i < 990; i++) {
      await database
          .upsertWord(_word('existing_990_$i', base.add(Duration(minutes: i))));
    }

    final batch = List.generate(
      100,
      (i) => _word('new_990_batch_$i', base.add(Duration(minutes: 1000 + i))),
    );
    await database.addBatch(batch);

    final activeIds = await database.activeCachedServerWordIds(limit: 1100);
    expect(activeIds.length, 1000);
    expect(activeIds, containsAll(batch.map((word) => word.serverWordId)));
  });

  test('markWordRememberedLowFrequency schedules far review as mastered',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_mark_remembered.db',
    );
    final now = DateTime.utc(2026, 5, 4, 10, 0);
    final word = _word('remembered_1', now);
    await database.upsertWord(word);

    await database.markWordRememberedLowFrequency(word: word, now: now);

    final updated = await database.recentlyLearnedReviewWord();
    expect(updated, isNotNull);
    expect(updated!.status, WordStatus.mastered);
    expect(updated.nextReviewAt, isNotNull);
    expect(
        updated.nextReviewAt!.isAfter(now.add(const Duration(days: 9))), true);
  });

  test('markWordDifficultForRelearn schedules near-term relearn as learning',
      () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_mark_difficult.db',
    );
    final now = DateTime.utc(2026, 5, 4, 10, 0);
    final word = _word('difficult_1', now);
    await database.upsertWord(word);

    await database.markWordDifficultForRelearn(word: word, now: now);

    final updated = await database
        .nextDifficultRelearnWord(now.add(const Duration(hours: 1)));
    expect(updated, isNotNull);
    expect(updated!.status, WordStatus.learning);
    expect(updated.nextReviewAt, isNotNull);
    expect(updated.nextReviewAt!.isAfter(now), true);
  });

  // ── pruneToCapSmartly tests ─────────────────────────────────────────────

  test('pruneToCapSmartly removes mastered words first (pass 1)', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_prune_smart_mastered_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 4);

    // 900 new words
    for (var i = 0; i < 900; i++) {
      await database
          .upsertWord(_word('new_$i', base.add(Duration(minutes: i))));
    }
    // 150 mastered words – their presence should be pruned down to make room
    for (var i = 0; i < 150; i++) {
      await database.upsertWord(
        _word('mastered_$i', base.add(Duration(minutes: 900 + i))).copyWith(
          status: WordStatus.mastered,
          lastSeenAt: base.add(Duration(minutes: i)), // earliest first
        ),
      );
    }
    // Total = 1050, need to remove 50

    final removed = await database.pruneToCapSmartly(maxWords: 1000);

    expect(removed, 50);
    // All mastered words with lowest lastSeen indices should have been removed
    final activeIds = await database.activeCachedServerWordIds(limit: 1100);
    expect(activeIds.length, 1000);
    // The 50 least-recently-seen mastered words (mastered_0..49) should be gone
    for (var i = 0; i < 50; i++) {
      expect(activeIds.contains('mastered_$i'), isFalse);
    }
    // mastered_50..149 should still be present
    for (var i = 50; i < 150; i++) {
      expect(activeIds.contains('mastered_$i'), isTrue);
    }
  });

  test('pruneToCapSmartly removes far-review words second (pass 2)', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_prune_smart_farreview_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 4);
    final farFuture = base.add(const Duration(days: 90));
    final nearFuture = base.add(const Duration(days: 7));

    // 950 new words
    for (var i = 0; i < 950; i++) {
      await database
          .upsertWord(_word('new_$i', base.add(Duration(minutes: i))));
    }
    // 50 review words due very soon (should NOT be pruned)
    for (var i = 0; i < 50; i++) {
      await database.upsertWord(
        _word('near_review_$i', base.add(Duration(minutes: 950 + i))).copyWith(
          status: WordStatus.review,
          nextReviewAt: nearFuture,
        ),
      );
    }
    // 80 review words far in the future (should be pruned)
    for (var i = 0; i < 80; i++) {
      await database.upsertWord(
        _word('far_review_$i', base.add(Duration(minutes: 1000 + i))).copyWith(
          status: WordStatus.review,
          nextReviewAt: farFuture.add(Duration(days: i)),
        ),
      );
    }
    // Total = 1080, need to remove 80; no mastered → pass 2 handles far review

    final removed = await database.pruneToCapSmartly(maxWords: 1000);

    expect(removed, 80);
    final activeIds = await database.activeCachedServerWordIds(limit: 1200);
    expect(activeIds.length, 1000);
    // Near-review words must be kept
    for (var i = 0; i < 50; i++) {
      expect(activeIds.contains('near_review_$i'), isTrue);
    }
    // All far-review words should have been removed
    for (var i = 0; i < 80; i++) {
      expect(activeIds.contains('far_review_$i'), isFalse);
    }
  });

  test('pruneToCapSmartly skips words with pending sync events', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_prune_smart_pending_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime.utc(2026, 5, 4);

    // 990 new words
    for (var i = 0; i < 990; i++) {
      await database
          .upsertWord(_word('new_$i', base.add(Duration(minutes: i))));
    }
    // 20 mastered words, 10 of which have pending study events
    for (var i = 0; i < 20; i++) {
      await database.upsertWord(
        _word('mastered_$i', base.add(Duration(minutes: 1000 + i))).copyWith(
          status: WordStatus.mastered,
          lastSeenAt: base.add(Duration(minutes: i)),
        ),
      );
    }
    // Insert pending study events for mastered_0..9
    for (var i = 0; i < 10; i++) {
      await database.insertStudyEvent(
        StudyEvent(
          clientEventId: 'evt_pending_$i',
          localWordId: 'mastered_$i',
          serverWordId: 'mastered_$i',
          rating: StudyRating.easy,
          occurredAt: base,
          syncStatus: SyncStatus.pending,
        ),
      );
    }
    // Total = 1010, need to remove 10
    // mastered_0..9 have pending events → skip; mastered_10..19 can be removed

    final removed = await database.pruneToCapSmartly(maxWords: 1000);

    expect(removed, 10);
    final activeIds = await database.activeCachedServerWordIds(limit: 1100);
    expect(activeIds.length, 1000);
    // Words with pending events must be kept
    for (var i = 0; i < 10; i++) {
      expect(activeIds.contains('mastered_$i'), isTrue);
    }
    // Words without pending events should have been removed
    for (var i = 10; i < 20; i++) {
      expect(activeIds.contains('mastered_$i'), isFalse);
    }
  });

  // ── markWordAsLearning tests ─────────────────────────────────────────────

  test('markWordAsLearning transitions status and sets timestamps', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_mark_learning_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime(2024, 1, 1, 12, 0, 0).toUtc();
    final word = _word('word_1', base);
    await database.addBatch([word]);

    await database.markWordAsLearning(word: word, now: base);

    // word_1 should no longer appear in the newWord pool
    final newWord = await database.nextNewWord();
    expect(newWord, isNull);

    // word_1 should appear in review after 24h
    final reviewWord = await database.nextDueReviewWord(
      base.add(const Duration(hours: 25)),
    );
    expect(reviewWord?.localId, equals('word_1'));
  });

  test('nextNewWord skips word after markWordAsLearning', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'local_database_test_skip_advanced_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final base = DateTime(2024, 1, 1, 12, 0, 0).toUtc();
    final word1 = _word('word_1', base);
    final word2 = _word('word_2', base.add(const Duration(seconds: 1)));
    await database.addBatch([word1, word2]);

    // Get the first word returned and advance it
    final first = await database.nextNewWord();
    expect(first, isNotNull);
    await database.markWordAsLearning(word: first!, now: base);

    // Next nextNewWord should be the other word
    final second = await database.nextNewWord();
    expect(second?.localId, isNot(equals(first.localId)));
  });
}

VocabularyWord _word(String id, DateTime updatedAt) {
  return VocabularyWord(
    localId: id,
    serverWordId: id,
    term: id,
    language: 'en',
    meaningVi: 'meaning',
    partOfSpeech: 'noun',
    ipa: '/wɜːd/',
    vietnamesePronunciation: 'word',
    example: 'A sample word.',
    exampleVi: 'A sample meaning.',
    difficulty: 'A1',
    topics: const ['sample'],
    status: WordStatus.newWord,
    lastSeenAt: updatedAt,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

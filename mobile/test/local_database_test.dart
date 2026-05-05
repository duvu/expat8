import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('persists words and prunes to 1000 most recent', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_prune.db',
    );
    final now = DateTime.utc(2026, 5, 4);

    for (var i = 0; i < 1001; i++) {
      await database.upsertWord(_word('word_$i', now.add(Duration(minutes: i))));
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

  test('persists a generated device id', () async {
    final database = await LocalDatabase.open(
      databaseName: 'local_database_test_device_id.db',
    );

    final first = await database.getOrCreateDeviceId(() => 'device_generated');
    final second = await database.getOrCreateDeviceId(() => 'device_other');

    expect(first, 'device_generated');
    expect(second, 'device_generated');
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

  test('returns the most recently learned word before due-review fallback', () async {
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
    final dbName = 'local_database_test_logs_${DateTime.now().microsecondsSinceEpoch}.db';
    final first = await LocalDatabase.open(databaseName: dbName);
    await first.persistLogEntry(
      LogEntry(
        timestamp: DateTime.utc(2026, 5, 5, 10, 0),
        level: AppLogLevel.info,
        category: AppLogCategory.api,
        event: 'api.request',
        message: 'Request started',
        traceId: 'trace_1',
        context: const {'uri': '/v1/words/next'},
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

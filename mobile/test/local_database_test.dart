import 'package:expat8_language_app/src/data/local_database.dart';
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

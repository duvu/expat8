import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
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
    final database = await LocalDatabase.open();
    final now = DateTime.utc(2026, 5, 4);

    for (var i = 0; i < 1001; i++) {
      await database.upsertWord(_word('word_$i', now.add(Duration(minutes: i))));
    }

    final removed = await database.pruneToMostRecent();
    expect(removed, 1);
    expect(await database.nextNewWord(), isNotNull);
  });

  test('stores pending study events before sync', () async {
    final database = await LocalDatabase.open();
    final now = DateTime.utc(2026, 5, 4);
    await database.insertStudyEvent(
      StudyEvent(
        clientEventId: 'evt_1',
        localWordId: 'local_1',
        serverWordId: 'server_1',
        rating: StudyRating.remembered,
        occurredAt: now,
        syncStatus: SyncStatus.pending,
      ),
    );

    final dueEntries = await database.dueSyncEntries(now.add(const Duration(minutes: 1)));
    expect(dueEntries, isNotEmpty);
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

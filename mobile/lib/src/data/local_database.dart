import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/study_event.dart';
import '../models/sync_queue_entry.dart';
import '../models/vocabulary_word.dart';

class LocalDatabase {
  LocalDatabase(this._db);

  final Database _db;

  static Future<LocalDatabase> open() async {
    final dbPath = path.join(await getDatabasesPath(), 'expat8_words.db');
    final database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_words (
            local_id TEXT PRIMARY KEY,
            server_word_id TEXT,
            term TEXT NOT NULL,
            language TEXT NOT NULL,
            meaning_vi TEXT NOT NULL,
            part_of_speech TEXT,
            ipa TEXT NOT NULL,
            vietnamese_pronunciation TEXT NOT NULL,
            example TEXT NOT NULL,
            example_vi TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            topics TEXT NOT NULL,
            status TEXT NOT NULL,
            last_seen_at TEXT,
            next_review_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE study_events (
            client_event_id TEXT PRIMARY KEY,
            local_word_id TEXT NOT NULL,
            server_word_id TEXT,
            rating TEXT NOT NULL,
            occurred_at TEXT NOT NULL,
            sync_status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            retry_count INTEGER NOT NULL,
            next_retry_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_local_words_status ON local_words(status)');
        await db.execute(
          'CREATE INDEX idx_local_words_last_seen ON local_words(last_seen_at)',
        );
        await db.execute(
          'CREATE INDEX idx_study_events_sync_status ON study_events(sync_status)',
        );
      },
    );
    return LocalDatabase(database);
  }

  Future<void> upsertWord(VocabularyWord word) async {
    await _db.insert(
      'local_words',
      _wordToRow(word),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<VocabularyWord?> nextNewWord() async {
    final rows = await _db.query(
      'local_words',
      where: 'status = ?',
      whereArgs: [WordStatus.newWord.name],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _wordFromRow(rows.first);
  }

  Future<VocabularyWord?> nextDueReviewWord(DateTime now) async {
    final rows = await _db.query(
      'local_words',
      where: 'status IN (?, ?, ?) AND (next_review_at IS NULL OR next_review_at <= ?)',
      whereArgs: [
        WordStatus.learning.name,
        WordStatus.review.name,
        WordStatus.mastered.name,
        now.toUtc().toIso8601String(),
      ],
      orderBy: 'next_review_at ASC, last_seen_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : _wordFromRow(rows.first);
  }

  Future<List<String>> recentServerWordIds({int limit = 20}) async {
    final rows = await _db.query(
      'local_words',
      columns: ['server_word_id'],
      where: 'server_word_id IS NOT NULL',
      orderBy: 'COALESCE(last_seen_at, updated_at, created_at) DESC',
      limit: limit,
    );
    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final serverWordId = row['server_word_id'] as String?;
      if (serverWordId == null || serverWordId.isEmpty || seen.contains(serverWordId)) {
        continue;
      }
      seen.add(serverWordId);
      result.add(serverWordId);
    }
    return result;
  }

  Future<void> updateWordAfterRating({
    required VocabularyWord word,
    required StudyRating rating,
    required DateTime now,
  }) async {
    final nextReview = switch (rating) {
      StudyRating.notRemembered => now.add(const Duration(minutes: 5)),
      StudyRating.hard => now.add(const Duration(days: 1)),
      StudyRating.remembered => now.add(const Duration(days: 3)),
      StudyRating.tooEasy => now.add(const Duration(days: 7)),
    };
    final status = switch (rating) {
      StudyRating.notRemembered => WordStatus.learning,
      StudyRating.hard => WordStatus.review,
      StudyRating.remembered => WordStatus.review,
      StudyRating.tooEasy => WordStatus.mastered,
    };
    await _db.update(
      'local_words',
      {
        'status': status.name,
        'last_seen_at': now.toUtc().toIso8601String(),
        'next_review_at': nextReview.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [word.localId],
    );
  }

  Future<void> insertStudyEvent(StudyEvent event) async {
    final payload = jsonEncode(event.toSyncJson());
    await _db.transaction((txn) async {
      await txn.insert(
        'study_events',
        {
          'client_event_id': event.clientEventId,
          'local_word_id': event.localWordId,
          'server_word_id': event.serverWordId,
          'rating': event.rating.name,
          'occurred_at': event.occurredAt.toUtc().toIso8601String(),
          'sync_status': event.syncStatus.name,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.insert('sync_queue', {
        'type': 'study_event',
        'payload': payload,
        'retry_count': 0,
        'next_retry_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<List<SyncQueueEntry>> dueSyncEntries(DateTime now) async {
    final rows = await _db.query(
      'sync_queue',
      where: 'next_retry_at <= ?',
      whereArgs: [now.toUtc().toIso8601String()],
      orderBy: 'created_at ASC',
      limit: 50,
    );
    return rows.map(_queueFromRow).toList();
  }

  Future<void> markEventSynced(String clientEventId) async {
    await _db.update(
      'study_events',
      {'sync_status': SyncStatus.synced.name},
      where: 'client_event_id = ?',
      whereArgs: [clientEventId],
    );
    await _db.delete(
      'sync_queue',
      where: 'payload LIKE ?',
      whereArgs: ['%"client_event_id":"$clientEventId"%'],
    );
  }

  Future<void> scheduleRetry(SyncQueueEntry entry, DateTime now) async {
    final retryCount = entry.retryCount + 1;
    final delayMinutes = retryCount.clamp(1, 30).toInt();
    await _db.update(
      'sync_queue',
      {
        'retry_count': retryCount,
        'next_retry_at': now.add(Duration(minutes: delayMinutes)).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> pruneToMostRecent({int maxWords = 1000}) async {
    final count = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM local_words'),
        ) ??
        0;
    if (count <= maxWords) {
      return 0;
    }
    final staleRows = await _db.rawQuery(
      '''
      SELECT local_id FROM local_words
      ORDER BY COALESCE(last_seen_at, updated_at, created_at) DESC
      LIMIT -1 OFFSET ?
      ''',
      [maxWords],
    );
    final staleIds = staleRows.map((row) => row['local_id'] as String).toList();
    for (final id in staleIds) {
      await _db.delete('local_words', where: 'local_id = ?', whereArgs: [id]);
    }
    return staleIds.length;
  }

  Map<String, Object?> _wordToRow(VocabularyWord word) {
    return {
      'local_id': word.localId,
      'server_word_id': word.serverWordId,
      'term': word.term,
      'language': word.language,
      'meaning_vi': word.meaningVi,
      'part_of_speech': word.partOfSpeech,
      'ipa': word.ipa,
      'vietnamese_pronunciation': word.vietnamesePronunciation,
      'example': word.example,
      'example_vi': word.exampleVi,
      'difficulty': word.difficulty,
      'topics': jsonEncode(word.topics),
      'status': word.status.name,
      'last_seen_at': word.lastSeenAt?.toUtc().toIso8601String(),
      'next_review_at': word.nextReviewAt?.toUtc().toIso8601String(),
      'created_at': word.createdAt.toUtc().toIso8601String(),
      'updated_at': word.updatedAt.toUtc().toIso8601String(),
    };
  }

  VocabularyWord _wordFromRow(Map<String, Object?> row) {
    return VocabularyWord(
      localId: row['local_id'] as String,
      serverWordId: row['server_word_id'] as String?,
      term: row['term'] as String,
      language: row['language'] as String,
      meaningVi: row['meaning_vi'] as String,
      partOfSpeech: row['part_of_speech'] as String?,
      ipa: row['ipa'] as String,
      vietnamesePronunciation: row['vietnamese_pronunciation'] as String,
      example: row['example'] as String,
      exampleVi: row['example_vi'] as String,
      difficulty: row['difficulty'] as String,
      topics: List<String>.from(jsonDecode(row['topics'] as String) as List),
      status: WordStatus.values.byName(row['status'] as String),
      lastSeenAt: _parseDate(row['last_seen_at']),
      nextReviewAt: _parseDate(row['next_review_at']),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  SyncQueueEntry _queueFromRow(Map<String, Object?> row) {
    return SyncQueueEntry(
      id: row['id'] as int,
      type: row['type'] as String,
      payload: row['payload'] as String,
      retryCount: row['retry_count'] as int,
      nextRetryAt: DateTime.parse(row['next_retry_at'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }
}

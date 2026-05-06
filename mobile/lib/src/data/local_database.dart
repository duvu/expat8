import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../logging/logger.dart';
import '../models/study_event.dart';
import '../models/sync_queue_entry.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';

class LocalDatabase {
  LocalDatabase(this._db, {Logger? logger})
      : _logger = logger ?? const NoopLogger();

  final Database _db;
  Logger _logger;

  void attachLogger(Logger logger) {
    _logger = logger;
  }

  static Future<LocalDatabase> open(
      {String databaseName = 'expat8_words.db'}) async {
    final dbPath = path.join(await getDatabasesPath(), databaseName);
    final database = await openDatabase(
      dbPath,
      version: 3,
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
        await _createAppSettingsTable(db);
        await _createAppLogsTable(db);
        await db.execute(
            'CREATE INDEX idx_local_words_status ON local_words(status)');
        await db.execute(
          'CREATE INDEX idx_local_words_last_seen ON local_words(last_seen_at)',
        );
        await db.execute(
          'CREATE INDEX idx_study_events_sync_status ON study_events(sync_status)',
        );
        await db.execute(
          'CREATE INDEX idx_app_logs_timestamp ON app_logs(timestamp)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAppSettingsTable(db);
        }
        if (oldVersion < 3) {
          await _createAppLogsTable(db);
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_app_logs_timestamp ON app_logs(timestamp)',
          );
        }
      },
    );
    return LocalDatabase(database);
  }

  static Future<void> _createAppSettingsTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createAppLogsTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS app_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        level TEXT NOT NULL,
        category TEXT NOT NULL,
        event TEXT NOT NULL,
        message TEXT NOT NULL,
        trace_id TEXT,
        context TEXT NOT NULL
      )
    ''');
  }

  Future<void> persistLogEntry(LogEntry entry) async {
    await _db.insert('app_logs', {
      'timestamp': entry.timestamp.toUtc().toIso8601String(),
      'level': entry.level.name,
      'category': entry.category.name,
      'event': entry.event,
      'message': entry.message,
      'trace_id': entry.traceId,
      'context': jsonEncode(entry.context),
    });
  }

  Future<List<LogEntry>> queryLogs({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 200,
    int offset = 0,
  }) async {
    final where = <String>[];
    final whereArgs = <Object?>[];

    if (minimumLevel != null) {
      final allowed = AppLogLevel.values
          .where((level) => level.priority >= minimumLevel.priority)
          .map((level) => level.name)
          .toList(growable: false);
      where.add('level IN (${List.filled(allowed.length, '?').join(',')})');
      whereArgs.addAll(allowed);
    }

    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category.name);
    }
    if (from != null) {
      where.add('timestamp >= ?');
      whereArgs.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.add('timestamp <= ?');
      whereArgs.add(to.toUtc().toIso8601String());
    }

    final rows = await _db.query(
      'app_logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(_logFromRow).toList(growable: false);
  }

  Future<int> pruneLogs({
    int maxEntries = 5000,
    Duration maxAge = const Duration(days: 7),
    DateTime? now,
  }) async {
    final cutoff =
        (now ?? DateTime.now().toUtc()).subtract(maxAge).toIso8601String();
    var removed = await _db.delete(
      'app_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );

    final count = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM app_logs'),
        ) ??
        0;

    if (count > maxEntries) {
      final overflowRows = await _db.rawQuery(
        '''
        SELECT id FROM app_logs
        ORDER BY timestamp DESC, id DESC
        LIMIT -1 OFFSET ?
        ''',
        [maxEntries],
      );
      for (final row in overflowRows) {
        removed += await _db
            .delete('app_logs', where: 'id = ?', whereArgs: [row['id']]);
      }
    }
    return removed;
  }

  Future<void> upsertWord(VocabularyWord word) async {
    await _db.insert(
      'local_words',
      _wordToRow(word),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _logger.debug(
      category: AppLogCategory.database,
      event: 'local_words.upsert',
      message: 'Word upserted in local cache.',
      context: {
        'local_id': word.localId,
        'server_word_id': word.serverWordId,
      },
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
      where:
          'status IN (?, ?, ?) AND (next_review_at IS NULL OR next_review_at <= ?)',
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

  Future<VocabularyWord?> recentlyLearnedReviewWord() async {
    final rows = await _db.query(
      'local_words',
      where: 'status IN (?, ?, ?) AND last_seen_at IS NOT NULL',
      whereArgs: [
        WordStatus.learning.name,
        WordStatus.review.name,
        WordStatus.mastered.name,
      ],
      orderBy: 'last_seen_at DESC, updated_at DESC',
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
      if (serverWordId == null ||
          serverWordId.isEmpty ||
          seen.contains(serverWordId)) {
        continue;
      }
      seen.add(serverWordId);
      result.add(serverWordId);
    }
    return result;
  }

  Future<List<String>> activeCachedServerWordIds({int limit = 1000}) async {
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
      if (serverWordId == null ||
          serverWordId.isEmpty ||
          seen.contains(serverWordId)) {
        continue;
      }
      seen.add(serverWordId);
      result.add(serverWordId);
    }
    return result;
  }

  Future<bool> deleteLocalWord(String localId) async {
    final removed = await _db.delete(
      'local_words',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    return removed > 0;
  }

  Future<String> getOrCreateDeviceId(String Function() createId) async {
    final rows = await _db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['device_id'],
      limit: 1,
    );
    final existing = rows.isEmpty ? null : rows.first['value'] as String?;
    if (existing != null && existing.isNotEmpty) {
      final normalized = _anonymousDeviceId(existing);
      if (normalized != existing) {
        await setSetting('device_id', normalized);
      }
      return normalized;
    }
    final deviceId = _anonymousDeviceId(createId());
    await _db.insert(
      'app_settings',
      {'key': 'device_id', 'value': deviceId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return deviceId;
  }

  String _anonymousDeviceId(String value) {
    return value.startsWith('anonymous_') ? value : 'anonymous_$value';
  }

  Future<void> saveUserSession(UserSession session) async {
    await _db.insert(
      'app_settings',
      {'key': 'user_session', 'value': jsonEncode(session.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserSession?> loadUserSession() async {
    final rows = await _db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['user_session'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return UserSession.fromJson(
        jsonDecode(rows.first['value'] as String) as Map<String, dynamic>);
  }

  Future<void> clearUserSession() async {
    await _db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['user_session'],
    );
  }

  Future<void> updateWordAfterRating({
    required VocabularyWord word,
    required StudyRating rating,
    required DateTime now,
  }) async {
    final nextReview = switch (rating) {
      StudyRating.tooHard => now.add(const Duration(minutes: 5)),
      StudyRating.hard => now.add(const Duration(days: 1)),
      StudyRating.easy => now.add(const Duration(days: 3)),
      StudyRating.tooEasy => now.add(const Duration(days: 7)),
    };
    final status = switch (rating) {
      StudyRating.tooHard => WordStatus.learning,
      StudyRating.hard => WordStatus.review,
      StudyRating.easy => WordStatus.review,
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
          'rating': event.rating.apiValue,
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
        'next_retry_at':
            now.add(Duration(minutes: delayMinutes)).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await _logger.warning(
      category: AppLogCategory.sync,
      event: 'sync_queue.retry_scheduled',
      message: 'Sync retry scheduled for queue entry.',
      context: {
        'queue_id': entry.id,
        'retry_count': retryCount,
      },
    );
  }

  // Settings key constants
  static const String keyIsPrefetchDone = 'is_prefetch_done';
  static const String keyLastDailyRefreshDate = 'last_daily_refresh_date';
  static const String keyWordsStudiedSinceLastRefresh =
      'words_studied_since_last_refresh';

  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> countUnstudiedNewWords() async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM local_words WHERE status = ?',
            [WordStatus.newWord.name],
          ),
        ) ??
        0;
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

  LogEntry _logFromRow(Map<String, Object?> row) {
    return LogEntry(
      id: row['id'] as int,
      timestamp: DateTime.parse(row['timestamp'] as String).toUtc(),
      level: AppLogLevel.fromName(row['level'] as String),
      category: AppLogCategory.values.byName(row['category'] as String),
      event: row['event'] as String,
      message: row['message'] as String,
      traceId: row['trace_id'] as String?,
      context: Map<String, Object?>.from(
        jsonDecode(row['context'] as String) as Map<String, dynamic>,
      ),
    );
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }
}

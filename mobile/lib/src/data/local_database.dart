import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../objectbox.g.dart';
import '../logging/logger.dart';
import '../models/study_event.dart';
import '../models/sync_queue_entry.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';
import 'local_database_entities.dart';

class LocalDatabase {
  LocalDatabase(this._store, {Logger? logger})
      : _logger = logger ?? const NoopLogger(),
        _localWords = _store.box<LocalWordEntity>(),
        _studyEvents = _store.box<StudyEventEntity>(),
        _syncQueue = _store.box<SyncQueueEntity>(),
        _settings = _store.box<AppSettingEntity>(),
        _logs = _store.box<AppLogEntity>(),
        _speakingPrompts = _store.box<SpeakingPromptEntity>(),
        _speakingAttempts = _store.box<SpeakingAttemptEntity>();

  final Store _store;
  Logger _logger;

  final Box<LocalWordEntity> _localWords;
  final Box<StudyEventEntity> _studyEvents;
  final Box<SyncQueueEntity> _syncQueue;
  final Box<AppSettingEntity> _settings;
  final Box<AppLogEntity> _logs;
  final Box<SpeakingPromptEntity> _speakingPrompts;
  final Box<SpeakingAttemptEntity> _speakingAttempts;

  void attachLogger(Logger logger) {
    _logger = logger;
  }

  static Future<LocalDatabase> open(
      {String databaseName = 'expat8_words.db'}) async {
    final baseDir = await _resolveStorageDirectory();
    final dbDir = Directory(path.join(baseDir.path, databaseName));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final store = await openStore(directory: dbDir.path);
    return LocalDatabase(store);
  }

  static Future<Directory> _resolveStorageDirectory() async {
    // On Linux (unit tests, desktop), use $HOME to keep data outside the project.
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty && home != '/') {
        final dir = Directory(path.join(home, '.expat8_mobile_data'));
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir;
      }
    }

    // On Android/iOS or when HOME is unusable, use the app documents directory.
    return getApplicationDocumentsDirectory();
  }

  Future<void> persistLogEntry(LogEntry entry) async {
    _logs.put(
      AppLogEntity(
        timestampMs: entry.timestamp.toUtc().millisecondsSinceEpoch,
        level: entry.level.name,
        category: entry.category.name,
        event: entry.event,
        message: entry.message,
        traceId: entry.traceId,
        contextJson: jsonEncode(entry.context),
      ),
    );
  }

  Future<List<LogEntry>> queryLogs({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 200,
    int offset = 0,
  }) async {
    final all = _logs.getAll();
    var filtered = all.where((entity) {
      if (minimumLevel != null &&
          AppLogLevel.fromName(entity.level).priority < minimumLevel.priority) {
        return false;
      }
      if (category != null && entity.category != category.name) {
        return false;
      }
      if (from != null &&
          entity.timestampMs < from.toUtc().millisecondsSinceEpoch) {
        return false;
      }
      if (to != null &&
          entity.timestampMs > to.toUtc().millisecondsSinceEpoch) {
        return false;
      }
      return true;
    }).toList(growable: false)
      ..sort((a, b) {
        final timeCompare = b.timestampMs.compareTo(a.timestampMs);
        if (timeCompare != 0) {
          return timeCompare;
        }
        return b.id.compareTo(a.id);
      });

    if (offset > 0) {
      filtered = filtered.skip(offset).toList(growable: false);
    }
    if (limit >= 0) {
      filtered = filtered.take(limit).toList(growable: false);
    }

    return filtered.map(_logFromEntity).toList(growable: false);
  }

  Future<int> pruneLogs({
    int maxEntries = 5000,
    Duration maxAge = const Duration(days: 7),
    DateTime? now,
  }) async {
    final cutoff =
        (now ?? DateTime.now().toUtc()).subtract(maxAge).millisecondsSinceEpoch;
    final all = _logs.getAll();
    var removed = 0;

    for (final entry in all) {
      if (entry.timestampMs < cutoff) {
        _logs.remove(entry.id);
        removed += 1;
      }
    }

    final remaining = _logs.getAll()
      ..sort((a, b) {
        final timeCompare = b.timestampMs.compareTo(a.timestampMs);
        if (timeCompare != 0) {
          return timeCompare;
        }
        return b.id.compareTo(a.id);
      });

    if (remaining.length > maxEntries) {
      final overflow = remaining.skip(maxEntries).toList(growable: false);
      for (final entry in overflow) {
        _logs.remove(entry.id);
        removed += 1;
      }
    }

    return removed;
  }

  Future<void> upsertWord(VocabularyWord word) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    final entity = LocalWordEntity(
      id: existing?.id ?? 0,
      localId: word.localId,
      serverWordId: word.serverWordId,
      term: word.term,
      language: word.language,
      meaningVi: word.meaningVi,
      partOfSpeech: word.partOfSpeech,
      ipa: word.ipa,
      vietnamesePronunciation: word.vietnamesePronunciation,
      example: word.example,
      exampleVi: word.exampleVi,
      difficulty: word.difficulty,
      topicsJson: jsonEncode(word.topics),
      status: word.status.name,
      lastSeenAtMs: word.lastSeenAt?.toUtc().millisecondsSinceEpoch,
      nextReviewAtMs: word.nextReviewAt?.toUtc().millisecondsSinceEpoch,
      createdAtMs: word.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtMs: word.updatedAt.toUtc().millisecondsSinceEpoch,
    );
    _localWords.put(entity);

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

  Future<VocabularyWord?> nextNewWord({String language = 'en'}) async {
    final rows = _localWords
        .query(
          LocalWordEntity_.status.equals(WordStatus.newWord.name) &
              LocalWordEntity_.language.equals(language),
        )
        .order(LocalWordEntity_.createdAtMs, flags: Order.descending)
        .build()
        .find();
    return rows.isEmpty ? null : _wordFromEntity(rows.first);
  }

  Future<VocabularyWord?> nextDueReviewWord(DateTime now,
      {String language = 'en'}) async {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status.oneOf(_activeReviewStatuses) &
              (LocalWordEntity_.nextReviewAtMs.isNull() |
                  LocalWordEntity_.nextReviewAtMs.lessOrEqual(nowMs)),
        )
        .build()
        .find();

    if (rows.isEmpty) {
      return null;
    }

    rows.sort((a, b) {
      final aNext = a.nextReviewAtMs ?? -1;
      final bNext = b.nextReviewAtMs ?? -1;
      final nextCompare = aNext.compareTo(bNext);
      if (nextCompare != 0) {
        return nextCompare;
      }
      final aSeen = a.lastSeenAtMs ?? -1;
      final bSeen = b.lastSeenAtMs ?? -1;
      return aSeen.compareTo(bSeen);
    });

    return _wordFromEntity(rows.first);
  }

  Future<VocabularyWord?> recentlyLearnedReviewWord(
      {String language = 'en'}) async {
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status.oneOf(_activeReviewStatuses) &
              LocalWordEntity_.lastSeenAtMs.notNull(),
        )
        .build()
        .find();

    if (rows.isEmpty) {
      return null;
    }

    rows.sort((a, b) {
      final seenCompare =
          (b.lastSeenAtMs ?? -1).compareTo(a.lastSeenAtMs ?? -1);
      if (seenCompare != 0) {
        return seenCompare;
      }
      return b.updatedAtMs.compareTo(a.updatedAtMs);
    });

    return _wordFromEntity(rows.first);
  }

  Future<VocabularyWord?> nextDifficultRelearnWord(DateTime now,
      {String language = 'en'}) async {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status.equals(WordStatus.learning.name) &
              (LocalWordEntity_.nextReviewAtMs.isNull() |
                  LocalWordEntity_.nextReviewAtMs.lessOrEqual(nowMs)),
        )
        .build()
        .find();

    if (rows.isEmpty) {
      return null;
    }

    rows.sort((a, b) {
      final aTs = a.nextReviewAtMs ?? a.updatedAtMs;
      final bTs = b.nextReviewAtMs ?? b.updatedAtMs;
      return aTs.compareTo(bTs);
    });

    return _wordFromEntity(rows.first);
  }

  Future<List<String>> recentServerWordIds({int limit = 20}) async {
    final rows = _localWords
        .query(LocalWordEntity_.serverWordId.notNull())
        .build()
        .find();

    rows.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return bTs.compareTo(aTs);
    });

    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final serverWordId = row.serverWordId;
      if (serverWordId == null ||
          serverWordId.isEmpty ||
          seen.contains(serverWordId)) {
        continue;
      }
      seen.add(serverWordId);
      result.add(serverWordId);
      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  Future<List<String>> activeCachedServerWordIds({int limit = 1000}) async {
    final rows = _localWords
        .query(LocalWordEntity_.serverWordId.notNull())
        .build()
        .find();

    rows.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return bTs.compareTo(aTs);
    });

    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final serverWordId = row.serverWordId;
      if (serverWordId == null ||
          serverWordId.isEmpty ||
          seen.contains(serverWordId)) {
        continue;
      }
      seen.add(serverWordId);
      result.add(serverWordId);
      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }

  Future<bool> deleteLocalWord(String localId) async {
    final query =
        _localWords.query(LocalWordEntity_.localId.equals(localId)).build();
    final matches = query.find();
    if (matches.isEmpty) {
      return false;
    }
    for (final entity in matches) {
      _localWords.remove(entity.id);
    }
    return true;
  }

  Future<String> getOrCreateDeviceId(String Function() createId) async {
    final existing = await getSetting('device_id');
    if (existing != null && existing.isNotEmpty) {
      final normalized = _anonymousDeviceId(existing);
      if (normalized != existing) {
        await setSetting('device_id', normalized);
      }
      return normalized;
    }

    final deviceId = _anonymousDeviceId(createId());
    await setSetting('device_id', deviceId);
    return deviceId;
  }

  String _anonymousDeviceId(String value) {
    return value.startsWith('anonymous_') ? value : 'anonymous_$value';
  }

  Future<void> saveUserSession(UserSession session) async {
    await setSetting('user_session', jsonEncode(session.toJson()));
  }

  Future<UserSession?> loadUserSession() async {
    final raw = await getSetting('user_session');
    if (raw == null) {
      return null;
    }
    return UserSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearUserSession() async {
    final query =
        _settings.query(AppSettingEntity_.key.equals('user_session')).build();
    final row = query.findFirst();
    if (row != null) {
      _settings.remove(row.id);
    }
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

    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    existing.status = status.name;
    existing.lastSeenAtMs = now.toUtc().millisecondsSinceEpoch;
    existing.nextReviewAtMs = nextReview.toUtc().millisecondsSinceEpoch;
    existing.updatedAtMs = now.toUtc().millisecondsSinceEpoch;
    _localWords.put(existing);
  }

  Future<void> markWordRememberedLowFrequency({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.status = WordStatus.mastered.name;
    existing.lastSeenAtMs = nowMs;
    // Product rule: remembered swipe reduces relearn frequency to 10%.
    // We model this by scheduling a farther review interval.
    existing.nextReviewAtMs =
        now.toUtc().add(const Duration(days: 10)).millisecondsSinceEpoch;
    existing.updatedAtMs = nowMs;
    _localWords.put(existing);
  }

  Future<void> markWordDifficultForRelearn({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    if (existing == null) {
      return;
    }

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.status = WordStatus.learning.name;
    existing.lastSeenAtMs = nowMs;
    existing.nextReviewAtMs =
        now.toUtc().add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    existing.updatedAtMs = nowMs;
    _localWords.put(existing);
  }

  /// Transitions a [newWord] word to [learning] status on first display.
  ///
  /// Schedules a review in 24 hours so the word enters the SRS cycle.
  /// Safe to call fire-and-forget — no-op if word not found.
  Future<void> markWordAsLearning({
    required VocabularyWord word,
    required DateTime now,
  }) async {
    final existing = _localWords
        .query(LocalWordEntity_.localId.equals(word.localId))
        .build()
        .findFirst();
    if (existing == null) return;

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    existing.status = WordStatus.learning.name;
    existing.lastSeenAtMs = nowMs;
    existing.nextReviewAtMs =
        now.toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    existing.updatedAtMs = nowMs;
    _localWords.put(existing);
  }

  Future<void> insertStudyEvent(StudyEvent event) async {
    final payload = jsonEncode(event.toSyncJson());

    final existing = _studyEvents
        .query(StudyEventEntity_.clientEventId.equals(event.clientEventId))
        .build()
        .findFirst();
    if (existing == null) {
      _studyEvents.put(
        StudyEventEntity(
          clientEventId: event.clientEventId,
          localWordId: event.localWordId,
          serverWordId: event.serverWordId,
          rating: event.rating.apiValue,
          occurredAtMs: event.occurredAt.toUtc().millisecondsSinceEpoch,
          syncStatus: event.syncStatus.name,
        ),
      );
    }

    _syncQueue.put(
      SyncQueueEntity(
        type: 'study_event',
        payload: payload,
        retryCount: 0,
        nextRetryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<SyncQueueEntry>> dueSyncEntries(DateTime now) async {
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final rows = _syncQueue
        .query(SyncQueueEntity_.nextRetryAtMs.lessOrEqual(nowMs))
        .order(SyncQueueEntity_.createdAtMs)
        .build()
        .find();

    return rows.take(50).map(_queueFromEntity).toList(growable: false);
  }

  Future<void> markEventSynced(String clientEventId) async {
    final event = _studyEvents
        .query(StudyEventEntity_.clientEventId.equals(clientEventId))
        .build()
        .findFirst();
    if (event != null) {
      event.syncStatus = SyncStatus.synced.name;
      _studyEvents.put(event);
    }

    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.payload.contains('"client_event_id":"$clientEventId"')) {
        _syncQueue.remove(item.id);
      }
    }
  }

  Future<void> scheduleRetry(SyncQueueEntry entry, DateTime now) async {
    if (entry.id == null) {
      return;
    }

    final entity = _syncQueue.get(entry.id!);
    if (entity == null) {
      return;
    }

    final retryCount = entry.retryCount + 1;
    final delayMinutes = retryCount.clamp(1, 30).toInt();

    entity.retryCount = retryCount;
    entity.nextRetryAtMs =
        now.add(Duration(minutes: delayMinutes)).toUtc().millisecondsSinceEpoch;
    _syncQueue.put(entity);

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

  static final List<String> _activeReviewStatuses = [
    WordStatus.learning.name,
    WordStatus.review.name,
    WordStatus.mastered.name,
  ];

  Future<String?> getSetting(String key) async {
    final row =
        _settings.query(AppSettingEntity_.key.equals(key)).build().findFirst();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    final existing =
        _settings.query(AppSettingEntity_.key.equals(key)).build().findFirst();
    _settings.put(
      AppSettingEntity(
        id: existing?.id ?? 0,
        key: key,
        value: value,
      ),
    );
  }

  Future<int> countUnstudiedNewWords({String language = 'en'}) async {
    return _localWords
        .query(
          LocalWordEntity_.status.equals(WordStatus.newWord.name) &
              LocalWordEntity_.language.equals(language),
        )
        .build()
        .count();
  }

  Future<int> countWords({String language = 'en'}) async {
    return _localWords
        .query(LocalWordEntity_.language.equals(language))
        .build()
        .count();
  }

  /// Picks a random word for [language] whose status is not [mastered]
  /// (i.e., not yet marked as remembered). Used as the fallback when no
  /// new-word card is available so the learner always has something to study.
  Future<VocabularyWord?> randomNotMasteredWord({
    String language = 'en',
    Random? random,
  }) async {
    final rows = _localWords
        .query(
          LocalWordEntity_.language.equals(language) &
              LocalWordEntity_.status.notEquals(WordStatus.mastered.name),
        )
        .build()
        .find();
    if (rows.isEmpty) return null;
    final rng = random ?? Random();
    return _wordFromEntity(rows[rng.nextInt(rows.length)]);
  }

  /// Picks any cached word for [language], including mastered words.
  ///
  /// This is the final offline fallback: if the learner has exhausted every
  /// new/learning/review card, the app must still show something instead of
  /// leaving the card area empty.
  Future<VocabularyWord?> randomWord({
    String language = 'en',
    Random? random,
  }) async {
    final rows = _localWords
        .query(LocalWordEntity_.language.equals(language))
        .build()
        .find();
    if (rows.isEmpty) return null;
    final rng = random ?? Random();
    return _wordFromEntity(rows[rng.nextInt(rows.length)]);
  }

  /// Deletes up to [limit] oldest mastered (remembered) words for [language],
  /// skipping any with pending sync events. Returns the number actually removed.
  Future<int> deleteOldestMasteredWords({
    String language = 'en',
    required int limit,
  }) async {
    if (limit <= 0) return 0;
    final pendingLocalIds = _studyEvents
        .query(StudyEventEntity_.syncStatus.equals(SyncStatus.pending.name))
        .build()
        .find()
        .map((e) => e.localWordId)
        .toSet();

    final rows = _localWords
        .query(
          LocalWordEntity_.status.equals(WordStatus.mastered.name) &
              LocalWordEntity_.language.equals(language),
        )
        .build()
        .find()
        .where((e) => !pendingLocalIds.contains(e.localId))
        .toList();

    rows.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return aTs.compareTo(bTs);
    });

    final toDelete = rows.take(limit).toList();
    for (final row in toDelete) {
      _localWords.remove(row.id);
    }
    return toDelete.length;
  }

  /// Adds a batch of words to the local cache.
  ///
  /// Enforces the per-language 1000-word cap after every batch write.
  /// Pruning runs once per language present in [words] so seeding one language
  /// never evicts entries from another.
  Future<void> addBatch(List<VocabularyWord> words) async {
    if (words.isEmpty) return;
    final affectedLanguages = <String>{};
    for (final word in words) {
      await upsertWord(word);
      affectedLanguages.add(word.language);
    }
    for (final language in affectedLanguages) {
      await pruneToCapSmartly(maxWords: 1000, language: language);
    }
  }

  /// Prunes the local word store for [language] (or globally when null) to
  /// [maxWords] using smart priority ordering:
  ///
  /// Pass 1: Remove [mastered] words (least-recently-seen first).
  /// Pass 2: Remove [review] words with nextReviewAt > 30 days from now
  ///         (farthest-first).
  /// Pass 3: Fallback — remove oldest words by createdAt.
  ///
  /// Words with pending (unsynced) study events are skipped in all passes.
  Future<int> pruneToCapSmartly({int maxWords = 1000, String? language}) async {
    final all = language == null
        ? _localWords.getAll()
        : _localWords
            .query(LocalWordEntity_.language.equals(language))
            .build()
            .find();
    if (all.length <= maxWords) return 0;

    // Build set of localIds that have pending sync events.
    final pendingLocalIds = _studyEvents
        .query(StudyEventEntity_.syncStatus.equals(SyncStatus.pending.name))
        .build()
        .find()
        .map((e) => e.localWordId)
        .toSet();

    bool hasPending(LocalWordEntity e) => pendingLocalIds.contains(e.localId);

    var removed = 0;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final thirtyDaysMs = const Duration(days: 30).inMilliseconds;

    // Pass 1: mastered words, least-recently-seen first.
    if (all.length - removed > maxWords) {
      final mastered = all
          .where((e) =>
              e.status == WordStatus.mastered.name && !hasPending(e))
          .toList()
        ..sort((a, b) {
          final aTs = a.lastSeenAtMs ?? 0;
          final bTs = b.lastSeenAtMs ?? 0;
          return aTs.compareTo(bTs); // ascending: least-recently-seen first
        });
      for (final row in mastered) {
        if (all.length - removed <= maxWords) break;
        _localWords.remove(row.id);
        removed += 1;
      }
    }

    // Pass 2: review words with nextReviewAt far in the future (> 30 days).
    if (all.length - removed > maxWords) {
      final farReview = all
          .where((e) =>
              e.status == WordStatus.review.name &&
              !hasPending(e) &&
              (e.nextReviewAtMs != null &&
                  e.nextReviewAtMs! > nowMs + thirtyDaysMs))
          .toList()
        ..sort((a, b) {
          final aTs = a.nextReviewAtMs ?? 0;
          final bTs = b.nextReviewAtMs ?? 0;
          return bTs.compareTo(aTs); // descending: farthest first
        });
      for (final row in farReview) {
        if (all.length - removed <= maxWords) break;
        _localWords.remove(row.id);
        removed += 1;
      }
    }

    // Pass 3: fallback — oldest by createdAt, skipping pending.
    if (all.length - removed > maxWords) {
      final oldest = all
          .where((e) => !hasPending(e))
          .toList()
        ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
      for (final row in oldest) {
        if (all.length - removed <= maxWords) break;
        // Skip rows already removed in earlier passes.
        if (_localWords.get(row.id) == null) continue;
        _localWords.remove(row.id);
        removed += 1;
      }
    }

    return removed;
  }

  Future<int> pruneToMostRecent({int maxWords = 1000}) async {
    final words = _localWords.getAll();
    if (words.length <= maxWords) {
      return 0;
    }

    words.sort((a, b) {
      final aTs = a.lastSeenAtMs ?? a.updatedAtMs;
      final bTs = b.lastSeenAtMs ?? b.updatedAtMs;
      return bTs.compareTo(aTs);
    });

    final stale = words.skip(maxWords).toList(growable: false);
    for (final row in stale) {
      _localWords.remove(row.id);
    }
    return stale.length;
  }

  Future<void> close() async {
    _store.close();
  }

  VocabularyWord _wordFromEntity(LocalWordEntity row) {
    return VocabularyWord(
      localId: row.localId,
      serverWordId: row.serverWordId,
      term: row.term,
      language: row.language,
      meaningVi: row.meaningVi,
      partOfSpeech: row.partOfSpeech,
      ipa: row.ipa,
      vietnamesePronunciation: row.vietnamesePronunciation,
      example: row.example,
      exampleVi: row.exampleVi,
      difficulty: row.difficulty,
      topics: List<String>.from(jsonDecode(row.topicsJson) as List<dynamic>),
      status: WordStatus.values.byName(row.status),
      lastSeenAt: _parseDateMs(row.lastSeenAtMs),
      nextReviewAt: _parseDateMs(row.nextReviewAtMs),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.createdAtMs, isUtc: true),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row.updatedAtMs, isUtc: true),
    );
  }

  SyncQueueEntry _queueFromEntity(SyncQueueEntity row) {
    return SyncQueueEntry(
      id: row.id,
      type: row.type,
      payload: row.payload,
      retryCount: row.retryCount,
      nextRetryAt:
          DateTime.fromMillisecondsSinceEpoch(row.nextRetryAtMs, isUtc: true),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.createdAtMs, isUtc: true),
    );
  }

  LogEntry _logFromEntity(AppLogEntity row) {
    return LogEntry(
      id: row.id,
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(row.timestampMs, isUtc: true),
      level: AppLogLevel.fromName(row.level),
      category: AppLogCategory.values.byName(row.category),
      event: row.event,
      message: row.message,
      traceId: row.traceId,
      context: Map<String, Object?>.from(
        jsonDecode(row.contextJson) as Map<String, dynamic>,
      ),
    );
  }

  DateTime? _parseDateMs(int? value) {
    if (value == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  // ---- Speaking prompt cache ----

  /// Upserts a speaking prompt into the local cache.
  void cacheSpeakingPrompt(SpeakingPromptEntity entity) {
    _speakingPrompts.put(entity);
  }

  /// Returns the cached prompt for [promptId], or null if not cached.
  SpeakingPromptEntity? getCachedPrompt(String promptId) {
    return _speakingPrompts
        .query(SpeakingPromptEntity_.promptId.equals(promptId))
        .build()
        .findFirst();
  }

  /// Returns up to [limit] cached prompts linked to [serverWordId].
  List<SpeakingPromptEntity> promptsForWord(String serverWordId,
      {int limit = 5}) {
    return _speakingPrompts
        .query(SpeakingPromptEntity_.serverWordId.equals(serverWordId))
        .build()
        .find()
        .take(limit)
        .toList(growable: false);
  }

  /// Returns up to [limit] cached prompts, most recently cached first.
  /// Used by drill selection when choosing from the local cache.
  List<SpeakingPromptEntity> recentCachedPrompts({int limit = 10}) {
    return _speakingPrompts
        .query()
        .order(SpeakingPromptEntity_.cachedAtMs, flags: Order.descending)
        .build()
        .find()
        .take(limit)
        .toList(growable: false);
  }

  // ---- Speaking attempt storage ----

  /// Saves a new speaking attempt entity, returning the ObjectBox id.
  int saveSpeakingAttempt(SpeakingAttemptEntity entity) {
    return _speakingAttempts.put(entity);
  }

  /// Updates an existing speaking attempt (by ObjectBox id).
  void updateSpeakingAttempt(SpeakingAttemptEntity entity) {
    _speakingAttempts.put(entity);
  }

  /// Returns the attempt entity with [attemptId], or null.
  SpeakingAttemptEntity? getSpeakingAttempt(String attemptId) {
    return _speakingAttempts
        .query(SpeakingAttemptEntity_.attemptId.equals(attemptId))
        .build()
        .findFirst();
  }

  /// Marks the attempt identified by [attemptId] as synced and removes its
  /// sync queue entry.
  void markSpeakingAttemptSynced(String attemptId) {
    final entity = getSpeakingAttempt(attemptId);
    if (entity != null) {
      entity.syncStatus = SyncStatus.synced.name;
      _speakingAttempts.put(entity);
    }
    // Remove from sync queue (payload contains the attempt_id).
    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.payload.contains('"attempt_id":"$attemptId"')) {
        _syncQueue.remove(item.id);
      }
    }
  }

  /// Queues a speaking event payload (JSON string) for background sync.
  void enqueueSpeakingEvent(String payloadJson) {
    _syncQueue.put(
      SyncQueueEntity(
        type: 'speaking_event',
        payload: payloadJson,
        retryCount: 0,
        nextRetryAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  /// Deletes all speaking attempt entities and clears their sync queue
  /// entries. Audio files are managed by [AudioFileManager] separately.
  Future<int> deleteAllSpeakingAttempts() async {
    final count = _speakingAttempts.count();
    _speakingAttempts.removeAll();
    final allQueue = _syncQueue.getAll();
    for (final item in allQueue) {
      if (item.type == 'speaking_event') {
        _syncQueue.remove(item.id);
      }
    }
    return count;
  }

  /// Returns the total number of speaking attempts stored locally.
  int countSpeakingAttempts() => _speakingAttempts.count();
}

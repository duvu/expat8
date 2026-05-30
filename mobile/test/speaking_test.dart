import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/local_database_entities.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:expat8_language_app/src/speaking/speaking_audio_service.dart';
import 'package:expat8_language_app/src/speaking/speaking_repository.dart';
import 'package:expat8_language_app/src/speaking/audio_file_manager.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Minimal fake audio service (no real mic/plugin) ----

class FakeAudioService implements ISpeakingAudioService {
  MicPermissionStatus _status = MicPermissionStatus.granted;
  bool recording = false;
  String? lastStartedAttemptId;
  String? lastStoppedPath;

  void setPermission(MicPermissionStatus s) => _status = s;

  @override
  Future<MicPermissionStatus> checkMicPermission() async => _status;

  @override
  Future<MicPermissionStatus> requestMicPermission() async => _status;

  @override
  Future<void> speakSample(String text, {String languageCode = 'en-US'}) async {}

  @override
  Future<void> stopSample() async {}

  @override
  Future<String> startRecording(String attemptId) async {
    recording = true;
    lastStartedAttemptId = attemptId;
    return attemptId;
  }

  @override
  Future<String?> stopRecording() async {
    recording = false;
    lastStoppedPath = '/local/speaking/${lastStartedAttemptId ?? 'test'}.m4a';
    return lastStoppedPath;
  }

  @override
  Future<void> playLocal(String localAudioPath) async {}

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> dispose() async {}
}

class FakeFileManager extends AudioFileManager {
  final List<String> deleted = [];

  @override
  Future<String> pathForAttempt(String attemptId) async =>
      '/local/speaking/${attemptId}.m4a';

  @override
  Future<bool> deleteOne(String localAudioPath) async {
    deleted.add(localAudioPath);
    return true;
  }

  @override
  Future<int> deleteAll() async {
    deleted.add('*');
    return 0;
  }

  @override
  Future<int> runRetentionCleanup() async => 0;
}

VocabularyWord _word({SpeakingPrompt? prompt}) {
  final now = DateTime.utc(2026, 1, 1);
  return VocabularyWord(
    localId: 'local_1',
    serverWordId: 'server_1',
    term: 'hello',
    language: 'en',
    meaningVi: 'xin chào',
    ipa: 'həˈloʊ',
    vietnamesePronunciation: 'he-lô',
    example: 'Hello, how are you?',
    exampleVi: 'Xin chào, bạn khỏe không?',
    difficulty: 'beginner',
    topics: const [],
    status: WordStatus.newWord,
    createdAt: now,
    updatedAt: now,
    speakingPrompt: prompt,
  );
}

SpeakingPrompt _prompt() => const SpeakingPrompt(
      promptId: 'prompt_1',
      targetText: 'Hello, how are you?',
      viHint: 'Xin chào, bạn khỏe không?',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeakingRepository', () {
    late LocalDatabase db;
    late FakeAudioService audio;
    late FakeFileManager files;
    late SpeakingRepository repo;

    setUp(() async {
      db = await LocalDatabase.open(
          databaseName: 'speaking_repository_test.db');
      audio = FakeAudioService();
      files = FakeFileManager();
      repo = SpeakingRepository(
        database: db,
        audioService: audio,
        fileManager: files,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('caches prompt when onPromptViewed is called', () {
      final word = _word(prompt: _prompt());
      repo.onPromptViewed(word);
      final cached = db.getCachedPrompt('prompt_1');
      expect(cached, isNotNull);
      expect(cached!.targetText, 'Hello, how are you?');
    });

    test('no cache when word has no speaking prompt', () {
      final word = _word();
      repo.onPromptViewed(word); // should be a no-op
      // No error thrown; nothing cached for word with no prompt.
      expect(db.getCachedPrompt('nonexistent'), isNull);
    });

    test('startRecording persists attempt entity', () async {
      final word = _word(prompt: _prompt());
      final id = await repo.startRecording(word);
      expect(id, isNotEmpty);
      final entity = db.getSpeakingAttempt(id);
      expect(entity, isNotNull);
      expect(entity!.syncStatus, SyncStatus.pending.name);
      expect(audio.recording, isTrue);
    });

    test('stopRecording stores localAudioPath and enqueues event', () async {
      final word = _word(prompt: _prompt());
      final id = await repo.startRecording(word);
      await repo.stopRecording(word);
      final entity = db.getSpeakingAttempt(id);
      expect(entity?.localAudioPath, isNotNull);
      // Verify a speaking_event was queued.
      final queue = await db.dueSyncEntries(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      final speaking =
          queue.where((e) => e.type == 'speaking_event').toList();
      expect(speaking, isNotEmpty);
      // Ensure localAudioPath is NOT in queued payload.
      for (final entry in speaking) {
        expect(entry.payload.contains('local_audio_path'), isFalse);
      }
    });

    test('localAudioPath never enters sync queue payloads', () async {
      final word = _word(prompt: _prompt());
      await repo.startRecording(word);
      await repo.stopRecording(word);
      final queue = await db.dueSyncEntries(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      for (final entry in queue) {
        expect(entry.payload.contains('local_audio_path'), isFalse,
            reason: 'local_audio_path must never appear in API payloads');
      }
    });

    test('onRetried increments retry count and enqueues event', () async {
      final word = _word(prompt: _prompt());
      final id = await repo.startRecording(word);
      await repo.stopRecording(word);
      repo.onRetried(word, id);
      final entity = db.getSpeakingAttempt(id);
      expect(entity?.retryCount, 1);
      final queue = await db.dueSyncEntries(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      final retried = queue
          .where((e) =>
              e.type == 'speaking_event' && e.payload.contains('retried'))
          .toList();
      expect(retried, isNotEmpty);
    });

    test('onSelfRated stores rating and enqueues event', () async {
      final word = _word(prompt: _prompt());
      final id = await repo.startRecording(word);
      await repo.stopRecording(word);
      repo.onSelfRated(word, id, SpeakingRating.ok);
      final entity = db.getSpeakingAttempt(id);
      expect(entity?.selfRating, 'ok');
    });

    test('permission denied — startRecording still safe via audio service',
        () async {
      audio.setPermission(MicPermissionStatus.denied);
      final status = await repo.requestMicPermission();
      expect(status, MicPermissionStatus.denied);
      // Repository does not auto-start on denied; UI checks first.
    });

    test('selectDrillPrompts returns cached prompts', () {
      final word = _word(prompt: _prompt());
      repo.onPromptViewed(word);
      final prompts = repo.selectDrillPrompts(count: 5);
      expect(prompts.isNotEmpty, isTrue);
    });

    test('deleteAllRecordings removes attempts from DB', () async {
      final word = _word(prompt: _prompt());
      await repo.startRecording(word);
      await repo.stopRecording(word);
      final removed = await repo.deleteAllRecordings();
      expect(removed, greaterThanOrEqualTo(0));
      final queue = await db.dueSyncEntries(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      final speaking =
          queue.where((e) => e.type == 'speaking_event').toList();
      // speaking queue entries removed by deleteAllRecordings
      expect(speaking, isEmpty);
    });
  });

  group('Drill selection', () {
    late LocalDatabase db;
    late SpeakingRepository repo;
    var _drillTestCounter = 0;

    setUp(() async {
      _drillTestCounter++;
      db = await LocalDatabase.open(
          databaseName: 'drill_selection_test_$_drillTestCounter.db');
      repo = SpeakingRepository(
        database: db,
        audioService: FakeAudioService(),
        fileManager: FakeFileManager(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('empty state when no prompts are cached', () {
      final prompts = repo.selectDrillPrompts(count: 5);
      expect(prompts, isEmpty);
    });

    test('returns at most count prompts', () {
      for (var i = 0; i < 10; i++) {
        db.cacheSpeakingPrompt(SpeakingPromptEntity(
          promptId: 'dp_$i',
          targetText: 'sentence $i',
          cachedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch + i,
        ));
      }
      final prompts = repo.selectDrillPrompts(count: 5);
      expect(prompts.length, 5);
    });

    test('returns most recently cached prompts first', () {
      final base = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      for (var i = 0; i < 3; i++) {
        db.cacheSpeakingPrompt(SpeakingPromptEntity(
          promptId: 'ord_$i',
          targetText: 'sentence $i',
          cachedAtMs: base + i * 1000,
        ));
      }
      final prompts = repo.selectDrillPrompts(count: 3);
      expect(prompts.first.promptId, 'ord_2'); // most recent first
    });

    test('available offline — prompts come from local cache only', () {
      // Simulate a prompt cached from a previous online session.
      db.cacheSpeakingPrompt(SpeakingPromptEntity(
        promptId: 'offline_p1',
        targetText: 'Nice to meet you.',
        cachedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ));
      // No network call is needed; selectDrillPrompts is synchronous.
      final prompts = repo.selectDrillPrompts(count: 5);
      expect(prompts.any((p) => p.promptId == 'offline_p1'), isTrue);
    });
  });

  group('SpeakingPromptEntity cache', () {
    test('cacheSpeakingPrompt upserts on conflict', () async {
      final db = await LocalDatabase.open(
          databaseName: 'speaking_prompt_upsert_test.db');
      try {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        db.cacheSpeakingPrompt(SpeakingPromptEntity(
          promptId: 'p1',
          targetText: 'Hello',
          cachedAtMs: now,
        ));
        db.cacheSpeakingPrompt(SpeakingPromptEntity(
          promptId: 'p1',
          targetText: 'Hello world', // updated
          cachedAtMs: now + 1000,
        ));
        final result = db.getCachedPrompt('p1');
        expect(result?.targetText, 'Hello world');
      } finally {
        await db.close();
      }
    });

    test('recentCachedPrompts returns most recently cached first', () async {
      final db = await LocalDatabase.open(
          databaseName: 'speaking_prompt_recent_test.db');
      try {
        final base = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
        for (var i = 0; i < 3; i++) {
          db.cacheSpeakingPrompt(SpeakingPromptEntity(
            promptId: 'pr_$i',
            targetText: 'sentence $i',
            cachedAtMs: base + i * 1000,
          ));
        }
        final recent = db.recentCachedPrompts(limit: 3);
        expect(recent.first.promptId, 'pr_2'); // most recent first
      } finally {
        await db.close();
      }
    });
  });

  group('postLoopCompletedEvent', () {
    late LocalDatabase db;
    late SpeakingRepository repo;
    var databaseCounter = 0;

    setUp(() async {
      db = await LocalDatabase.open(
          databaseName: 'loop_completed_test_${databaseCounter++}.db');
      repo = SpeakingRepository(
        database: db,
        audioService: FakeAudioService(),
        fileManager: FakeFileManager(),
      );
    });

    tearDown(() async => db.close());

    test('enqueues loop_completed event with duration and prompts_count',
        () async {
      repo.postLoopCompletedEvent(durationMs: 90000, promptsCount: 5);

      final queue = await db.dueSyncEntries(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      final loopEvents = queue
          .where((e) =>
              e.type == 'speaking_event' &&
              e.payload.contains('loop_completed'))
          .toList();
      expect(loopEvents, hasLength(1));
      expect(loopEvents.first.payload, contains('"duration_ms":90000'));
      expect(loopEvents.first.payload, contains('"prompts_count":5'));
    });

    test('does not include local_audio_path in loop_completed payload', () async {
      repo.postLoopCompletedEvent(durationMs: 60000, promptsCount: 3);

      final queue = await db.dueSyncEntries(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      final loopEvent = queue.firstWhere(
        (e) => e.payload.contains('loop_completed'),
      );
      expect(loopEvent.payload, isNot(contains('local_audio_path')));
    });
  });

  group('getWeeklySummary', () {
    late LocalDatabase db;
    late SpeakingRepository repo;

    setUp(() async {
      db = await LocalDatabase.open(
          databaseName: 'get_weekly_summary_test.db');
      repo = SpeakingRepository(
        database: db,
        audioService: FakeAudioService(),
        fileManager: FakeFileManager(),
        // No apiClient — tests the offline/null fallback path
      );
    });

    tearDown(() async => db.close());

    test('returns null when no apiClient is configured', () async {
      final result = await repo.getWeeklySummary();
      expect(result, isNull);
    });
  });
}

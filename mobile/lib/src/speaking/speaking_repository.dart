import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../data/local_database.dart';
import '../data/local_database_entities.dart';
import '../models/study_event.dart';
import '../models/vocabulary_word.dart';
import 'audio_file_manager.dart';
import 'speaking_audio_service.dart';

/// Speaking event types matching the backend enum.
class SpeakingEventType {
  static const promptViewed = 'speaking_prompt_viewed';
  static const samplePlayed = 'speaking_sample_played';
  static const recorded = 'speaking_recorded';
  static const retried = 'speaking_retried';
  static const selfRatedClear = 'speaking_self_rated_clear';
  static const selfRatedHesitated = 'speaking_self_rated_hesitated';
  static const selfRatedCouldNotSay = 'speaking_self_rated_could_not_say';
  static const drillCompleted = 'speaking_drill_completed';
}

/// Self-rating values for the vocabulary card speaking panel.
enum SpeakingRating { easy, ok, hard }

extension SpeakingRatingApi on SpeakingRating {
  /// Local storage value (unchanged for backwards compat with existing DB rows).
  String get apiValue => switch (this) {
        SpeakingRating.easy => 'easy',
        SpeakingRating.ok => 'ok',
        SpeakingRating.hard => 'hard',
      };

  /// The backend event type emitted when this rating is selected.
  String get eventType => switch (this) {
        SpeakingRating.easy => SpeakingEventType.selfRatedClear,
        SpeakingRating.ok => SpeakingEventType.selfRatedHesitated,
        SpeakingRating.hard => SpeakingEventType.selfRatedCouldNotSay,
      };
}

/// Self-rating values for the drill flow.
enum SpeakingDrillRating { clear, hesitated, couldNotSay }

extension SpeakingDrillRatingApi on SpeakingDrillRating {
  String get label => switch (this) {
        SpeakingDrillRating.clear => 'Clear',
        SpeakingDrillRating.hesitated => 'Hesitated',
        SpeakingDrillRating.couldNotSay => "Couldn't say it",
      };

  String get storageValue => switch (this) {
        SpeakingDrillRating.clear => 'clear',
        SpeakingDrillRating.hesitated => 'hesitated',
        SpeakingDrillRating.couldNotSay => 'could_not_say',
      };

  String get eventType => switch (this) {
        SpeakingDrillRating.clear => SpeakingEventType.selfRatedClear,
        SpeakingDrillRating.hesitated => SpeakingEventType.selfRatedHesitated,
        SpeakingDrillRating.couldNotSay =>
          SpeakingEventType.selfRatedCouldNotSay,
      };
}

/// Orchestrates speaking attempt lifecycle:
/// - manages local [SpeakingAttemptEntity] records
/// - delegates audio I/O to [ISpeakingAudioService]
/// - enqueues speaking events via [LocalDatabase] for background sync
/// - enforces the rule that [localAudioPath] never enters API payloads
class SpeakingRepository {
  SpeakingRepository({
    required LocalDatabase database,
    required ISpeakingAudioService audioService,
    required AudioFileManager fileManager,
    Uuid? uuid,
  })  : _database = database,
        _audioService = audioService,
        _fileManager = fileManager,
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final ISpeakingAudioService _audioService;
  final AudioFileManager _fileManager;
  final Uuid _uuid;

  String? _activeAttemptId;
  String? _currentDrillSessionId;

  // ---- permission ----

  Future<MicPermissionStatus> checkMicPermission() =>
      _audioService.checkMicPermission();

  Future<MicPermissionStatus> requestMicPermission() =>
      _audioService.requestMicPermission();

  // ---- prompt cache ----

  /// Caches a speaking prompt received from a vocabulary card response.
  void cachePrompt(SpeakingPrompt prompt, {String? serverWordId}) {
    _database.cacheSpeakingPrompt(
      SpeakingPromptEntity(
        promptId: prompt.promptId,
        wordSenseId: null,
        serverWordId: serverWordId,
        targetText: prompt.targetText,
        viHint: prompt.viHint,
        targetPhrase: prompt.targetPhrase,
        pronunciationTip: prompt.pronunciationTip,
        commonMistake: prompt.commonMistake,
        difficulty: prompt.difficulty,
        topic: prompt.topic,
        cachedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  // ---- drill session ----

  /// Generates a new drill session UUID and stores it.
  /// Must be called once before the drill begins.
  /// All drill events will carry this [attempt_id] until [onDrillCompleted].
  String beginDrillSession() {
    _currentDrillSessionId = _uuid.v4();
    return _currentDrillSessionId!;
  }

  /// Returns up to [count] prompts for the 3-minute drill, from recent cache.
  List<SpeakingPromptEntity> selectDrillPrompts({int count = 5}) =>
      getDrillCandidates(limit: count);

  /// Returns up to [limit] drill candidate prompts (most recently cached first).
  List<SpeakingPromptEntity> getDrillCandidates({int limit = 5}) {
    return _database.recentCachedPrompts(limit: limit);
  }

  /// Returns all cached prompts for a given [wordSenseId].
  List<SpeakingPromptEntity> getByWordSenseId(String wordSenseId) {
    return _database.getPromptsByWordSenseId(wordSenseId);
  }

  /// Upserts a batch of prompts received from the backend sync endpoint.
  ///
  /// [items] is the list of items from `GET /v1/speaking/prompts`.
  void upsertAllFromSync(List<SpeakingPromptItem> items) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final entities = items
        .map(
          (item) => SpeakingPromptEntity(
            promptId: item.id,
            wordSenseId: item.wordSenseId,
            serverWordId: null,
            targetText: item.targetText,
            viHint: item.viHint,
            targetPhrase: null,
            pronunciationTip: item.pronunciationTip,
            commonMistake: item.commonMistake,
            difficulty: item.difficulty,
            topic: item.topic,
            cachedAtMs: now,
          ),
        )
        .toList();
    _database.upsertAllSpeakingPrompts(entities);
  }

  // ---- vocab-card events ----

  /// Records that the user viewed the speaking prompt for [word].
  /// Also caches the prompt locally if present.
  void onPromptViewed(VocabularyWord word) {
    final prompt = word.speakingPrompt;
    if (prompt == null) return;
    cachePrompt(prompt, serverWordId: word.serverWordId);
    _enqueueEvent({
      'event_type': SpeakingEventType.promptViewed,
      'client_event_id': _uuid.v4(),
      'prompt_id': prompt.promptId,
      'server_word_id': word.serverWordId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void onSamplePlayed(VocabularyWord word) {
    final prompt = word.speakingPrompt;
    if (prompt == null) return;
    _enqueueEvent({
      'event_type': SpeakingEventType.samplePlayed,
      'client_event_id': _uuid.v4(),
      'prompt_id': prompt.promptId,
      'server_word_id': word.serverWordId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ---- vocab-card recording lifecycle ----

  /// Starts a new recording for [word]. Creates a local attempt record.
  /// Emits a `speaking_first_recording` analytics event on the very first
  /// attempt ever (conversion metric).
  /// Returns the new [attemptId].
  Future<String> startRecording(VocabularyWord word) async {
    final isFirst = _database.countSpeakingAttempts() == 0;
    final id = _uuid.v4();
    _activeAttemptId = id;
    final now = DateTime.now().toUtc();

    _database.saveSpeakingAttempt(
      SpeakingAttemptEntity(
        attemptId: id,
        promptId: word.speakingPrompt?.promptId,
        serverWordId: word.serverWordId,
        occurredAtMs: now.millisecondsSinceEpoch,
        retryCount: 0,
        syncStatus: SyncStatus.pending.name,
      ),
    );

    if (isFirst) {
      _enqueueEvent({
        'event_type': 'speaking_first_recording',
        'client_event_id': _uuid.v4(),
        'prompt_id': word.speakingPrompt?.promptId,
        'server_word_id': word.serverWordId,
        'occurred_at': now.toIso8601String(),
      });
    }

    await _audioService.startRecording(id);
    return id;
  }

  /// Stops the active recording. Updates local attempt with duration and
  /// enqueues a `speaking_recorded` event.
  Future<void> stopRecording(VocabularyWord word) async {
    final id = _activeAttemptId;
    if (id == null) return;

    final startMs = _database.getSpeakingAttempt(id)?.occurredAtMs;
    final localPath = await _audioService.stopRecording();

    final durationMs = startMs == null
        ? null
        : DateTime.now().toUtc().millisecondsSinceEpoch - startMs;

    final entity = _database.getSpeakingAttempt(id);
    if (entity != null) {
      entity.localAudioPath = localPath; // local-only, never sent to backend
      entity.durationMs = durationMs;
      _database.updateSpeakingAttempt(entity);
    }

    _enqueueEvent({
      'event_type': SpeakingEventType.recorded,
      'client_event_id': _uuid.v4(),
      'attempt_id': id,
      'prompt_id': word.speakingPrompt?.promptId,
      'server_word_id': word.serverWordId,
      'duration_ms': durationMs,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      // localAudioPath intentionally excluded
    });
  }

  /// Records a retry — increments retry count and enqueues a `speaking_retried`
  /// event.
  void onRetried(VocabularyWord word, String attemptId) {
    final entity = _database.getSpeakingAttempt(attemptId);
    int retryCount = 0;
    if (entity != null) {
      entity.retryCount++;
      retryCount = entity.retryCount;
      _database.updateSpeakingAttempt(entity);
    }
    _enqueueEvent({
      'event_type': SpeakingEventType.retried,
      'client_event_id': _uuid.v4(),
      'attempt_id': attemptId,
      'retry_count': retryCount,
      'prompt_id': word.speakingPrompt?.promptId,
      'server_word_id': word.serverWordId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Records a self-rating and enqueues the correct `speaking_self_rated_*`
  /// event type.
  void onSelfRated(
      VocabularyWord word, String attemptId, SpeakingRating rating) {
    final entity = _database.getSpeakingAttempt(attemptId);
    if (entity != null) {
      entity.selfRating = rating.apiValue;
      _database.updateSpeakingAttempt(entity);
    }
    _enqueueEvent({
      'event_type': rating.eventType,
      'client_event_id': _uuid.v4(),
      'attempt_id': attemptId,
      'prompt_id': word.speakingPrompt?.promptId,
      'server_word_id': word.serverWordId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ---- drill events ----

  /// Emits `speaking_prompt_viewed` when a drill card becomes active.
  void onDrillPromptViewed(SpeakingPromptEntity prompt) {
    _enqueueEvent({
      'event_type': SpeakingEventType.promptViewed,
      'client_event_id': _uuid.v4(),
      'attempt_id': _currentDrillSessionId,
      'prompt_id': prompt.promptId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Emits `speaking_sample_played` when the Listen button is tapped in drill.
  void onDrillSamplePlayed(SpeakingPromptEntity prompt) {
    _enqueueEvent({
      'event_type': SpeakingEventType.samplePlayed,
      'client_event_id': _uuid.v4(),
      'attempt_id': _currentDrillSessionId,
      'prompt_id': prompt.promptId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Starts a drill recording for [promptId]. Returns the new [attemptId].
  Future<String> startDrillRecording({required String promptId}) async {
    final isFirst = _database.countSpeakingAttempts() == 0;
    final id = _uuid.v4();
    _activeAttemptId = id;
    final now = DateTime.now().toUtc();

    _database.saveSpeakingAttempt(
      SpeakingAttemptEntity(
        attemptId: id,
        promptId: promptId,
        serverWordId: null,
        occurredAtMs: now.millisecondsSinceEpoch,
        retryCount: 0,
        syncStatus: SyncStatus.pending.name,
      ),
    );

    if (isFirst) {
      _enqueueEvent({
        'event_type': 'speaking_first_recording',
        'client_event_id': _uuid.v4(),
        'prompt_id': promptId,
        'occurred_at': now.toIso8601String(),
      });
    }

    await _audioService.startRecording(id);
    return id;
  }

  /// Stops the active drill recording. Updates local attempt with duration
  /// and enqueues a `speaking_recorded` event.
  Future<void> stopDrillRecording({required String promptId}) async {
    final id = _activeAttemptId;
    if (id == null) return;

    final startMs = _database.getSpeakingAttempt(id)?.occurredAtMs;
    final localPath = await _audioService.stopRecording();

    final durationMs = startMs == null
        ? null
        : DateTime.now().toUtc().millisecondsSinceEpoch - startMs;

    final entity = _database.getSpeakingAttempt(id);
    if (entity != null) {
      entity.localAudioPath = localPath; // local-only, never sent to backend
      entity.durationMs = durationMs;
      _database.updateSpeakingAttempt(entity);
    }

    _enqueueEvent({
      'event_type': SpeakingEventType.recorded,
      'client_event_id': _uuid.v4(),
      'attempt_id': id,
      'prompt_id': promptId,
      'duration_ms': durationMs,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Emits `speaking_retried` when Try Again is tapped in the drill.
  void onDrillRetried(
      {required String attemptId,
      required String promptId,
      required int retryCount}) {
    final entity = _database.getSpeakingAttempt(attemptId);
    if (entity != null) {
      entity.retryCount = retryCount;
      _database.updateSpeakingAttempt(entity);
    }
    _enqueueEvent({
      'event_type': SpeakingEventType.retried,
      'client_event_id': _uuid.v4(),
      'attempt_id': attemptId,
      'retry_count': retryCount,
      'prompt_id': promptId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Emits the correct `speaking_self_rated_*` event when rating is tapped in drill.
  void onDrillSelfRated({
    required String attemptId,
    required String promptId,
    required SpeakingDrillRating rating,
  }) {
    final entity = _database.getSpeakingAttempt(attemptId);
    if (entity != null) {
      entity.selfRating = rating.storageValue;
      _database.updateSpeakingAttempt(entity);
    }
    _enqueueEvent({
      'event_type': rating.eventType,
      'client_event_id': _uuid.v4(),
      'attempt_id': attemptId,
      'prompt_id': promptId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Emits `speaking_drill_completed` at the end of a drill session.
  void onDrillCompleted({
    required int promptsAttempted,
    required int promptsCompleted,
    required int totalDurationMs,
  }) {
    _enqueueEvent({
      'event_type': SpeakingEventType.drillCompleted,
      'client_event_id': _uuid.v4(),
      'attempt_id': _currentDrillSessionId,
      'prompts_attempted': promptsAttempted,
      'prompts_completed': promptsCompleted,
      'total_duration_ms': totalDurationMs,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    _currentDrillSessionId = null;
  }

  // ---- TTS playback ----

  Future<void> playSample(String text, {String languageCode = 'en-US'}) =>
      _audioService.speakSample(text, languageCode: languageCode);

  Future<void> stopSample() => _audioService.stopSample();

  Future<void> playLocalRecording(String localAudioPath) =>
      _audioService.playLocal(localAudioPath);

  Future<void> stopPlayback() => _audioService.stopPlayback();

  // ---- retention / deletion ----

  Future<int> runRetentionCleanup() => _fileManager.runRetentionCleanup();

  Future<bool> deleteOneRecording(String localAudioPath) =>
      _fileManager.deleteOne(localAudioPath);

  Future<int> deleteAllRecordings() async {
    await _fileManager.deleteAll();
    return _database.deleteAllSpeakingAttempts();
  }

  // ---- lifecycle ----

  Future<void> dispose() => _audioService.dispose();

  // ---- private helpers ----

  void _enqueueEvent(Map<String, dynamic> payload) {
    // Guard: ensure localAudioPath never enters the payload
    payload.remove('local_audio_path');
    _database.enqueueSpeakingEvent(jsonEncode(payload));
  }
}

import 'dart:convert';

import 'package:uuid/uuid.dart';

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
  static const selfRated = 'speaking_self_rated';
}

/// Self-rating values.
enum SpeakingRating { easy, ok, hard }

extension SpeakingRatingApi on SpeakingRating {
  String get apiValue => switch (this) {
        SpeakingRating.easy => 'easy',
        SpeakingRating.ok => 'ok',
        SpeakingRating.hard => 'hard',
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

  /// Returns up to [count] prompts for the 3-minute drill, from recent cache.
  List<SpeakingPromptEntity> selectDrillPrompts({int count = 5}) {
    return _database.recentCachedPrompts(limit: count);
  }

  // ---- events ----

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

  // ---- recording lifecycle ----

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
    if (entity != null) {
      entity.retryCount++;
      _database.updateSpeakingAttempt(entity);
    }
    _enqueueEvent({
      'event_type': SpeakingEventType.retried,
      'client_event_id': _uuid.v4(),
      'attempt_id': attemptId,
      'prompt_id': word.speakingPrompt?.promptId,
      'server_word_id': word.serverWordId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Records a self-rating and enqueues a `speaking_self_rated` event.
  void onSelfRated(
      VocabularyWord word, String attemptId, SpeakingRating rating) {
    final entity = _database.getSpeakingAttempt(attemptId);
    if (entity != null) {
      entity.selfRating = rating.apiValue;
      _database.updateSpeakingAttempt(entity);
    }
    _enqueueEvent({
      'event_type': SpeakingEventType.selfRated,
      'client_event_id': _uuid.v4(),
      'attempt_id': attemptId,
      'prompt_id': word.speakingPrompt?.promptId,
      'server_word_id': word.serverWordId,
      'self_rating': rating.apiValue,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
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

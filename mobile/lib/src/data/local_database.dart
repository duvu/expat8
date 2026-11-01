import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../objectbox.g.dart';
import '../logging/logger.dart';
import '../models/learning_progress.dart';
import '../models/review_state.dart';
import '../models/submitted_word.dart';
import '../models/study_event.dart';
import '../models/sync_queue_entry.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';
import '../models/workplace_sentence.dart';
import '../curriculum/curriculum.dart' show subjectOf;
import '../curriculum/skill_mastery.dart';
import '../srs/srs_scheduler.dart';
import 'local_database_entities.dart';

part 'local_database_logs.dart';
part 'local_database_words.dart';
part 'local_database_sentences.dart';
part 'local_database_progress.dart';
part 'local_database_identity.dart';
part 'local_database_sync.dart';
part 'local_database_speaking.dart';
part 'local_database_exams.dart';
part 'local_database_memorization.dart';
part 'local_database_shadowing.dart';
part 'local_database_engagement.dart';
part 'local_database_skills.dart';

class LocalDatabase {
  LocalDatabase(this._store, {Logger? logger})
      : _logger = logger ?? const NoopLogger(),
        _localWords = _store.box<LocalWordEntity>(),
        _localWorkplaceSentences = _store.box<LocalWorkplaceSentenceEntity>(),
        _studyEvents = _store.box<StudyEventEntity>(),
        _syncQueue = _store.box<SyncQueueEntity>(),
        _submittedWords = _store.box<SubmittedWordEntity>(),
        _learningHistory = _store.box<LearningHistoryEntity>(),
        _settings = _store.box<AppSettingEntity>(),
        _logs = _store.box<AppLogEntity>(),
        _speakingPrompts = _store.box<SpeakingPromptEntity>(),
        _speakingAttempts = _store.box<SpeakingAttemptEntity>(),
        _examAttempts = _store.box<ExamAttemptEntity>(),
        _passages = _store.box<LocalPassageEntity>(),
        _segments = _store.box<LocalSegmentEntity>(),
        _segmentProgress = _store.box<LocalSegmentProgressEntity>(),
        _shadowingVideos = _store.box<ShadowingVideoEntity>(),
        _shadowingSegments = _store.box<ShadowingSegmentEntity>(),
        _shadowingProgress = _store.box<ShadowingProgressEntity>(),
        _skillAnswers = _store.box<SkillAnswerEntity>();
  final Store _store;
  Logger _logger;
  final Box<LocalWordEntity> _localWords;
  final Box<LocalWorkplaceSentenceEntity> _localWorkplaceSentences;
  final Box<StudyEventEntity> _studyEvents;
  final Box<SyncQueueEntity> _syncQueue;
  final Box<SubmittedWordEntity> _submittedWords;
  final Box<LearningHistoryEntity> _learningHistory;
  final Box<AppSettingEntity> _settings;
  final Box<AppLogEntity> _logs;
  final Box<SpeakingPromptEntity> _speakingPrompts;
  final Box<SpeakingAttemptEntity> _speakingAttempts;
  final Box<ExamAttemptEntity> _examAttempts;
  final Box<LocalPassageEntity> _passages;
  final Box<LocalSegmentEntity> _segments;
  final Box<LocalSegmentProgressEntity> _segmentProgress;
  final Box<ShadowingVideoEntity> _shadowingVideos;
  final Box<ShadowingSegmentEntity> _shadowingSegments;
  final Box<ShadowingProgressEntity> _shadowingProgress;
  final Box<SkillAnswerEntity> _skillAnswers;
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
    final database = LocalDatabase(store);
    await database._backfillLearningStateFields();
    return database;
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
  } // Log rows are buffered and written in batches on ObjectBox's background

  // worker: a synchronous put per log line on the UI isolate (several per API
  // call) caused frame drops.
  final List<AppLogEntity> _pendingLogs = [];
  Timer? _logFlushTimer;
  Future<void>? _logFlush;
  static const _logFlushDelay = Duration(seconds: 2);
  static const _logFlushBatch = 50;
  static final List<String> _activeReviewStatuses = [
    WordStatus.learning.name,
    WordStatus.review.name,
    WordStatus.mastered.name,
  ];
  Future<void> close() async {
    await flushLogs();
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
      entryType: row.entryType.isEmpty ? 'word' : row.entryType,
      explanation: row.explanation,
    );
  }

  DateTime? _parseDateMs(int? value) {
    if (value == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
}

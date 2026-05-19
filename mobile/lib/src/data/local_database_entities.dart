import 'package:objectbox/objectbox.dart';

@Entity()
class LocalWordEntity {
  LocalWordEntity({
    this.id = 0,
    required this.localId,
    this.serverWordId,
    required this.term,
    required this.language,
    required this.meaningVi,
    this.partOfSpeech,
    required this.ipa,
    required this.vietnamesePronunciation,
    required this.example,
    required this.exampleVi,
    required this.difficulty,
    required this.topicsJson,
    required this.status,
    this.lastSeenAtMs,
    this.nextReviewAtMs,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.entryType = 'word',
    this.explanation = '',
    this.learningState = '',
    this.learningStateAtMs,
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String localId;

  @Index()
  String? serverWordId;

  String term;
  String language;
  String meaningVi;
  String? partOfSpeech;
  String ipa;
  String vietnamesePronunciation;
  String example;
  String exampleVi;
  String difficulty;
  String topicsJson;

  @Index()
  String status;

  @Index()
  int? lastSeenAtMs;

  @Index()
  int? nextReviewAtMs;

  @Index()
  int createdAtMs;
  int updatedAtMs;

  String entryType;
  String explanation;

  @Index()
  String learningState = '';

  @Index()
  int? learningStateAtMs;
}

@Entity()
class LocalWorkplaceSentenceEntity {
  LocalWorkplaceSentenceEntity({
    this.id = 0,
    required this.localId,
    this.serverSentenceId,
    required this.text,
    required this.language,
    required this.meaningVi,
    this.topic,
    this.sourceTitle,
    required this.generationSource,
    required this.isBundled,
    required this.status,
    this.lastSeenAtMs,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.learningState = '',
    this.learningStateAtMs,
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String localId;

  @Index()
  String? serverSentenceId;

  String text;
  String language;
  String meaningVi;
  String? topic;
  String? sourceTitle;
  String generationSource;

  /// ObjectBox stores booleans as 0/1 scalar values.
  int isBundled;

  @Index()
  String status;

  @Index()
  int? lastSeenAtMs;

  @Index()
  int createdAtMs;
  int updatedAtMs;

  @Index()
  String learningState = '';

  @Index()
  int? learningStateAtMs;
}

@Entity()
class StudyEventEntity {
  StudyEventEntity({
    this.id = 0,
    required this.clientEventId,
    required this.localWordId,
    this.serverWordId,
    required this.rating,
    required this.occurredAtMs,
    required this.syncStatus,
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String clientEventId;

  String localWordId;
  String? serverWordId;
  String rating;
  int occurredAtMs;

  @Index()
  String syncStatus;
}

@Entity()
class SyncQueueEntity {
  SyncQueueEntity({
    this.id = 0,
    required this.type,
    required this.payload,
    required this.retryCount,
    required this.nextRetryAtMs,
    required this.createdAtMs,
  });

  int id;
  String type;
  String payload;
  int retryCount;

  @Index()
  int nextRetryAtMs;

  @Index()
  int createdAtMs;
}

@Entity()
class SubmittedWordEntity {
  SubmittedWordEntity({
    this.id = 0,
    required this.localSubmissionId,
    this.serverSubmissionId,
    required this.submittedTerm,
    required this.targetLanguage,
    required this.status,
    this.failureReason,
    this.resolutionType,
    this.resolvedWordServerId,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.resolvedAtMs,
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String localSubmissionId;

  @Index()
  String? serverSubmissionId;

  String submittedTerm;

  @Index()
  String targetLanguage;

  @Index()
  String status;

  String? failureReason;
  String? resolutionType;

  @Index()
  String? resolvedWordServerId;

  @Index()
  int createdAtMs;

  @Index()
  int updatedAtMs;

  @Index()
  int? resolvedAtMs;
}

@Entity()
class LearningHistoryEntity {
  LearningHistoryEntity({
    this.id = 0,
    required this.snapshotJson,
    required this.learningState,
    required this.occurredAtMs,
  });

  int id;

  String snapshotJson;

  @Index()
  String learningState;

  @Index()
  int occurredAtMs;
}

@Entity()
class AppSettingEntity {
  AppSettingEntity({
    this.id = 0,
    required this.key,
    required this.value,
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String key;

  String value;
}

@Entity()
class AppLogEntity {
  AppLogEntity({
    this.id = 0,
    required this.timestampMs,
    required this.level,
    required this.category,
    required this.event,
    required this.message,
    this.traceId,
    required this.contextJson,
  });

  int id;

  @Index()
  int timestampMs;

  @Index()
  String level;

  @Index()
  String category;

  String event;
  String message;
  String? traceId;
  String contextJson;
}

/// Local cache of a speaking prompt received from the backend.
/// Keyed by [promptId] (the server-assigned UUID).
/// Updated whenever the vocabulary card response includes a speaking prompt.
@Entity()
class SpeakingPromptEntity {
  SpeakingPromptEntity({
    this.id = 0,
    required this.promptId,
    this.wordSenseId,
    this.serverWordId,
    this.targetText,
    this.viHint,
    this.targetPhrase,
    this.pronunciationTip,
    this.commonMistake,
    this.difficulty,
    this.topic,
    required this.cachedAtMs,
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String promptId;

  @Index()
  String? wordSenseId;

  @Index()
  String? serverWordId;

  String? targetText;
  String? viHint;
  String? targetPhrase;
  String? pronunciationTip;
  String? commonMistake;
  String? difficulty;
  String? topic;

  @Index()
  int cachedAtMs;
}

/// Metadata for a single speaking attempt recorded by the user.
///
/// [localAudioPath] is device-local only — it MUST NEVER be included in:
///   • backend API request bodies
///   • sync queue payloads
///   • application logs
@Entity()
class SpeakingAttemptEntity {
  SpeakingAttemptEntity({
    this.id = 0,
    required this.attemptId,
    this.promptId,
    this.serverWordId,
    required this.occurredAtMs,
    this.durationMs,
    required this.retryCount,
    this.selfRating,
    required this.syncStatus,
    this.localAudioPath,
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String attemptId;

  @Index()
  String? promptId;

  @Index()
  String? serverWordId;

  @Index()
  int occurredAtMs;

  int? durationMs;
  int retryCount;

  /// null = not yet rated; values: "easy", "ok", "hard"
  String? selfRating;

  @Index()
  String syncStatus;

  /// Local file path — kept here for playback ONLY.
  /// Strip this field before any network transmission.
  String? localAudioPath;
}

@Entity()
class ExamAttemptEntity {
  ExamAttemptEntity({
    this.id = 0,
    required this.attemptId,
    required this.sessionId,
    required this.topic,
    required this.language,
    this.difficultyLevel,
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePct,
    required this.passed,
    required this.createdAtMs,
    this.certificateId,
    this.syncStatus = 'synced',
  });

  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String attemptId;

  @Index()
  String sessionId;

  @Index()
  String topic;

  @Index()
  String language;

  String? difficultyLevel;

  int totalQuestions;
  int correctCount;

  /// Score as a percentage (0–100).
  double scorePct;

  /// 1 = passed, 0 = failed.
  int passed;

  @Index()
  int createdAtMs;

  /// Non-null when the attempt produced a certificate.
  String? certificateId;

  /// Sync status: 'pending' (not yet confirmed by backend) or 'synced'.
  @Index()
  String syncStatus;
}

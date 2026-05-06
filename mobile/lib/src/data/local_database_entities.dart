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

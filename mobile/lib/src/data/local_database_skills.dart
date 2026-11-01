part of 'local_database.dart';

/// Per-account answers to skill-tagged questions (see curriculum/).
extension LocalDatabaseSkills on LocalDatabase {
  Future<void> addSkillAnswer(SkillAnswer answer,
      {required String? ownerUserId}) async {
    _skillAnswers.put(SkillAnswerEntity(
      ownerUserId: ownerUserId,
      subject: subjectOf(answer.skillId),
      skillId: answer.skillId,
      correct: answer.correct,
      elapsedMs: answer.elapsedMs,
      answeredAtMs: answer.answeredAtMs,
      source: answer.source,
    ));
  }

  /// Every answer of one account (null = answers given while signed out),
  /// optionally limited to one [subject].
  Future<List<SkillAnswer>> skillAnswers({
    required String? ownerUserId,
    String? subject,
  }) async {
    var condition = ownerUserId == null
        ? SkillAnswerEntity_.ownerUserId.isNull()
        : SkillAnswerEntity_.ownerUserId.equals(ownerUserId);
    if (subject != null) {
      condition = condition & SkillAnswerEntity_.subject.equals(subject);
    }
    final query = _skillAnswers.query(condition).build();
    try {
      return [
        for (final e in query.find())
          SkillAnswer(
            skillId: e.skillId,
            correct: e.correct,
            elapsedMs: e.elapsedMs,
            answeredAtMs: e.answeredAtMs,
            source: e.source,
          ),
      ];
    } finally {
      query.close();
    }
  }
}

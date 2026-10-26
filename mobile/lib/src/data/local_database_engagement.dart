part of 'local_database.dart';

/// Read-only queries behind streaks, the daily goal and due-soon counts.
extension LocalDatabaseEngagement on LocalDatabase {
  /// Times (epoch ms, UTC) of every study event of one account; a null
  /// [ownerUserId] selects the events studied while signed out.
  Future<List<int>> studyEventTimesMs({required String? ownerUserId}) async {
    final condition = ownerUserId == null
        ? StudyEventEntity_.ownerUserId.isNull()
        : StudyEventEntity_.ownerUserId.equals(ownerUserId);
    final query = _studyEvents.query(condition).build();
    try {
      return query.property(StudyEventEntity_.occurredAtMs).find();
    } finally {
      query.close();
    }
  }

  /// Next-review times (epoch ms, UTC) of words in review for [language];
  /// unscheduled words are reported as 0, i.e. already due.
  Future<List<int>> reviewScheduleMs({required String language}) async {
    final query = _localWords
        .query(LocalWordEntity_.language.equals(language) &
            LocalWordEntity_.status.oneOf(LocalDatabase._activeReviewStatuses))
        .build();
    try {
      return query
          .property(LocalWordEntity_.nextReviewAtMs)
          .find(replaceNullWith: 0);
    } finally {
      query.close();
    }
  }
}

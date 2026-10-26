import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/review_state.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';

/// Offline backend: every upload and the immediate submit fail, except the
/// explicit sync, which records which account each event was uploaded under.
class _FamilyBackend extends BackendApiClient {
  _FamilyBackend()
      : super(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'a',
            appSecret: 's');

  final uploadedBy = <String, String?>{}; // client_event_id -> session token
  List<ReviewStatesPage> pages = [];
  final requestedCursors = <String?>[];

  @override
  Future<UserSession> signIn({
    required String identifier,
    required String password,
    String? deviceId,
  }) async =>
      UserSession(
          userId: identifier, identifier: identifier, sessionToken: identifier);

  @override
  Future<void> signOut({required UserSession session}) async {}

  @override
  Future<StudyEventResult> submitStudyEvent({
    required String deviceId,
    required Map<String, dynamic> event,
    String language = 'en',
    String? sessionToken,
  }) =>
      throw StateError('offline');

  @override
  Future<CacheInventoryResult> syncCacheInventory({
    required String deviceId,
    required List<String> serverWordIds,
    DateTime? observedAt,
    String? sessionToken,
  }) =>
      throw StateError('offline');

  @override
  Future<SyncResult> syncStudyEvents({
    required String deviceId,
    required List<Map<String, dynamic>> events,
    String? sessionToken,
    String? language,
  }) async {
    for (final e in events) {
      expect(e.containsKey('owner_user_id'), isFalse,
          reason: 'the owner never leaves the device');
      uploadedBy[e['client_event_id'] as String] = sessionToken;
    }
    return SyncResult(
      acceptedEventIds: [
        for (final e in events) e['client_event_id'] as String
      ],
      rejectedEvents: const [],
    );
  }

  @override
  Future<ReviewStatesPage> fetchReviewStates({
    required String deviceId,
    required String language,
    String? cursor,
    String? sessionToken,
  }) async {
    requestedCursors.add(cursor);
    return pages.removeAt(0);
  }
}

VocabularyWord _word(String id) {
  final at = DateTime.utc(2026, 1, 1);
  return VocabularyWord(
    localId: id,
    serverWordId: id,
    term: id,
    language: 'en',
    meaningVi: 'nghĩa $id',
    ipa: '',
    vietnamesePronunciation: '',
    example: '',
    exampleVi: '',
    difficulty: 'A1',
    topics: const [],
    status: WordStatus.newWord,
    createdAt: at,
    updatedAt: at,
  );
}

ServerReviewState _state(String id,
        {required int reps, required DateTime due}) =>
    ServerReviewState(
      word: _word(id),
      status: WordStatus.review,
      nextReviewAt: due,
      lastStudiedAt: due.subtract(const Duration(days: 6)),
      ease: 2.5,
      intervalDays: 6,
      reps: reps,
      lapses: 0,
    );

void main() {
  late LocalDatabase db;
  late _FamilyBackend api;
  late WordRepository repo;
  final now = DateTime.utc(2026, 3, 1, 8);

  setUp(() async {
    db = await LocalDatabase.open(
        databaseName: 'family_${DateTime.now().microsecondsSinceEpoch}.db');
    api = _FamilyBackend();
    repo = WordRepository(database: db, apiClient: api);
    await db.addBatch([_word('apple'), _word('river')]);
  });
  tearDown(() => db.close());

  Future<VocabularyWord?> dueOn(DateTime at) => db.nextDueReviewWord(at);

  test('a shared device keeps each family member\'s schedule and uploads',
      () async {
    await repo.signInUser(identifier: 'parent', password: 'x');
    await repo.recordRating(
        word: _word('apple'),
        rating: StudyRating.tooHard,
        now: now,
        deviceId: 'tablet');
    expect(
        (await dueOn(now.add(const Duration(minutes: 10))))?.localId, 'apple');

    // The parent hands the tablet to a child, still offline.
    await repo.signOutUser();
    await repo.signInUser(identifier: 'kid', password: 'x');
    expect(await dueOn(now.add(const Duration(days: 1))), isNull,
        reason: "the parent's forgotten word is not the kid's review");
    await repo.recordRating(
        word: _word('river'),
        rating: StudyRating.easy,
        now: now,
        deviceId: 'tablet');

    // Back online with the kid signed in: only the kid's event is uploaded.
    await repo.syncPendingEvents(deviceId: 'tablet');
    expect(api.uploadedBy.values.toSet(), {'kid'});

    // The parent signs in again: their schedule is rebuilt and uploaded.
    await repo.signOutUser();
    await repo.signInUser(identifier: 'parent', password: 'x');
    expect(
        (await dueOn(now.add(const Duration(minutes: 10))))?.localId, 'apple');
    expect(await dueOn(now.add(const Duration(days: 2))),
        isNot(predicate<VocabularyWord?>((w) => w?.localId == 'river')));
    await repo.syncPendingEvents(deviceId: 'tablet');
    expect(api.uploadedBy.values.toList()..sort(), ['kid', 'parent']);
  });

  test('upgrading keeps a signed-in learner\'s schedule and progress',
      () async {
    // Before this version events had no owner (recorded here before the
    // session exists, so none is stamped), while the learner was signed in.
    final studiedAt = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch -
            const Duration(days: 1).inMilliseconds,
        isUtc: true);
    await db.insertStudyEvent(StudyEvent(
      clientEventId: 'legacy-1',
      localWordId: 'apple',
      serverWordId: 'apple',
      rating: StudyRating.easy,
      occurredAt: studiedAt,
      syncStatus: SyncStatus.pending,
    ));
    await db.updateWordAfterRating(
        word: _word('apple'), rating: StudyRating.easy, now: studiedAt);
    await db.markWordLearned(word: _word('river'), now: studiedAt);
    await db.saveUserSession(const UserSession(
        userId: 'parent', identifier: 'parent', sessionToken: 'parent'));
    final before = await db.getLearningProgressTotals();

    await repo.upgradeLocalSchedule();

    final apple = (await db.wordsForLanguage('en'))
        .singleWhere((w) => w.localId == 'apple');
    expect(apple.status, WordStatus.review);
    expect(apple.nextReviewAt, studiedAt.add(const Duration(days: 2)));
    final after = await db.getLearningProgressTotals();
    expect(after.learned, before.learned);
    expect(after.total, before.total);
    // The parent's queued event is still uploaded under the parent.
    await repo.syncPendingEvents(deviceId: 'tablet');
    expect(api.uploadedBy, {'legacy-1': 'parent'});
  });

  test('pulls every page, stores the cursor, keeps words rated offline',
      () async {
    await repo.signInUser(identifier: 'parent', password: 'x');
    // Rated offline after the server state was computed: still pending.
    await repo.recordRating(
        word: _word('apple'),
        rating: StudyRating.tooHard,
        now: now,
        deviceId: 'tablet');
    final due = now.add(const Duration(days: 6));
    api.pages = [
      ReviewStatesPage(
          items: [_state('apple', reps: 2, due: due)],
          nextCursor: 'c1',
          hasMore: true),
      ReviewStatesPage(
          items: [_state('lemon', reps: 2, due: due)],
          nextCursor: 'c2',
          hasMore: false),
    ];

    await repo.pullReviewStates(deviceId: 'tablet');

    expect(api.requestedCursors, [null, 'c1']);
    expect(await db.getSetting('srs.pull.cursor.parent.en'), 'c2');
    // A word studied on another device arrives with its schedule.
    final lemon = await db.getWordByServerId('lemon');
    expect(lemon?.status, WordStatus.review);
    expect(lemon?.nextReviewAt, due);
    // The pending offline lapse wins until it is uploaded.
    expect(
        (await dueOn(now.add(const Duration(minutes: 10))))?.localId, 'apple');
  });
}

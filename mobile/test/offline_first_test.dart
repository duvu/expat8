import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/article_repository.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/memorization_repository.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/article.dart';
import 'package:expat8_language_app/src/models/memorization_passage.dart';
import 'package:expat8_language_app/src/models/proficiency_state.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/network/connectivity_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// API client whose reachability can be toggled.
class _SwitchableApi extends BackendApiClient {
  _SwitchableApi()
      : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  bool online = true;
  int syncCalls = 0;
  Completer<void>? syncGate;
  List<MemorizationPassage> passages = [];
  List<ManagedArticle> articles = [];
  Object? syncError;

  void _ensureOnline() {
    if (!online) throw BackendApiException('Network is unreachable');
  }

  @override
  Future<SyncResult> syncStudyEvents({
    required String deviceId,
    required List<Map<String, dynamic>> events,
    String? sessionToken,
    String? language,
  }) async {
    syncCalls++;
    await syncGate?.future;
    _ensureOnline();
    final error = syncError;
    if (error != null) throw error;
    return SyncResult(
      acceptedEventIds: [for (final e in events) e['client_event_id'] as String],
      rejectedEvents: const [],
    );
  }

  @override
  Future<ProficiencyState> fetchProficiency({
    required String deviceId,
    String language = 'en',
    String? sessionToken,
  }) async {
    _ensureOnline();
    return ProficiencyState(
      scale: 'cefr',
      level: 'B2',
      levelIndex: 3,
      language: language,
    );
  }

  @override
  Future<List<MemorizationPassage>> listPassages({
    required String sessionToken,
  }) async {
    _ensureOnline();
    return passages;
  }

  @override
  Future<List<MemorizationSegmentProgress>> getPassageProgress({
    required String sessionToken,
    required String passageId,
  }) async {
    _ensureOnline();
    return [
      const MemorizationSegmentProgress(
        segmentId: 'seg_1',
        status: 'learning',
        reviewCount: 2,
      ),
    ];
  }

  @override
  Future<List<ManagedArticle>> listArticles({
    required String sessionToken,
  }) async {
    _ensureOnline();
    return articles;
  }
}

Future<LocalDatabase> _openDb(String name) => LocalDatabase.open(
      databaseName: '${name}_${DateTime.now().microsecondsSinceEpoch}.db',
    );

StudyEvent _event(String id) => StudyEvent(
      clientEventId: id,
      localWordId: 'local_$id',
      serverWordId: 'server_$id',
      rating: StudyRating.easy,
      occurredAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.pending,
      language: 'zh',
    );

MemorizationPassage _passage(String id) => MemorizationPassage(
      id: id,
      title: 'Passage $id',
      language: 'en',
      status: 'ready',
      visibility: 'private',
      segmentCount: 1,
      createdAt: '2026-09-28T00:00:00.000Z',
    );

void main() {
  test('concurrent sync triggers share one run', () async {
    final db = await _openDb('offline_sync_guard');
    addTearDown(db.close);
    final api = _SwitchableApi()..syncGate = Completer<void>();
    final repository = WordRepository(database: db, apiClient: api);
    await db.insertStudyEvent(_event('evt_guard'));

    final later = DateTime.now().toUtc().add(const Duration(minutes: 1));
    final first = repository.syncPendingEvents(deviceId: 'd', now: later);
    final second = repository.syncPendingEvents(deviceId: 'd', now: later);
    api.syncGate!.complete();
    await Future.wait([first, second]);

    expect(api.syncCalls, 1);
  });

  test('offline events stay queued and sync with their language when online',
      () async {
    final db = await _openDb('offline_sync_replay');
    addTearDown(db.close);
    final api = _SwitchableApi()..online = false;
    final repository = WordRepository(database: db, apiClient: api);
    await db.insertStudyEvent(_event('evt_offline'));
    final farFuture = DateTime.now().toUtc().add(const Duration(days: 1));

    final afterBackoff = farFuture.add(const Duration(hours: 1));

    await repository.syncPendingEvents(deviceId: 'd', now: farFuture);
    expect(await db.dueSyncEntries(afterBackoff), isNotEmpty);

    api.online = true;
    await repository.syncPendingEvents(deviceId: 'd', now: afterBackoff);
    expect(await db.dueSyncEntries(afterBackoff), isEmpty);
  });

  test('permanently rejected requests are dropped instead of retried forever',
      () async {
    final db = await _openDb('offline_sync_permanent');
    addTearDown(db.close);
    final api = _SwitchableApi()
      ..syncError = BackendApiException('bad', statusCode: 400);
    final repository = WordRepository(database: db, apiClient: api);
    await db.insertStudyEvent(_event('evt_bad'));
    final farFuture = DateTime.now().toUtc().add(const Duration(days: 1));

    await repository.syncPendingEvents(deviceId: 'd', now: farFuture);
    expect(await db.dueSyncEntries(farFuture), isEmpty);
  });

  test('server errors keep the entry queued for retry', () async {
    final db = await _openDb('offline_sync_transient');
    addTearDown(db.close);
    final api = _SwitchableApi()
      ..syncError = BackendApiException('unavailable', statusCode: 503);
    final repository = WordRepository(database: db, apiClient: api);
    await db.insertStudyEvent(_event('evt_503'));
    final farFuture = DateTime.now().toUtc().add(const Duration(days: 1));

    await repository.syncPendingEvents(deviceId: 'd', now: farFuture);
    expect(
      await db.dueSyncEntries(farFuture.add(const Duration(hours: 1))),
      isNotEmpty,
    );
  });

  test('proficiency level is remembered for offline restarts', () async {
    final db = await _openDb('offline_proficiency');
    addTearDown(db.close);
    final api = _SwitchableApi();
    final repository = WordRepository(database: db, apiClient: api);

    await repository.fetchProficiency(deviceId: 'd', language: 'en');
    api.online = false;

    final cached = await repository.loadCachedProficiency('en');
    expect(cached?.level, 'B2');
    expect(await repository.loadCachedProficiency('zh'), isNull);
  });

  test('memorization passages and progress are served from cache offline',
      () async {
    final db = await _openDb('offline_memorization');
    addTearDown(db.close);
    final api = _SwitchableApi()..passages = [_passage('p1'), _passage('p2')];
    final repository = MemorizationRepository(apiClient: api, localDb: db);

    final online = await repository.loadPassages(sessionToken: 't');
    expect(online.fromCache, isFalse);
    await repository.loadPassageProgress(sessionToken: 't', passageId: 'p1');

    // p2 was deleted on the server; the next online refresh removes it.
    api.passages = [_passage('p1')];
    await repository.loadPassages(sessionToken: 't');

    api.online = false;
    final offline = await repository.loadPassages(sessionToken: 't');
    expect(offline.fromCache, isTrue);
    expect(offline.data.map((p) => p.id), ['p1']);
    final progress =
        await repository.loadPassageProgress(sessionToken: 't', passageId: 'p1');
    expect(progress.single.reviewCount, 2);
  });

  test('articles are served from the per-account cache offline', () async {
    final db = await _openDb('offline_articles');
    addTearDown(db.close);
    await db.saveUserSession(const UserSession(
      userId: 'user_1',
      identifier: 'a@example.com',
      sessionToken: 't',
    ));
    final api = _SwitchableApi()
      ..articles = [
        ManagedArticle(
          id: 'a1',
          title: 'Offline article',
          language: 'en',
          visibility: 'private',
          status: 'processed',
          createdAt: DateTime.utc(2026, 9, 28),
          updatedAt: DateTime.utc(2026, 9, 28),
        ),
      ];
    final repository = ArticleRepository(apiClient: api, localDb: db);

    await repository.loadArticles(sessionToken: 't');
    api.online = false;
    final offline = await repository.loadArticles(sessionToken: 't');
    expect(offline.fromCache, isTrue);
    expect(offline.data.single.title, 'Offline article');

    // Another account on the same device does not see these articles.
    await db.saveUserSession(const UserSession(
      userId: 'user_2',
      identifier: 'b@example.com',
      sessionToken: 't2',
    ));
    expect(
      () => repository.loadArticles(sessionToken: 't2'),
      throwsA(isA<BackendApiException>()),
    );
  });

  test('connectivity monitor fires reconnect only on offline to online', () async {
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    final monitor = ConnectivityMonitor(
      changes: changes.stream,
      check: () async => [ConnectivityResult.none],
    );
    var reconnects = 0;
    monitor.onReconnect(() => reconnects++);
    await monitor.start();
    expect(monitor.isOnline, isFalse);

    changes.add([ConnectivityResult.none]);
    changes.add([ConnectivityResult.wifi]);
    changes.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);

    expect(monitor.isOnline, isTrue);
    expect(reconnects, 1);
    monitor.dispose();
  });
}

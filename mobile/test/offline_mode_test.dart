import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/study_event.dart';
import 'package:expat8_language_app/src/session/learning_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Every request fails the way it does with no network / backend down.
BackendApiClient unreachableBackend() => BackendApiClient(
      baseUrl: 'https://backend.invalid',
      timeout: const Duration(seconds: 1),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: MockClient(
        (request) async => throw http.ClientException('Network is unreachable'),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('learning works with no backend: seed, study, rate, queue for sync',
      () async {
    final database = await LocalDatabase.open(
      databaseName:
          'offline_mode_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    addTearDown(database.close);
    final repository =
        WordRepository(database: database, apiClient: unreachableBackend());

    final seeded = await repository.seedFromBundleIfEmpty(languages: ['en']);
    expect(seeded, greaterThan(0), reason: 'bundled vocabulary is available');

    final controller = LearningSessionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadInitial();

    final first = controller.currentWord;
    expect(first, isNotNull, reason: 'a card is shown without the backend');

    await controller.rateCurrent(StudyRating.easy);
    expect(controller.currentWord, isNotNull);

    // The rating is kept locally and retried later instead of being lost.
    final deviceId = await repository.getOrCreateDeviceId();
    await repository.syncPendingEvents(deviceId: deviceId);
    final queued = await database
        .dueSyncEntries(DateTime.now().toUtc().add(const Duration(days: 1)));
    expect(queued, isNotEmpty);
  });
}

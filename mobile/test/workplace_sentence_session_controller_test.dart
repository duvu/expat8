import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_repository.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_seed_loader.dart';
import 'package:expat8_language_app/src/models/workplace_sentence.dart';
import 'package:expat8_language_app/src/session/workplace_sentence_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadInitial shows bundled sentence even when refill fails', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_controller_offline_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _FailingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [_sentence('offline_seed_1', createdAt: DateTime.utc(2026, 5, 16, 0))],
      }),
    );
    final controller = WorkplaceSentenceSessionController(repository: repository);

    await controller.loadInitial();

    expect(controller.currentSentence, isNotNull);
    expect(controller.currentSentence?.localId, 'offline_seed_1');
    expect(controller.statusMessage, isNull);
  });

  test('showNextSentence continues through local bundle while refill fails', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_controller_next_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _FailingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('offline_seed_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('offline_seed_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );
    final controller = WorkplaceSentenceSessionController(repository: repository);

    await controller.loadInitial();
    final firstId = controller.currentSentence?.localId;

    await controller.showNextSentence();

    expect(controller.currentSentence, isNotNull);
    expect(controller.currentSentence?.localId, isNot(firstId));
  });

  test('showNextSentence falls back to learned sentences after unseen pool is exhausted', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_controller_rotation_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _FailingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('offline_seed_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('offline_seed_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );
    final controller = WorkplaceSentenceSessionController(repository: repository);

    await controller.loadInitial();
    final firstId = controller.currentSentence?.localId;

    await controller.showNextSentence();
    final secondId = controller.currentSentence?.localId;

    await controller.showNextSentence();
    final thirdId = controller.currentSentence?.localId;

    expect(firstId, isNotNull);
    expect(secondId, isNotNull);
    expect(thirdId, isNotNull);
    expect({firstId, secondId, thirdId}.length, 2);
    expect(controller.currentSentence?.status, WorkplaceSentenceStatus.seen);
  });

  test('right-to-left swipe records learned sentence and advances', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_controller_rtl_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _FailingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('rtl_sentence_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('rtl_sentence_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );
    final controller = WorkplaceSentenceSessionController(repository: repository);

    await controller.loadInitial();
    final before = controller.currentSentence?.localId;

    await controller.onSwipeRightToLeft();

    expect(before, isNotNull);
    expect(controller.currentSentence?.localId, isNot(before));
    final history = await database.getLearningHistory();
    expect(history, hasLength(1));
    expect(history.single.snapshot.localId, before);
    expect(history.single.stateLabel, 'Learned');
  });

  test('left-to-right swipe opens history without mutating state', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_controller_ltr_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _FailingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('ltr_sentence_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('ltr_sentence_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );
    final controller = WorkplaceSentenceSessionController(repository: repository);

    await controller.loadInitial();
    final before = controller.currentSentence?.localId;

    await controller.onSwipeLeftToRight();

    expect(controller.currentSentence?.localId, before);
    expect(await database.getLearningHistory(), isEmpty);
  });

  test('bottom-to-top swipe marks sentence remembered and advances', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_controller_btt_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _FailingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('btt_sentence_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('btt_sentence_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );
    final controller = WorkplaceSentenceSessionController(repository: repository);

    await controller.loadInitial();
    final before = controller.currentSentence?.localId;

    await controller.onSwipeBottomToTop();

    final totals = await database.getLearningProgressTotals();
    expect(controller.currentSentence?.localId, isNot(before));
    expect(totals.remembered, 1);
  });

  test('top-to-bottom swipe marks sentence difficult and advances', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_controller_ttb_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _FailingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('ttb_sentence_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('ttb_sentence_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );
    final controller = WorkplaceSentenceSessionController(repository: repository);

    await controller.loadInitial();
    final before = controller.currentSentence?.localId;

    await controller.onSwipeTopToBottom();

    final totals = await database.getLearningProgressTotals();
    expect(controller.currentSentence?.localId, isNot(before));
    expect(totals.difficult, 1);
  });
}

class _StubSentenceSeedLoader extends WorkplaceSentenceSeedLoader {
  _StubSentenceSeedLoader(this._sentencesByLanguage) : super();

  final Map<String, List<WorkplaceSentence>> _sentencesByLanguage;

  @override
  Future<List<WorkplaceSentence>> loadForLanguage(String language) async {
    return _sentencesByLanguage[language] ?? const [];
  }
}

class _FailingSentenceApiClient extends BackendApiClient {
  _FailingSentenceApiClient()
      : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  @override
  Future<List<WorkplaceSentence>> fetchWorkplaceSentences({
    int limit = 20,
    String targetLanguage = 'en',
    String? sessionToken,
  }) {
    throw BackendApiException('forced workplace sentence failure');
  }
}

WorkplaceSentence _sentence(
  String id, {
  required DateTime createdAt,
}) {
  return WorkplaceSentence(
    localId: id,
    serverSentenceId: id,
    text: 'Sentence for $id.',
    language: 'en',
    meaningVi: 'Nghia cua $id.',
    topic: 'work',
    sourceTitle: 'Starter pack',
    generationSource: 'bundled_workplace_sentences',
    isBundled: true,
    status: WorkplaceSentenceStatus.unseen,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

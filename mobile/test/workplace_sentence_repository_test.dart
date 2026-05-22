import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_repository.dart';
import 'package:expat8_language_app/src/data/workplace_sentence_seed_loader.dart';
import 'package:expat8_language_app/src/models/workplace_sentence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seedFromBundleIfEmpty inserts starter sentences only once', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_repository_seed_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _RecordingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('seed_sentence_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('seed_sentence_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );

    final firstLoad = await repository.seedFromBundleIfEmpty(languages: ['en']);
    final secondLoad = await repository.seedFromBundleIfEmpty(languages: ['en']);

    expect(firstLoad, 2);
    expect(secondLoad, 0);
    expect(await database.countWorkplaceSentences(language: 'en'), 2);
  });

  test('refillWorkplaceSentences stores fetched sentences locally', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_repository_refill_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final apiClient = _RecordingSentenceApiClient(
      sentenceItems: [
        _sentence('remote_sentence_1'),
        _sentence('remote_sentence_2'),
      ],
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: apiClient,
    );

    final loaded = await repository.refillWorkplaceSentences(
      deviceId: 'device_sentence_repo',
      limit: 2,
      language: 'en',
    );

    expect(loaded, hasLength(2));
    expect(await database.countWorkplaceSentences(language: 'en'), 2);
    expect(apiClient.lastLimit, 2);
    expect(apiClient.lastTargetLanguage, 'en');
  });

  test('nextSentence prefers unseen items then randomizes learned items', () async {
    final database = await LocalDatabase.open(
      databaseName:
          'workplace_sentence_repository_rotation_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final repository = WorkplaceSentenceRepository(
      database: database,
      apiClient: _RecordingSentenceApiClient(),
      seedLoader: _StubSentenceSeedLoader({
        'en': [
          _sentence('sentence_1', createdAt: DateTime.utc(2026, 5, 16, 0)),
          _sentence('sentence_2', createdAt: DateTime.utc(2026, 5, 16, 1)),
        ],
      }),
    );

    await repository.seedFromBundleIfEmpty(languages: ['en']);

    final first = await repository.nextSentence(language: 'en');
    expect(first, isNotNull);
    expect(first?.status, WorkplaceSentenceStatus.unseen);

    await repository.markSentenceSeen(
      sentence: first!,
      now: DateTime.utc(2026, 5, 16, 2),
    );

    final second = await repository.nextSentence(language: 'en');
    expect(second, isNotNull);
    expect(second?.status, WorkplaceSentenceStatus.unseen);

    await repository.markSentenceSeen(
      sentence: second!,
      now: DateTime.utc(2026, 5, 16, 3),
    );

    final fallback = await repository.nextSentence(language: 'en');
    expect(fallback, isNotNull);
    expect(
      fallback!.localId,
      anyOf('sentence_1', 'sentence_2'),
    );
    expect(fallback.status, WorkplaceSentenceStatus.seen);
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

class _RecordingSentenceApiClient extends BackendApiClient {
  _RecordingSentenceApiClient({this.sentenceItems = const []})
      : super(
          baseUrl: 'http://unused',
          timeout: Duration.zero,
          appId: 'test-app',
          appSecret: 'test-secret',
        );

  final List<WorkplaceSentence> sentenceItems;
  int? lastLimit;
  String? lastTargetLanguage;

  @override
  Future<List<WorkplaceSentence>> fetchWorkplaceSentences({
    int limit = 20,
    String targetLanguage = 'en',
    String? sessionToken,
  }) async {
    lastLimit = limit;
    lastTargetLanguage = targetLanguage;
    return sentenceItems.take(limit).toList(growable: false);
  }
}

WorkplaceSentence _sentence(
  String id, {
  DateTime? createdAt,
}) {
  final ts = createdAt ?? DateTime.utc(2026, 5, 16);
  return WorkplaceSentence(
    localId: id,
    serverSentenceId: id,
    text: 'Sentence for $id.',
    language: 'en',
    meaningVi: 'Nghia cua $id.',
    topic: 'work',
    sourceTitle: 'Starter pack',
    generationSource: 'bundled_workplace_sentences',
    isBundled: false,
    status: WorkplaceSentenceStatus.unseen,
    createdAt: ts,
    updatedAt: ts,
  );
}

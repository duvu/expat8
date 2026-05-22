import 'dart:math';

import 'package:uuid/uuid.dart';

import '../api/backend_api_client.dart';
import '../logging/logger.dart';
import '../models/learning_progress.dart';
import '../models/user_session.dart';
import '../models/workplace_sentence.dart';
import 'local_database.dart';
import 'workplace_sentence_seed_loader.dart';

class WorkplaceSentenceRepository {
  WorkplaceSentenceRepository({
    required this.database,
    required this.apiClient,
    Logger? logger,
    Uuid? uuid,
    WorkplaceSentenceSeedLoader? seedLoader,
  })  : _logger = logger ?? const NoopLogger(),
        _uuid = uuid ?? const Uuid(),
        _seedLoader = seedLoader ?? const WorkplaceSentenceSeedLoader();

  final LocalDatabase database;
  final BackendApiClient apiClient;
  final Logger _logger;
  final Uuid _uuid;
  final WorkplaceSentenceSeedLoader _seedLoader;

  static const int _refillThreshold = 40;
  static const int _refillBatchSize = 20;

  String? _refillDeviceId;
  String _activeLanguage = 'en';
  final Random _random = Random.secure();

  Future<String> getOrCreateDeviceId() {
    return database.getOrCreateDeviceId(_uuid.v4);
  }

  void initRefreshWorker(String deviceId) {
    _refillDeviceId = deviceId;
  }

  void setActiveLanguage(String language) {
    _activeLanguage = language;
  }

  Future<UserSession?> loadUserSession() {
    return database.loadUserSession();
  }

  Future<int> seedFromBundleIfEmpty({required List<String> languages}) async {
    var totalLoaded = 0;
    for (final language in languages) {
      final existing = await database.countWorkplaceSentences(language: language);
      if (existing > 0) continue;
      final seed = await _seedLoader.loadForLanguage(language);
      if (seed.isEmpty) continue;
      final normalized = seed
          .map((sentence) => sentence.copyWith(isBundled: true))
          .toList(growable: false);
      totalLoaded += await database.addWorkplaceSentenceBatch(normalized);
      await _logger.info(
        category: AppLogCategory.app,
        event: 'seed_workplace_sentences.bundle_loaded',
        message: 'Seeded local workplace sentence cache from app bundle.',
        context: {
          'language': language,
          'loaded_count': normalized.length,
        },
      );
    }
    return totalLoaded;
  }

  Future<WorkplaceSentence?> nextSentence({String language = 'en'}) async {
    final unseen = await database.nextUnseenWorkplaceSentence(
      language: language,
      random: _random,
    );
    if (unseen != null) {
      return unseen;
    }
    return database.randomWorkplaceSentence(language: language, random: _random);
  }

  Future<void> markSentenceSeen({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) {
    return database.markWorkplaceSentenceSeen(sentence: sentence, now: now);
  }

  Future<void> markSentenceLearned({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) {
    return database.markSentenceLearned(sentence: sentence, now: now);
  }

  Future<void> markSentenceRemembered({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) {
    return database.markSentenceRemembered(sentence: sentence, now: now);
  }

  Future<void> markSentenceDifficult({
    required WorkplaceSentence sentence,
    required DateTime now,
  }) {
    return database.markSentenceDifficult(sentence: sentence, now: now);
  }

  Future<List<LearningHistoryEntry>> loadLearningHistory({int limit = -1}) {
    return database.getLearningHistory(limit: limit);
  }

  Future<LearningProgressTotals> loadLearningProgressTotals() {
    return database.getLearningProgressTotals();
  }

  Future<int> topUpInventoryIfNeeded() async {
    final language = _activeLanguage;
    final unseen = await database.countUnseenWorkplaceSentences(language: language);
    if (unseen >= _refillThreshold) {
      return 0;
    }
    return _safeRefill(limit: _refillBatchSize, language: language);
  }

  Future<int> _safeRefill({
    required int limit,
    required String language,
  }) async {
    try {
      final deviceId = _refillDeviceId ?? await getOrCreateDeviceId();
      final loaded = await refillWorkplaceSentences(
        deviceId: deviceId,
        limit: limit,
        language: language,
      );
      return loaded.length;
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'workplace_sentences.refill.failed',
        message: 'Workplace sentence inventory refill failed.',
        context: {
          'limit': limit,
          'language': language,
          'error': '$error',
        },
      );
      return 0;
    }
  }

  Future<List<WorkplaceSentence>> refillWorkplaceSentences({
    required String deviceId,
    int limit = _refillBatchSize,
    String language = 'en',
  }) async {
    if (limit <= 0) return const [];
    final session = await database.loadUserSession();
    final items = await apiClient.fetchWorkplaceSentences(
      limit: limit,
      targetLanguage: language,
      sessionToken: session?.sessionToken,
    );
    final inserted = await database.addWorkplaceSentenceBatch(items);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'workplace_sentences.refill',
      message: 'Refilled local workplace sentence cache from backend.',
      context: {
        'device_id': deviceId,
        'requested_limit': limit,
        'fetched_count': items.length,
        'inserted_count': inserted,
      },
    );
    return items;
  }
}

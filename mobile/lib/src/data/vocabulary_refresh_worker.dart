import '../api/backend_api_client.dart';
import '../config.dart';
import '../logging/logger.dart';
import '../models/vocabulary_word.dart';
import 'local_database.dart';

class VocabularyRefreshWorker {
  VocabularyRefreshWorker({
    required this.database,
    required this.apiClient,
    required this.deviceId,
    AppConfig? config,
    Logger? logger,
  })  : _config = config ?? AppConfig.fromEnvironment(),
        _logger = logger ?? const NoopLogger();

  final LocalDatabase database;
  final BackendApiClient apiClient;
  final String deviceId;
  final AppConfig _config;
  final Logger _logger;

  /// First-install prefetch: fetch up to [prefetchLimit] words and store them.
  Future<void> runPrefetch() async {
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'vocab_refresh.prefetch.start',
      message: 'Starting first-install vocabulary prefetch.',
      context: {'limit': _config.vocabPrefetchLimit},
    );
    try {
      final words = await _fetchAndStoreLearningCards(
        _config.vocabPrefetchLimit,
      );
      await database.setSetting(LocalDatabase.keyIsPrefetchDone, 'true');
      await _logger.info(
        category: AppLogCategory.sync,
        event: 'vocab_refresh.prefetch.complete',
        message: 'First-install vocabulary prefetch completed.',
        context: {'words_fetched': words.length},
      );
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'vocab_refresh.prefetch.error',
        message: 'First-install prefetch failed; will retry next session.',
        context: {'error': '$error'},
      );
      // Do not mark prefetch as done so it retries next session.
    }
  }

  /// Daily refresh: ask the backend for selected new cards and sync the
  /// resulting local cache inventory.
  Future<void> runDailyRefresh() async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'vocab_refresh.daily.start',
      message: 'Starting daily vocabulary refresh.',
      context: {'date': today, 'count': _config.vocabDailyRefreshCount},
    );
    try {
      final words = await _fetchAndStoreLearningCards(
        _config.vocabDailyRefreshCount,
      );
      await database.setSetting(LocalDatabase.keyLastDailyRefreshDate, today);
      await _logger.info(
        category: AppLogCategory.sync,
        event: 'vocab_refresh.daily.complete',
        message: 'Daily vocabulary refresh completed.',
        context: {'words_fetched': words.length},
      );
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'vocab_refresh.daily.error',
        message: 'Daily refresh failed; will retry next session.',
        context: {'error': '$error'},
      );
      // Do not update last refresh date so it retries next session.
    }
  }

  /// Proactive refresh: fetch [needed] words to top up the unstudied cache.
  Future<void> runProactiveRefresh(int needed) async {
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'vocab_refresh.proactive.start',
      message: 'Starting proactive vocabulary refresh.',
      context: {'needed': needed},
    );
    try {
      final words = await _fetchAndStoreLearningCards(needed);
      await _logger.info(
        category: AppLogCategory.sync,
        event: 'vocab_refresh.proactive.complete',
        message: 'Proactive vocabulary refresh completed.',
        context: {'words_fetched': words.length},
      );
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'vocab_refresh.proactive.error',
        message: 'Proactive refresh failed.',
        context: {'error': '$error'},
      );
    }
  }

  Future<List<VocabularyWord>> _fetchAndStoreLearningCards(int limit) async {
    final batch = await apiClient.fetchLearningCards(
      deviceId: deviceId,
      limit: limit.clamp(1, 100).toInt(),
    );
    await database.addBatch(batch.items);
    final serverWordIds = await database.activeCachedServerWordIds();
    await apiClient.syncCacheInventory(
      deviceId: deviceId,
      serverWordIds: serverWordIds,
    );
    return batch.items;
  }
}

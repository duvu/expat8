import '../api/backend_api_client.dart';
import '../config.dart';
import '../logging/logger.dart';
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
      final words = await apiClient.fetchRecentWords(
        limit: _config.vocabPrefetchLimit,
        deviceId: deviceId,
      );
      for (final word in words) {
        await database.upsertWord(word);
      }
      await database.pruneToMostRecent();
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

  /// Daily refresh: replace ~[dailyRefreshCount] words by fetching new ones
  /// that differ from already-cached server word IDs.
  Future<void> runDailyRefresh() async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'vocab_refresh.daily.start',
      message: 'Starting daily vocabulary refresh.',
      context: {'date': today, 'count': _config.vocabDailyRefreshCount},
    );
    try {
      final excludeIds = await database.recentServerWordIds(limit: 1000);
      final words = await apiClient.fetchRecentWords(
        limit: _config.vocabDailyRefreshCount,
        deviceId: deviceId,
        excludeIds: excludeIds,
      );
      for (final word in words) {
        await database.upsertWord(word);
      }
      await database.pruneToMostRecent();
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
      final excludeIds = await database.recentServerWordIds(limit: 1000);
      final words = await apiClient.fetchRecentWords(
        limit: needed,
        deviceId: deviceId,
        excludeIds: excludeIds,
      );
      for (final word in words) {
        await database.upsertWord(word);
      }
      await database.pruneToMostRecent();
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
}

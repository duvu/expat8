import '../logging/logger.dart';
import 'word_repository.dart';

class SyncWorker {
  SyncWorker({
    required this.repository,
    required this.deviceId,
    Logger? logger,
  }) : _logger = logger ?? const NoopLogger();

  final WordRepository repository;
  final String deviceId;
  final Logger _logger;

  Future<void> runOnce() async {
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'sync_worker.run_once.start',
      message: 'Starting one sync worker pass.',
    );
    await repository.syncPendingEvents(deviceId: deviceId);
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'sync_worker.run_once.complete',
      message: 'Completed one sync worker pass.',
    );
  }
}

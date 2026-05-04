import 'word_repository.dart';

class SyncWorker {
  SyncWorker({
    required this.repository,
    required this.deviceId,
  });

  final WordRepository repository;
  final String deviceId;

  Future<void> runOnce() {
    return repository.syncPendingEvents(deviceId: deviceId);
  }
}

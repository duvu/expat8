class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.type,
    required this.payload,
    required this.retryCount,
    required this.nextRetryAt,
    required this.createdAt,
  });

  final int? id;
  final String type;
  final String payload;
  final int retryCount;
  final DateTime nextRetryAt;
  final DateTime createdAt;
}

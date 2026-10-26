part of 'local_database.dart';

/// Persisted app logs (buffered writes, retention).
extension LocalDatabaseLogs on LocalDatabase {
  Future<void> persistLogEntry(LogEntry entry) async {
    _pendingLogs.add(
      AppLogEntity(
        timestampMs: entry.timestamp.toUtc().millisecondsSinceEpoch,
        level: entry.level.name,
        category: entry.category.name,
        event: entry.event,
        message: entry.message,
        traceId: entry.traceId,
        contextJson: jsonEncode(entry.context),
      ),
    );
    if (_pendingLogs.length >= LocalDatabase._logFlushBatch) {
      unawaited(flushLogs());
    } else {
      _logFlushTimer ??=
          Timer(LocalDatabase._logFlushDelay, () => unawaited(flushLogs()));
    }
  }

  /// Writes buffered log rows (call before reading logs or closing).
  Future<void> flushLogs() async {
    _logFlushTimer?.cancel();
    _logFlushTimer = null;
    final running = _logFlush;
    if (running != null) await running;
    if (_pendingLogs.isEmpty) return;
    final batch = List<AppLogEntity>.of(_pendingLogs);
    _pendingLogs.clear();
    final write = _logs.putManyAsync(batch).then((_) {});
    _logFlush = write;
    try {
      await write;
    } finally {
      if (identical(_logFlush, write)) _logFlush = null;
    }
  }

  Future<List<LogEntry>> queryLogs({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 200,
    int offset = 0,
  }) async {
    await flushLogs();
    final all = _logs.getAll();
    var filtered = all.where((entity) {
      if (minimumLevel != null &&
          AppLogLevel.fromName(entity.level).priority < minimumLevel.priority) {
        return false;
      }
      if (category != null && entity.category != category.name) {
        return false;
      }
      if (from != null &&
          entity.timestampMs < from.toUtc().millisecondsSinceEpoch) {
        return false;
      }
      if (to != null &&
          entity.timestampMs > to.toUtc().millisecondsSinceEpoch) {
        return false;
      }
      return true;
    }).toList(growable: false)
      ..sort((a, b) {
        final timeCompare = b.timestampMs.compareTo(a.timestampMs);
        if (timeCompare != 0) {
          return timeCompare;
        }
        return b.id.compareTo(a.id);
      });

    if (offset > 0) {
      filtered = filtered.skip(offset).toList(growable: false);
    }
    if (limit >= 0) {
      filtered = filtered.take(limit).toList(growable: false);
    }

    return filtered.map(_logFromEntity).toList(growable: false);
  }

  /// Enforces log retention. Runs periodically on the UI isolate, so it must
  /// stay cheap: native queries and bulk removes in single transactions, never
  /// loading every log row into Dart (that froze games every 5 minutes).
  Future<int> pruneLogs({
    int maxEntries = 5000,
    Duration maxAge = const Duration(days: 7),
    DateTime? now,
  }) async {
    await flushLogs();
    final cutoff =
        (now ?? DateTime.now().toUtc()).subtract(maxAge).millisecondsSinceEpoch;
    return _store.runAsync(_pruneLogsWorker, (cutoff, maxEntries));
  }

  static int _pruneLogsWorker(Store store, (int, int) args) {
    final (cutoff, maxEntries) = args;
    final logs = store.box<AppLogEntity>();
    final expired =
        logs.query(AppLogEntity_.timestampMs.lessThan(cutoff)).build();
    var removed = expired.remove();
    expired.close();

    final overflow = logs.count() - maxEntries;
    if (overflow > 0) {
      final oldest = (logs.query()
            ..order(AppLogEntity_.timestampMs)
            ..order(AppLogEntity_.id))
          .build()
        ..limit = overflow;
      removed += logs.removeMany(oldest.findIds());
      oldest.close();
    }
    return removed;
  }

  LogEntry _logFromEntity(AppLogEntity row) {
    return LogEntry(
      id: row.id,
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(row.timestampMs, isUtc: true),
      level: AppLogLevel.fromName(row.level),
      category: AppLogCategory.values.byName(row.category),
      event: row.event,
      message: row.message,
      traceId: row.traceId,
      context: Map<String, Object?>.from(
        jsonDecode(row.contextJson) as Map<String, dynamic>,
      ),
    );
  }
}

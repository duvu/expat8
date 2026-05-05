import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and deserializes log entry', () {
    final entry = LogEntry(
      id: 12,
      timestamp: DateTime.utc(2026, 5, 5, 10, 0, 0),
      level: AppLogLevel.warning,
      category: AppLogCategory.api,
      event: 'api.timeout',
      message: 'Timeout while requesting next word',
      traceId: 'trace_1',
      context: const {'status_code': 504, 'endpoint': '/v1/words/next'},
    );

    final restored = LogEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.level, entry.level);
    expect(restored.category, entry.category);
    expect(restored.event, entry.event);
    expect(restored.traceId, entry.traceId);
    expect(restored.context['status_code'], 504);
  });

  test('persisted logger filters entries below minimum level', () async {
    final captured = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.warning,
      write: (entry) async => captured.add(entry),
    );

    await logger.info(
      category: AppLogCategory.app,
      event: 'app.start',
      message: 'App started',
    );
    await logger.error(
      category: AppLogCategory.app,
      event: 'app.crash',
      message: 'Unhandled error',
    );

    expect(captured.length, 1);
    expect(captured.first.level, AppLogLevel.error);
  });

  test('sanitizer redacts sensitive context and message values', () {
    final sanitizer = LogSanitizer();
    final entry = LogEntry(
      timestamp: DateTime.utc(2026, 5, 5),
      level: AppLogLevel.error,
      category: AppLogCategory.auth,
      event: 'auth.failed',
      message: 'authorization=Bearer abcdef password=secret123',
      traceId: 'trace_sensitive',
      context: const {
        'authorization': 'Bearer abcdef',
        'password': 'secret123',
        'safe': 'ok',
      },
    );

    final sanitized = sanitizer.sanitize(entry);

    expect(sanitized.message.contains('abcdef'), false);
    expect(sanitized.context['authorization'], LogSanitizer.redacted);
    expect(sanitized.context['password'], LogSanitizer.redacted);
    expect(sanitized.context['safe'], 'ok');
  });

  test('logger preserves trace id for correlation', () async {
    final captured = <LogEntry>[];
    final logger = PersistedLogger(
      minimumLevel: AppLogLevel.debug,
      write: (entry) async => captured.add(entry),
    );

    await logger.debug(
      category: AppLogCategory.sync,
      event: 'sync.retry',
      message: 'Retrying sync',
      traceId: 'trace_sync_123',
    );

    expect(captured.single.traceId, 'trace_sync_123');
  });
}

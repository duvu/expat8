import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/logging/logger.dart';
import 'package:expat8_language_app/src/ui/log_share_service.dart';
import 'package:expat8_language_app/src/ui/logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export shows no-log feedback without opening share sheet',
      (tester) async {
    final repository = await _repositoryWithLogs(const []);
    final shareService = _RecordingLogShareService();

    await tester.pumpWidget(
      MaterialApp(
        home: LogsScreen(
          repository: repository,
          shareService: shareService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export logs'));
    await _pumpUntil(
      tester,
      () => find
          .text('No logs to export for selected filters.')
          .evaluate()
          .isNotEmpty,
    );

    expect(shareService.exports, isEmpty);
    expect(
        find.text('No logs to export for selected filters.'), findsOneWidget);
  });

  testWidgets('export shares generated file for matching logs', (tester) async {
    final repository = await _repositoryWithLogs([
      _log(
        level: AppLogLevel.warning,
        event: 'api.warning',
        message: 'Request warning',
      ),
    ]);
    expect(await repository.loadLogs(minimumLevel: AppLogLevel.warning),
        hasLength(1));
    final shareService = _RecordingLogShareService(
      outcome: const LogShareOutcome(LogShareStatus.success),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LogsScreen(
          repository: repository,
          shareService: shareService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request warning'), findsOneWidget);

    await tester.tap(find.byTooltip('Export logs'));
    await _pumpUntil(tester, () => shareService.exports.isNotEmpty);
    await _pumpUntil(
      tester,
      () => find.text('Shared 1 logs.').evaluate().isNotEmpty,
    );

    expect(shareService.exports.length, 1);
    expect(shareService.exports.single.path, isNotNull);
    expect(shareService.exports.single.fileName, endsWith('.txt'));
    expect(find.text('Shared 1 logs.'), findsOneWidget);
  });

  testWidgets('export reports unavailable share action without deleting logs',
      (tester) async {
    final repository = await _repositoryWithLogs([
      _log(
        level: AppLogLevel.error,
        event: 'api.error',
        message: 'Request failed',
      ),
    ]);
    expect(await repository.loadLogs(minimumLevel: AppLogLevel.error),
        hasLength(1));
    final shareService = _RecordingLogShareService(
      outcome: const LogShareOutcome(LogShareStatus.unavailable),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LogsScreen(
          repository: repository,
          shareService: shareService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request failed'), findsOneWidget);

    await tester.tap(find.byTooltip('Export logs'));
    await _pumpUntil(tester, () => shareService.exports.isNotEmpty);
    await _pumpUntil(
      tester,
      () => find
          .text('Log sharing is unavailable on this device.')
          .evaluate()
          .isNotEmpty,
    );

    expect(shareService.exports.length, 1);
    expect(find.text('Log sharing is unavailable on this device.'),
        findsOneWidget);
    final persisted =
        await repository.loadLogs(minimumLevel: AppLogLevel.error);
    expect(persisted.length, 1);
  });

  testWidgets('send shows success feedback and keeps export intact',
      (tester) async {
    final repository = await _repositoryWithLogs([
      _log(
        level: AppLogLevel.warning,
        event: 'api.warning',
        message: 'Request warning',
      ),
    ]);
    final shareService = _RecordingLogShareService();

    await tester.pumpWidget(
      MaterialApp(
        home: LogsScreen(
          repository: repository,
          shareService: shareService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Send logs to server'));
    await _pumpUntil(
      tester,
      () => find.text('Sent 1 logs to the server.').evaluate().isNotEmpty,
    );

    expect(find.text('Sent 1 logs to the server.'), findsOneWidget);
    expect(shareService.exports, isEmpty);
  });

  testWidgets('send reports failures without deleting logs', (tester) async {
    final repository = await _repositoryWithLogs([
      _log(
        level: AppLogLevel.error,
        event: 'api.error',
        message: 'Request failed',
      ),
    ]);
    final failingRepository = repository as _FakeLogRepository;
    failingRepository.sendError = Exception('upload failed');
    final shareService = _RecordingLogShareService();

    await tester.pumpWidget(
      MaterialApp(
        home: LogsScreen(
          repository: failingRepository,
          shareService: shareService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Send logs to server'));
    await _pumpUntil(
      tester,
      () => find
          .textContaining('Failed to send logs to server:')
          .evaluate()
          .isNotEmpty,
    );

    expect(
      find.textContaining('Failed to send logs to server:'),
      findsOneWidget,
    );
    expect(shareService.exports, isEmpty);
    final persisted =
        await failingRepository.loadLogs(minimumLevel: AppLogLevel.error);
    expect(persisted.length, 1);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 40; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) {
      return;
    }
  }
  fail('Condition was not met before timeout.');
}

Future<WordRepository> _repositoryWithLogs(List<LogEntry> logs) async {
  final database = await LocalDatabase.open(
    databaseName:
        'logs_screen_test_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return _FakeLogRepository(database: database, logs: logs);
}

class _FakeLogRepository extends WordRepository {
  _FakeLogRepository({
    required super.database,
    required this.logs,
  }) : super(
          apiClient: BackendApiClient(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'test-app',
            appSecret: 'test-secret',
          ),
          logger: const NoopLogger(),
        );

  final List<LogEntry> logs;
  Object? sendError;
  final List<LogExportResult> sentExports = [];

  @override
  Future<List<LogEntry>> loadLogs({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 200,
    int offset = 0,
  }) async {
    var filtered = logs.where((entry) {
      if (minimumLevel != null &&
          entry.level.priority < minimumLevel.priority) {
        return false;
      }
      if (category != null && entry.category != category) {
        return false;
      }
      return true;
    }).toList(growable: false);
    if (offset > 0) {
      filtered = filtered.skip(offset).toList(growable: false);
    }
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<LogExportResult> exportLogs({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 2000,
  }) async {
    final entries = await loadLogs(
      minimumLevel: minimumLevel,
      category: category,
      from: from,
      to: to,
      limit: limit,
    );
    return LogExportResult(
      path: entries.isEmpty ? null : '/tmp/expat8_logs_test.txt',
      payload: entries.map((entry) => entry.toJsonLine()).join('\n'),
      count: entries.length,
      fileName: 'expat8_logs_test.txt',
    );
  }

  @override
  Future<LogExportResult> sendLogsToServer({
    AppLogLevel? minimumLevel,
    AppLogCategory? category,
    DateTime? from,
    DateTime? to,
    int limit = 2000,
  }) async {
    final export = await exportLogs(
      minimumLevel: minimumLevel,
      category: category,
      from: from,
      to: to,
      limit: limit,
    );
    if (sendError != null) {
      throw sendError!;
    }
    sentExports.add(export);
    return export;
  }
}

LogEntry _log({
  required AppLogLevel level,
  required String event,
  required String message,
}) {
  return LogEntry(
    timestamp: DateTime.utc(2026, 5, 7, 12),
    level: level,
    category: AppLogCategory.api,
    event: event,
    message: message,
    context: const {},
  );
}

class _RecordingLogShareService implements LogShareService {
  _RecordingLogShareService({
    this.outcome = const LogShareOutcome(LogShareStatus.success),
  });

  final LogShareOutcome outcome;
  final List<LogExportResult> exports = [];

  @override
  Future<LogShareOutcome> share(
    LogExportResult export, {
    Rect? sharePositionOrigin,
  }) async {
    exports.add(export);
    return outcome;
  }
}

import 'dart:convert';

enum AppLogLevel {
  debug(10),
  info(20),
  warning(30),
  error(40);

  const AppLogLevel(this.priority);

  final int priority;

  static AppLogLevel fromName(String value) {
    return AppLogLevel.values.firstWhere(
      (level) => level.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AppLogLevel.info,
    );
  }
}

enum AppLogCategory {
  app,
  api,
  sync,
  database,
  session,
  auth,
  ui,
}

class LogEntry {
  const LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.event,
    required this.message,
    required this.context,
    this.traceId,
  });

  final int? id;
  final DateTime timestamp;
  final AppLogLevel level;
  final AppLogCategory category;
  final String event;
  final String message;
  final Map<String, Object?> context;
  final String? traceId;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.name,
      'category': category.name,
      'event': event,
      'message': message,
      'context': context,
      'trace_id': traceId,
    };
  }

  String toJsonLine() => jsonEncode(toJson());

  factory LogEntry.fromJson(Map<String, Object?> json) {
    return LogEntry(
      id: json['id'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      level: AppLogLevel.fromName(json['level'] as String),
      category: AppLogCategory.values.byName(json['category'] as String),
      event: json['event'] as String,
      message: json['message'] as String,
      context: Map<String, Object?>.from(
        json['context'] as Map<String, dynamic>? ?? const {},
      ),
      traceId: json['trace_id'] as String?,
    );
  }

  LogEntry copyWith({
    int? id,
    DateTime? timestamp,
    AppLogLevel? level,
    AppLogCategory? category,
    String? event,
    String? message,
    Map<String, Object?>? context,
    String? traceId,
  }) {
    return LogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      category: category ?? this.category,
      event: event ?? this.event,
      message: message ?? this.message,
      context: context ?? this.context,
      traceId: traceId ?? this.traceId,
    );
  }
}

class LogSanitizer {
  LogSanitizer({
    Set<String>? sensitiveKeys,
  }) : _sensitiveKeys = sensitiveKeys ??
            const {
              'authorization',
              'token',
              'sessiontoken',
              'session_token',
              'password',
              'appsecret',
              'app_secret',
              'secret',
              'x-expat8-signature',
            };

  final Set<String> _sensitiveKeys;

  static const String redacted = '[REDACTED]';

  LogEntry sanitize(LogEntry entry) {
    return entry.copyWith(
      message: _sanitizeMessage(entry.message),
      context: sanitizeMap(entry.context),
    );
  }

  Map<String, Object?> sanitizeMap(Map<String, Object?> input) {
    final output = <String, Object?>{};
    for (final pair in input.entries) {
      final key = pair.key;
      final normalizedKey = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (_sensitiveKeys.contains(normalizedKey)) {
        output[key] = redacted;
      } else {
        output[key] = _sanitizeValue(pair.value);
      }
    }
    return output;
  }

  Object? _sanitizeValue(Object? value) {
    if (value is Map<String, Object?>) {
      return sanitizeMap(value);
    }
    if (value is Map) {
      return sanitizeMap(value.map((k, v) => MapEntry('$k', v)));
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    if (value is String) {
      return _sanitizeMessage(value);
    }
    return value;
  }

  String _sanitizeMessage(String message) {
    var sanitized = message;
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer $redacted',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'(password\s*[:=]\s*)([^\s,;]+)', caseSensitive: false),
      'password=$redacted',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'(token\s*[:=]\s*)([^\s,;]+)', caseSensitive: false),
      'token=$redacted',
    );
    return sanitized;
  }
}

abstract class Logger {
  const Logger();

  Future<void> log({
    required AppLogLevel level,
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  });

  Future<void> debug({
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    return log(
      level: AppLogLevel.debug,
      category: category,
      event: event,
      message: message,
      traceId: traceId,
      context: context,
    );
  }

  Future<void> info({
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    return log(
      level: AppLogLevel.info,
      category: category,
      event: event,
      message: message,
      traceId: traceId,
      context: context,
    );
  }

  Future<void> warning({
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    return log(
      level: AppLogLevel.warning,
      category: category,
      event: event,
      message: message,
      traceId: traceId,
      context: context,
    );
  }

  Future<void> error({
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  }) {
    return log(
      level: AppLogLevel.error,
      category: category,
      event: event,
      message: message,
      traceId: traceId,
      context: context,
    );
  }
}

typedef LogWriteCallback = Future<void> Function(LogEntry entry);

class PersistedLogger extends Logger {
  PersistedLogger({
    required this.minimumLevel,
    required this.write,
    LogSanitizer? sanitizer,
  }) : _sanitizer = sanitizer ?? LogSanitizer();

  final AppLogLevel minimumLevel;
  final LogWriteCallback write;
  final LogSanitizer _sanitizer;

  @override
  Future<void> log({
    required AppLogLevel level,
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  }) async {
    if (level.priority < minimumLevel.priority) {
      return;
    }
    final entry = _sanitizer.sanitize(
      LogEntry(
        timestamp: DateTime.now().toUtc(),
        level: level,
        category: category,
        event: event,
        message: message,
        context: context,
        traceId: traceId,
      ),
    );
    await write(entry);
  }
}

class NoopLogger extends Logger {
  const NoopLogger();

  @override
  Future<void> log({
    required AppLogLevel level,
    required AppLogCategory category,
    required String event,
    required String message,
    String? traceId,
    Map<String, Object?> context = const {},
  }) async {}
}

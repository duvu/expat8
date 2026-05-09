import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../logging/logger.dart';
import '../models/proficiency_state.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';

class BackendApiClient {
  BackendApiClient({
    required this.baseUrl,
    required this.timeout,
    required this.appId,
    required this.appSecret,
    http.Client? httpClient,
    Logger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _logger = logger ?? const NoopLogger();

  final String baseUrl;
  final Duration timeout;
  final String appId;
  final String appSecret;
  final http.Client _httpClient;
  final Logger _logger;

  Future<ProficiencyState> fetchProficiency({
    required String deviceId,
    String language = 'en',
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/proficiency').replace(queryParameters: {
      'device_id': deviceId,
      'language': language,
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'proficiency.request',
      message: 'Requesting proficiency state.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
      },
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: _signedHeaders(
              method: 'GET',
              uri: uri,
              sessionToken: sessionToken,
            ),
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'proficiency.timeout',
        message: 'Proficiency request timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'proficiency.response',
      message: 'Received proficiency response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Proficiency fetch failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ProficiencyState.fromJson(body);
  }

  Future<StudyEventResult> submitStudyEvent({
    required String deviceId,
    required Map<String, dynamic> event,
    String language = 'en',
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/study-events');
    final payload = jsonEncode({
      'device_id': deviceId,
      'language': language,
      ...event,
    });
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            ..._signedHeaders(
              method: 'POST',
              uri: uri,
              body: Uint8List.fromList(utf8.encode(payload)),
              sessionToken: sessionToken,
            ),
          },
          body: payload,
        )
        .timeout(timeout);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'study_event.response',
      message: 'Received study-event response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
      },
    );
    _throwIfFailed(response, 'Study-event submit failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyEventResult(
      success: (body['success'] ?? false) as bool,
      eventId: body['event_id'] as String?,
      idempotent: (body['idempotent'] ?? false) as bool,
      proficiency: ProficiencyState.fromJson(
        body['proficiency'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Future<LearningCardBatch> fetchLearningCards({
    required String deviceId,
    int limit = 10,
    String targetLanguage = 'en',
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/learning/cards');
    final payload = jsonEncode({
      'device_id': deviceId,
      'limit': limit,
      'target_language': targetLanguage,
      'card_mode': 'new',
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'learning_cards.request',
      message: 'Requesting learning cards from backend.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'limit': limit,
        'target_language': targetLanguage,
        'timeout_ms': timeout.inMilliseconds,
      },
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              ..._signedHeaders(
                method: 'POST',
                uri: uri,
                body: Uint8List.fromList(utf8.encode(payload)),
                sessionToken: sessionToken,
              ),
            },
            body: payload,
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'learning_cards.timeout',
        message: 'Learning-card request timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'limit': limit,
          'target_language': targetLanguage,
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'learning_cards.response',
      message: 'Received learning-card response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Learning-card batch failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List? ?? const [];
    return LearningCardBatch(
      items: items
          .map((item) => VocabularyWord.fromJson(item as Map<String, dynamic>))
          .toList(),
      targetMix: LearningCardMix.fromJson(
        body['target_mix'] as Map<String, dynamic>? ?? const {},
      ),
      actualMix: LearningCardMix.fromJson(
        body['actual_mix'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Future<CacheInventoryResult> syncCacheInventory({
    required String deviceId,
    required List<String> serverWordIds,
    DateTime? observedAt,
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/user-word-cache');
    final payload = jsonEncode({
      'device_id': deviceId,
      'server_word_ids': serverWordIds,
      'observed_at':
          (observedAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    });
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'cache_inventory.request',
      message: 'Syncing user cache inventory to backend.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'server_word_ids_count': serverWordIds.length,
        'timeout_ms': timeout.inMilliseconds,
      },
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .put(
            uri,
            headers: {
              'content-type': 'application/json',
              ..._signedHeaders(
                method: 'PUT',
                uri: uri,
                body: Uint8List.fromList(utf8.encode(payload)),
                sessionToken: sessionToken,
              ),
            },
            body: payload,
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.sync,
        event: 'cache_inventory.timeout',
        message: 'Cache inventory sync timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'server_word_ids_count': serverWordIds.length,
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'cache_inventory.response',
      message: 'Received cache inventory response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Cache inventory sync failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return CacheInventoryResult(
      storedCount: body['stored_count'] as int? ?? 0,
      unknownServerWordIds: List<String>.from(
        body['unknown_server_word_ids'] as List? ?? const [],
      ),
    );
  }

  Future<SyncResult> syncStudyEvents({
    required String deviceId,
    required List<Map<String, dynamic>> events,
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/study-events/sync');
    final payload = jsonEncode({'device_id': deviceId, 'events': events});
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'sync.request',
      message: 'Syncing study events.',
      traceId: traceId,
      context: {
        'events_count': events.length,
      },
    );
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            ..._signedHeaders(
              method: 'POST',
              uri: uri,
              body: Uint8List.fromList(utf8.encode(payload)),
              sessionToken: sessionToken,
            ),
          },
          body: payload,
        )
        .timeout(timeout);
    await _logger.info(
      category: AppLogCategory.sync,
      event: 'sync.response',
      message: 'Received sync response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
      },
    );
    _throwIfFailed(response, 'Study-event sync failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SyncResult(
      acceptedEventIds: List<String>.from(
        body['accepted_event_ids'] as List? ?? const [],
      ),
      rejectedEvents: List<Map<String, dynamic>>.from(
        body['rejected_events'] as List? ?? const [],
      ),
      proficiency: body['proficiency'] is Map<String, dynamic>
          ? ProficiencyState.fromJson(
              body['proficiency'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<UserSession> registerUser({
    required String identifier,
    required String password,
    String? displayName,
    String? deviceId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/users/register');
    final payload = jsonEncode({
      'identifier': identifier,
      'password': password,
      if (displayName != null) 'display_name': displayName,
      if (deviceId != null) 'device_id': deviceId,
    });
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.register.request',
      message: 'Submitting registration request.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'has_display_name': displayName != null,
        'has_device_id': deviceId != null,
        'timeout_ms': timeout.inMilliseconds,
      },
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              ..._signedHeaders(
                method: 'POST',
                uri: uri,
                body: Uint8List.fromList(utf8.encode(payload)),
              ),
            },
            body: payload,
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.auth,
        event: 'auth.register.timeout',
        message: 'Registration request timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.register.response',
      message: 'Received registration response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Registration failed');
    return UserSession.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserSession> signIn({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/users/sign-in');
    final payload = jsonEncode({
      'identifier': identifier,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
    });
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.sign_in.request',
      message: 'Submitting sign-in request.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'has_device_id': deviceId != null,
        'timeout_ms': timeout.inMilliseconds,
      },
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              ..._signedHeaders(
                method: 'POST',
                uri: uri,
                body: Uint8List.fromList(utf8.encode(payload)),
              ),
            },
            body: payload,
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.auth,
        event: 'auth.sign_in.timeout',
        message: 'Sign-in request timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.sign_in.response',
      message: 'Received sign-in response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Sign-in failed');
    return UserSession.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> signOut({required UserSession session}) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/users/sign-out');
    final payload = jsonEncode({});
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.sign_out.request',
      message: 'Submitting sign-out request.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'timeout_ms': timeout.inMilliseconds,
      },
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              ..._signedHeaders(
                method: 'POST',
                uri: uri,
                body: Uint8List.fromList(utf8.encode(payload)),
                sessionToken: session.sessionToken,
              ),
            },
            body: payload,
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.auth,
        event: 'auth.sign_out.timeout',
        message: 'Sign-out request timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
    await _logger.info(
      category: AppLogCategory.auth,
      event: 'auth.sign_out.response',
      message: 'Received sign-out response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Sign-out failed');
  }

  /// Fetches the weekly speaking summary for [deviceId] (and optionally
  /// a signed-in user via [sessionToken]).
  Future<SpeakingWeeklySummary> fetchSpeakingSummary({
    required String deviceId,
    String language = 'en',
    String period = 'week',
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri =
        Uri.parse('$baseUrl/v1/speaking/summary').replace(queryParameters: {
      'device_id': deviceId,
      'language': language,
      'period': period,
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'speaking.summary.request',
      message: 'Fetching weekly speaking summary.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: _signedHeaders(
              method: 'GET',
              uri: uri,
              sessionToken: sessionToken,
            ),
          )
          .timeout(timeout);
    } on TimeoutException {
      stopwatch.stop();
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'speaking.summary.response',
      message: 'Received weekly speaking summary.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch speaking summary failed');
    return SpeakingWeeklySummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfFailed(http.Response response, String context) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    String? backendError;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      backendError = body['error'] as String?;
    } catch (_) {
      backendError = null;
    }
    throw BackendApiException(
      '$context: ${response.statusCode}',
      statusCode: response.statusCode,
      backendError: backendError,
    );
  }

  String _newTraceId() {
    return 'api_${DateTime.now().microsecondsSinceEpoch}';
  }
}

extension on BackendApiClient {
  Map<String, String> _signedHeaders({
    required String method,
    required Uri uri,
    Uint8List? body,
    String? sessionToken,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final nonce = _newNonce();
    final rawBody = body ?? Uint8List(0);
    final contentSha256 = _hashBody(rawBody);
    final canonicalRequest = _buildCanonicalRequest(
      method: method,
      uri: uri,
      timestamp: timestamp,
      nonce: nonce,
      contentSha256: contentSha256,
    );
    final signature = _signCanonicalRequest(canonicalRequest);

    return {
      'x-expat8-app-id': appId,
      'x-expat8-timestamp': timestamp,
      'x-expat8-nonce': nonce,
      'x-expat8-content-sha256': contentSha256,
      'x-expat8-signature': signature,
      if (sessionToken != null) 'authorization': 'Bearer $sessionToken',
    };
  }

  String _newNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'mobile_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  String _hashBody(Uint8List rawBody) {
    final digest = sha256.convert(rawBody);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _buildCanonicalRequest({
    required String method,
    required Uri uri,
    required String timestamp,
    required String nonce,
    required String contentSha256,
  }) {
    final sortedKeys = uri.queryParametersAll.keys.toList()..sort();
    final sortedParams = <String>[];
    for (final key in sortedKeys) {
      final values = [...(uri.queryParametersAll[key] ?? const <String>[])]
        ..sort();
      for (final value in values) {
        sortedParams.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
        );
      }
    }
    final canonicalPathWithQuery = sortedParams.isEmpty
        ? uri.path
        : '${uri.path}?${sortedParams.join('&')}';

    return [
      'v1',
      method.toUpperCase(),
      canonicalPathWithQuery,
      timestamp,
      nonce,
      contentSha256,
    ].join('\n');
  }

  String _signCanonicalRequest(String canonicalRequest) {
    final hmacDigest = Hmac(sha256, utf8.encode(appSecret)).convert(
      utf8.encode(canonicalRequest),
    );
    final signature = base64Url.encode(hmacDigest.bytes).replaceAll('=', '');
    return 'v1=$signature';
  }
}

class SyncResult {
  const SyncResult({
    required this.acceptedEventIds,
    required this.rejectedEvents,
    this.proficiency,
  });

  final List<String> acceptedEventIds;
  final List<Map<String, dynamic>> rejectedEvents;
  final ProficiencyState? proficiency;
}

class StudyEventResult {
  const StudyEventResult({
    required this.success,
    required this.eventId,
    required this.idempotent,
    required this.proficiency,
  });

  final bool success;
  final String? eventId;
  final bool idempotent;
  final ProficiencyState proficiency;
}

class LearningCardBatch {
  const LearningCardBatch({
    required this.items,
    required this.targetMix,
    required this.actualMix,
  });

  final List<VocabularyWord> items;
  final LearningCardMix targetMix;
  final LearningCardMix actualMix;
}

class LearningCardMix {
  const LearningCardMix({
    required this.newCount,
    required this.reviewCount,
  });

  factory LearningCardMix.fromJson(Map<String, dynamic> json) {
    return LearningCardMix(
      newCount: json['new'] as int? ?? 0,
      reviewCount: json['review'] as int? ?? 0,
    );
  }

  final int newCount;
  final int reviewCount;
}

class CacheInventoryResult {
  const CacheInventoryResult({
    required this.storedCount,
    required this.unknownServerWordIds,
  });

  final int storedCount;
  final List<String> unknownServerWordIds;
}

class BackendApiException implements Exception {
  BackendApiException(
    this.message, {
    this.statusCode,
    this.backendError,
  });

  final String message;
  final int? statusCode;
  final String? backendError;

  @override
  String toString() => message;
}

/// Weekly speaking summary returned by `GET /v1/speaking/summary`.
class SpeakingWeeklySummary {
  const SpeakingWeeklySummary({
    required this.spokenSentenceCount,
    required this.retryCount,
    required this.approximateDurationMs,
    required this.selfRatingCounts,
    this.latestSpeakingAt,
  });

  factory SpeakingWeeklySummary.fromJson(Map<String, dynamic> json) {
    final raw = json['self_rating_counts'] as Map<String, dynamic>? ?? {};
    return SpeakingWeeklySummary(
      spokenSentenceCount: json['spoken_sentence_count'] as int? ?? 0,
      retryCount: json['retry_count'] as int? ?? 0,
      approximateDurationMs: json['approximate_duration_ms'] as int? ?? 0,
      selfRatingCounts: raw.map((k, v) => MapEntry(k, (v as num).toInt())),
      latestSpeakingAt: json['latest_speaking_at'] == null
          ? null
          : DateTime.tryParse(json['latest_speaking_at'] as String),
    );
  }

  final int spokenSentenceCount;
  final int retryCount;
  final int approximateDurationMs;
  final Map<String, int> selfRatingCounts;
  final DateTime? latestSpeakingAt;
}

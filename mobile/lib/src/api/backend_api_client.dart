import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../logging/logger.dart';
import '../models/article.dart';
import '../models/memorization_passage.dart';
import '../models/proficiency_state.dart';
import '../models/release_info.dart';
import '../models/shadowing_video.dart';
import '../models/submitted_word.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';
import '../models/workplace_sentence.dart';
import 'models/content_models.dart';
import 'models/exam_models.dart';
import 'models/learning_models.dart';
import 'models/speaking_models.dart';

// Barrel exports for backward compatibility.
export 'models/content_models.dart';
export 'models/exam_models.dart';
export 'models/learning_models.dart';
export 'models/speaking_models.dart';

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
    final bodyBytes = Uint8List.fromList(utf8.encode(payload));
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
                body: bodyBytes,
                sessionToken: sessionToken,
              ),
            },
            body: bodyBytes,
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

  Future<List<WorkplaceSentence>> fetchWorkplaceSentences({
    int limit = 20,
    String targetLanguage = 'en',
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/workplace-sentences/recent').replace(
      queryParameters: {
        'limit': '$limit',
        'target_language': targetLanguage,
      },
    );
    await _logger.info(
      category: AppLogCategory.api,
      event: 'workplace_sentences.request',
      message: 'Requesting workplace sentences from backend.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'limit': limit,
        'target_language': targetLanguage,
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
        event: 'workplace_sentences.timeout',
        message: 'Workplace sentence request timed out.',
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
      event: 'workplace_sentences.response',
      message: 'Received workplace sentence response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );

    _throwIfFailed(response, 'Workplace sentence batch failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List? ?? const [];
    return items
        .map((item) => WorkplaceSentence.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
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

  Future<SubmittedWord> createSubmittedWord({
    required String localSubmissionId,
    required String deviceId,
    required String term,
    required String targetLanguage,
    String? sessionToken,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/user-submitted-words');
    final payload = jsonEncode({
      'device_id': deviceId,
      'term': term,
      'target_language': targetLanguage,
    });
    final bodyBytes = Uint8List.fromList(utf8.encode(payload));
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            ..._signedHeaders(
              method: 'POST',
              uri: uri,
              body: bodyBytes,
              sessionToken: sessionToken,
            ),
          },
          body: bodyBytes,
        )
        .timeout(timeout);
    _throwIfFailed(response, 'Submitted-word create failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SubmittedWord.fromJson(body, localSubmissionId: localSubmissionId);
  }

  Future<List<SubmittedWord>> fetchSubmittedWords({
    required String deviceId,
    int limit = 50,
    String? sessionToken,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/user-submitted-words').replace(
      queryParameters: {
        'device_id': deviceId,
        'limit': '$limit',
      },
    );
    final response = await _httpClient
        .get(
          uri,
          headers: _signedHeaders(
            method: 'GET',
            uri: uri,
            sessionToken: sessionToken,
          ),
        )
        .timeout(timeout);
    _throwIfFailed(response, 'Submitted-word fetch failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List? ?? const [];
    return items
        .map((item) => SubmittedWord.fromJson(
              item as Map<String, dynamic>,
              localSubmissionId: (item['id'] as String?) ?? '',
            ))
        .toList(growable: false);
  }

  Future<List<ShadowingVideo>> fetchShadowingVideos({
    required String deviceId,
    int limit = 50,
    String? sessionToken,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/shadowing/videos').replace(
      queryParameters: {
        'device_id': deviceId,
        'limit': '$limit',
      },
    );
    final response = await _httpClient
        .get(
          uri,
          headers: _signedHeaders(
            method: 'GET',
            uri: uri,
            sessionToken: sessionToken,
          ),
        )
        .timeout(timeout);
    _throwIfFailed(response, 'Shadowing video fetch failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ShadowingVideo.fromJson)
        .toList(growable: false);
  }

  Future<ShadowingVideo> importShadowingVideo({
    required String deviceId,
    required String sourceUrl,
    String? sessionToken,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/shadowing/videos');
    final payload = jsonEncode({
      'device_id': deviceId,
      'source_url': sourceUrl,
    });
    final bodyBytes = Uint8List.fromList(utf8.encode(payload));
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            ..._signedHeaders(
              method: 'POST',
              uri: uri,
              body: bodyBytes,
              sessionToken: sessionToken,
            ),
          },
          body: bodyBytes,
        )
        .timeout(timeout);
    _throwIfFailed(response, 'Shadowing video import failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ShadowingVideo.fromJson(body);
  }

  Future<ShadowingVideo> fetchShadowingVideoDetail({
    required String entryId,
    required String deviceId,
    String? sessionToken,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/shadowing/videos/$entryId').replace(
      queryParameters: {'device_id': deviceId},
    );
    final response = await _httpClient
        .get(
          uri,
          headers: _signedHeaders(
            method: 'GET',
            uri: uri,
            sessionToken: sessionToken,
          ),
        )
        .timeout(timeout);
    _throwIfFailed(response, 'Shadowing video detail failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ShadowingVideo.fromJson(body);
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

  Future<void> uploadLogArchive({
    required String payload,
    required String fileName,
    required String deviceId,
    String? sessionToken,
    String sourceLabel = 'mobile',
    String contentType = 'text/plain; charset=utf-8',
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/mobile/log-archives');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'log_archive.upload.request',
      message: 'Uploading sanitized log archive.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'file_name': fileName,
        'device_id': deviceId,
        'has_session_token': sessionToken != null,
      },
    );
    final stopwatch = Stopwatch()..start();
    final bodyBytes = Uint8List.fromList(utf8.encode(payload));
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'content-type': contentType,
              'x-expat8-device-id': deviceId,
              'x-expat8-log-source': sourceLabel,
              'x-expat8-log-filename': fileName,
              ..._signedHeaders(
                method: 'POST',
                uri: uri,
                body: bodyBytes,
                sessionToken: sessionToken,
              ),
            },
            body: bodyBytes,
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'log_archive.upload.timeout',
        message: 'Log archive upload timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'file_name': fileName,
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
      event: 'log_archive.upload.response',
      message: 'Received log archive upload response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Log archive upload failed');
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
    String? backendReason;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      backendError = body['error'] as String?;
      backendReason = body['reason'] as String?;
    } catch (_) {
      backendError = null;
      backendReason = null;
    }
    throw BackendApiException(
      '$context: ${response.statusCode}',
      statusCode: response.statusCode,
      backendError: backendError,
      backendReason: backendReason,
    );
  }

  /// Fetches approved speaking prompts for offline drill sync.
  ///
  /// Calls `GET /v1/speaking/prompts?limit=[limit]` and returns all items.
  Future<List<SpeakingPromptItem>> fetchSpeakingPrompts({
    int limit = 100,
  }) async {
    final traceId = _newTraceId();
    final uri =
        Uri.parse('$baseUrl/v1/speaking/prompts').replace(queryParameters: {
      'limit': '$limit',
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'speaking.prompts.request',
      message: 'Fetching approved speaking prompts.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _signedHeaders(method: 'GET', uri: uri))
          .timeout(timeout);
    } on TimeoutException {
      stopwatch.stop();
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'speaking.prompts.response',
      message: 'Received approved speaking prompts.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch speaking prompts failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(SpeakingPromptItem.fromJson)
        .toList();
  }

  Future<List<ManagedArticle>> listArticles({
    required String sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/articles');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.list.request',
      message: 'Requesting user articles.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final response = await _httpClient
        .get(
          uri,
          headers: _signedHeaders(
            method: 'GET',
            uri: uri,
            sessionToken: sessionToken,
          ),
        )
        .timeout(timeout);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.list.response',
      message: 'Received user articles.',
      traceId: traceId,
      context: {'status_code': response.statusCode},
    );
    _throwIfFailed(response, 'List articles failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ManagedArticle.fromJson)
        .toList(growable: false);
  }

  Future<ManagedArticle> createArticle({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
    String? sourceUrl,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/articles');
    final payload = jsonEncode({
      'title': title,
      'language': language,
      'raw_text': rawText,
      if (sourceUrl != null && sourceUrl.trim().isNotEmpty)
        'source_url': sourceUrl.trim(),
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.create.request',
      message: 'Creating article.',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'language': language,
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
      category: AppLogCategory.api,
      event: 'articles.create.response',
      message: 'Received article creation response.',
      traceId: traceId,
      context: {'status_code': response.statusCode},
    );
    _throwIfFailed(response, 'Create article failed');
    return ManagedArticle.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ManagedArticle> getArticle({
    required String sessionToken,
    required String articleId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/articles/$articleId');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.detail.request',
      message: 'Requesting article detail.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final response = await _httpClient
        .get(
          uri,
          headers: _signedHeaders(
            method: 'GET',
            uri: uri,
            sessionToken: sessionToken,
          ),
        )
        .timeout(timeout);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.detail.response',
      message: 'Received article detail response.',
      traceId: traceId,
      context: {'status_code': response.statusCode},
    );
    _throwIfFailed(response, 'Fetch article failed');
    return ManagedArticle.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ArticleVocabularyResponse> getArticleVocabulary({
    required String sessionToken,
    required String articleId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/articles/$articleId/vocabulary');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.vocabulary.request',
      message: 'Requesting article vocabulary.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final response = await _httpClient
        .get(
          uri,
          headers: _signedHeaders(
            method: 'GET',
            uri: uri,
            sessionToken: sessionToken,
          ),
        )
        .timeout(timeout);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.vocabulary.response',
      message: 'Received article vocabulary response.',
      traceId: traceId,
      context: {'status_code': response.statusCode},
    );
    _throwIfFailed(response, 'Fetch article vocabulary failed');
    return ArticleVocabularyResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteArticle({
    required String sessionToken,
    required String articleId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/articles/$articleId');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.delete.request',
      message: 'Deleting article.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final response = await _httpClient
        .delete(
          uri,
          headers: _signedHeaders(
            method: 'DELETE',
            uri: uri,
            sessionToken: sessionToken,
          ),
        )
        .timeout(timeout);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'articles.delete.response',
      message: 'Received article delete response.',
      traceId: traceId,
      context: {'status_code': response.statusCode},
    );
    _throwIfFailed(response, 'Delete article failed');
  }

  // ─── Memorization Passages ──────────────────────────────────────────────────

  Future<List<MemorizationPassage>> listPassages({
    required String sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/memorization/passages');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.list_passages.request',
      message: 'Fetching memorization passages list.',
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
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'memorization.list_passages.timeout',
        message: 'List passages request timed out.',
        traceId: traceId,
        context: {'elapsed_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.list_passages.response',
      message: 'Received passages list response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'List passages failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => MemorizationPassage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MemorizationPassage> createPassage({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/memorization/passages');
    final payload = jsonEncode({
      'title': title,
      'language': language,
      'raw_text': rawText,
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.create_passage.request',
      message: 'Creating memorization passage.',
      traceId: traceId,
      context: {'uri': uri.toString(), 'language': language, 'title_length': title.length},
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
    } on TimeoutException {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'memorization.create_passage.timeout',
        message: 'Create passage request timed out.',
        traceId: traceId,
        context: {'elapsed_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.create_passage.response',
      message: 'Received create passage response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Create passage failed');
    return MemorizationPassage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MemorizationPassage> getPassage({
    required String sessionToken,
    required String passageId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/memorization/passages/$passageId');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.get_passage.request',
      message: 'Fetching memorization passage.',
      traceId: traceId,
      context: {'passage_id': passageId},
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
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'memorization.get_passage.timeout',
        message: 'Get passage request timed out.',
        traceId: traceId,
        context: {'passage_id': passageId, 'elapsed_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.get_passage.response',
      message: 'Received get passage response.',
      traceId: traceId,
      context: {
        'passage_id': passageId,
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch passage failed');
    return MemorizationPassage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deletePassage({
    required String sessionToken,
    required String passageId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/memorization/passages/$passageId');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.delete_passage.request',
      message: 'Deleting memorization passage.',
      traceId: traceId,
      context: {'passage_id': passageId},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .delete(
            uri,
            headers: _signedHeaders(
              method: 'DELETE',
              uri: uri,
              sessionToken: sessionToken,
            ),
          )
          .timeout(timeout);
    } on TimeoutException {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'memorization.delete_passage.timeout',
        message: 'Delete passage request timed out.',
        traceId: traceId,
        context: {'passage_id': passageId, 'elapsed_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.delete_passage.response',
      message: 'Received delete passage response.',
      traceId: traceId,
      context: {
        'passage_id': passageId,
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Delete passage failed');
  }

  Future<List<MemorizationSegmentProgress>> getPassageProgress({
    required String sessionToken,
    required String passageId,
  }) async {
    final traceId = _newTraceId();
    final uri =
        Uri.parse('$baseUrl/v1/memorization/progress?passage_id=$passageId');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.get_progress.request',
      message: 'Fetching memorization passage progress.',
      traceId: traceId,
      context: {'passage_id': passageId},
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
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'memorization.get_progress.timeout',
        message: 'Get passage progress request timed out.',
        traceId: traceId,
        context: {'passage_id': passageId, 'elapsed_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.get_progress.response',
      message: 'Received passage progress response.',
      traceId: traceId,
      context: {
        'passage_id': passageId,
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch passage progress failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? [];
    return items
        .map((e) =>
            MemorizationSegmentProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertSegmentProgress({
    required String sessionToken,
    required List<Map<String, dynamic>> progressUpdates,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/memorization/progress');
    final payload = jsonEncode({'entries': progressUpdates});
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.upsert_progress.request',
      message: 'Upserting memorization segment progress.',
      traceId: traceId,
      context: {'entry_count': progressUpdates.length},
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
    } on TimeoutException {
      stopwatch.stop();
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'memorization.upsert_progress.timeout',
        message: 'Upsert segment progress request timed out.',
        traceId: traceId,
        context: {'entry_count': progressUpdates.length, 'elapsed_ms': stopwatch.elapsedMilliseconds},
      );
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'memorization.upsert_progress.response',
      message: 'Received upsert progress response.',
      traceId: traceId,
      context: {
        'entry_count': progressUpdates.length,
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Upsert segment progress failed');
  }

  // ─── Exam endpoints ─────────────────────────────────────────────────────────

  /// Returns the list of topics the signed-in user has studied words in for
  /// [language]. Calls `GET /v1/exam/topics?language=<language>`.
  Future<List<String>> fetchExamTopics({
    required String sessionToken,
    String language = 'en',
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/exam/topics').replace(queryParameters: {
      'language': language,
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.topics.request',
      message: 'Fetching exam topics.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .get(uri,
              headers: _signedHeaders(
                  method: 'GET', uri: uri, sessionToken: sessionToken))
          .timeout(timeout);
    } on TimeoutException {
      stopwatch.stop();
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.topics.response',
      message: 'Received exam topics.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch exam topics failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ((body['topics'] as List<dynamic>?) ?? [])
        .whereType<String>()
        .toList();
  }

  /// Checks whether the backend is ready without sending app credential headers.
  Future<bool> checkBackendReadiness() async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/health/ready');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'health.ready.request',
      message: 'Checking backend readiness.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _httpClient.get(uri).timeout(timeout);
      await _logger.info(
        category: AppLogCategory.api,
        event: 'health.ready.response',
        message: 'Received backend readiness response.',
        traceId: traceId,
        context: {
          'status_code': response.statusCode,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'health.ready.unhealthy',
        message: 'Backend readiness probe reported unhealthy.',
        traceId: traceId,
        context: {
          'status_code': response.statusCode,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        },
      );
      return false;
    } on TimeoutException catch (error) {
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'health.ready.timeout',
        message: 'Backend readiness probe timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      return false;
    } catch (error) {
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'health.ready.failed',
        message: 'Backend readiness probe failed.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
        },
      );
      return false;
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
  }

  /// Calls `POST /v1/exam/start` to generate a new exam session.
  ///
  /// Returns an [ExamSessionResponse]. Throws [BackendApiException] with
  /// `backendError == 'INSUFFICIENT_WORDS'` when fewer than 5 words are
  /// available for the requested language.
  Future<ExamSessionResponse> startExamSession({
    required String sessionToken,
    String language = 'en',
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/exam/start');
    final rawBody = utf8.encode(jsonEncode({'language': language}));
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.start.request',
      message: 'Starting exam session.',
      traceId: traceId,
      context: {'language': language},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              ..._signedHeaders(
                  method: 'POST',
                  uri: uri,
                  body: Uint8List.fromList(rawBody),
                  sessionToken: sessionToken),
              'content-type': 'application/json',
            },
            body: rawBody,
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
      event: 'exam.start.response',
      message: 'Received exam session.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Start exam session failed');
    return ExamSessionResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Calls `POST /v1/exam/submit` to score an exam session.
  ///
  /// [answers] is a list of 0-based choice indices in question ordinal order.
  Future<ExamSubmitResponse> submitExamSession({
    required String sessionToken,
    required String sessionId,
    required List<int> answers,
    String? localAttemptId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/exam/submit');
    final bodyMap = <String, dynamic>{
      'session_id': sessionId,
      'answers': answers,
      if (localAttemptId != null) 'local_attempt_id': localAttemptId,
    };
    final rawBody = utf8.encode(jsonEncode(bodyMap));
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.submit.request',
      message: 'Submitting exam session.',
      traceId: traceId,
      context: {'session_id': sessionId},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              ..._signedHeaders(
                  method: 'POST',
                  uri: uri,
                  body: Uint8List.fromList(rawBody),
                  sessionToken: sessionToken),
              'content-type': 'application/json',
            },
            body: rawBody,
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
      event: 'exam.submit.response',
      message: 'Received exam result.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Submit exam session failed');
    return ExamSubmitResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Calls `GET /v1/exam/results?page=<page>&limit=<limit>` to retrieve the
  /// authenticated user's exam history.
  Future<ExamResultsPage> fetchExamResults({
    required String sessionToken,
    int page = 1,
    int limit = 20,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/exam/results').replace(queryParameters: {
      'page': '$page',
      'limit': '$limit',
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.results.request',
      message: 'Fetching exam results.',
      traceId: traceId,
      context: {'uri': uri.toString()},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .get(uri,
              headers: _signedHeaders(
                  method: 'GET', uri: uri, sessionToken: sessionToken))
          .timeout(timeout);
    } on TimeoutException {
      stopwatch.stop();
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.results.response',
      message: 'Received exam results.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch exam results failed');
    return ExamResultsPage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Calls `GET /v1/exam/certificate/:id` (public — no session required).
  Future<ExamCertificate> fetchExamCertificate({
    required String certificateId,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/exam/certificate/$certificateId');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.certificate.request',
      message: 'Fetching exam certificate.',
      traceId: traceId,
      context: {'certificate_id': certificateId},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _signedHeaders(method: 'GET', uri: uri))
          .timeout(timeout);
    } on TimeoutException {
      stopwatch.stop();
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.certificate.response',
      message: 'Received exam certificate.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch exam certificate failed');
    return ExamCertificate.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Lists published content packs for [language].
  ///
  /// Pass [afterVersion] to receive only packs with a higher version number
  /// (incremental sync). Returns at most [limit] results (1–200).
  Future<List<ContentPackSummary>> listContentPacks({
    String language = 'en',
    int? afterVersion,
    int limit = 100,
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final queryParams = <String, String>{
      'language': language,
      'limit': limit.toString(),
      if (afterVersion != null) 'after_version': afterVersion.toString(),
    };
    final uri = Uri.parse('$baseUrl/v1/content-packs')
        .replace(queryParameters: queryParams);
    await _logger.info(
      category: AppLogCategory.api,
      event: 'content_packs.list.request',
      message: 'Requesting content pack list.',
      traceId: traceId,
      context: {
        'language': language,
        'after_version': afterVersion,
        'limit': limit,
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
    } on TimeoutException {
      stopwatch.stop();
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'content_packs.list.response',
      message: 'Received content pack list.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'List content packs failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ContentPackSummary.fromJson)
        .toList(growable: false);
  }

  /// Downloads a single published content pack by [id].
  ///
  /// Returns `null` when the pack is not found (404).
  Future<ContentPack?> fetchContentPack({
    required String id,
    String? sessionToken,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/content-packs/$id');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'content_pack.fetch.request',
      message: 'Fetching content pack.',
      traceId: traceId,
      context: {'pack_id': id},
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
      event: 'content_pack.fetch.response',
      message: 'Received content pack.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    if (response.statusCode == 404) return null;
    _throwIfFailed(response, 'Fetch content pack failed');
    return ContentPack.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches the latest available release for [platform].
  ///
  /// Returns `null` if no release exists for the given platform.
  Future<ReleaseInfo?> fetchLatestRelease({
    String platform = 'android',
  }) async {
    final traceId = _newTraceId();
    final uri =
        Uri.parse('$baseUrl/v1/releases/latest').replace(queryParameters: {
      'platform': platform,
    });
    await _logger.info(
      category: AppLogCategory.api,
      event: 'releases.latest.request',
      message: 'Checking latest release.',
      traceId: traceId,
      context: {'platform': platform},
    );
    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _signedHeaders(method: 'GET', uri: uri))
          .timeout(timeout);
    } on TimeoutException {
      stopwatch.stop();
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'releases.latest.response',
      message: 'Received latest release response.',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    _throwIfFailed(response, 'Fetch latest release failed');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final release = body['release'];
    if (release == null) return null;
    return ReleaseInfo.fromJson(release as Map<String, dynamic>);
  }

  /// Downloads the release APK for [releaseId] to a temporary file.
  ///
  /// Calls [onProgress] periodically with (bytesReceived, totalBytes).
  /// Returns the path to the downloaded file.
  Future<String> downloadRelease(
    String releaseId, {
    void Function(int received, int total)? onProgress,
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/releases/$releaseId/download');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'releases.download.request',
      message: 'Downloading release APK.',
      traceId: traceId,
      context: {'release_id': releaseId},
    );
    final request = http.Request('GET', uri);
    request.headers.addAll(_signedHeaders(method: 'GET', uri: uri));
    final streamedResponse =
        await _httpClient.send(request).timeout(timeout);
    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      await streamedResponse.stream.drain<void>();
      throw BackendApiException(
        'Release download failed: ${streamedResponse.statusCode}',
        statusCode: streamedResponse.statusCode,
      );
    }
    final totalBytes = streamedResponse.contentLength ?? 0;
    final tempDir = io.Directory.systemTemp;
    final filePath = '${tempDir.path}/release-$releaseId.apk';
    final file = io.File(filePath);
    final sink = file.openWrite();
    int received = 0;
    try {
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, totalBytes);
      }
    } finally {
      await sink.close();
    }
    await _logger.info(
      category: AppLogCategory.api,
      event: 'releases.download.complete',
      message: 'Release APK downloaded.',
      traceId: traceId,
      context: {
        'release_id': releaseId,
        'file_path': filePath,
        'bytes': received,
      },
    );
    return filePath;
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

class BackendApiException implements Exception {
  BackendApiException(
    this.message, {
    this.statusCode,
    this.backendError,
    this.backendReason,
  });

  final String message;
  final int? statusCode;
  final String? backendError;
  final String? backendReason;

  @override
  String toString() => message;
}

// ─── Re-exported models (backward compatibility) ────────────────────────────
// DTOs have been extracted to models/ subdirectory.
// These exports maintain backward compatibility for existing imports.

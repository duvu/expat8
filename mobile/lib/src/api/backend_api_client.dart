import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../logging/logger.dart';
import '../models/article.dart';
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

  // ─── Exam endpoints ─────────────────────────────────────────────────────────

  /// Returns the list of topics the signed-in user has studied words in for
  /// [language]. Calls `GET /v1/exam/topics?language=<language>`.
  Future<List<String>> fetchExamTopics({
    required String sessionToken,
    String language = 'en',
  }) async {
    final traceId = _newTraceId();
    final uri =
        Uri.parse('$baseUrl/v1/exam/topics').replace(queryParameters: {
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

  /// Calls `POST /v1/exam/start` to generate a new exam session.
  ///
  /// Returns an [ExamSessionResponse]. Throws [BackendApiException] with
  /// `backendError == 'INSUFFICIENT_WORDS'` when fewer than 5 words are
  /// available for the requested topic and language.
  Future<ExamSessionResponse> startExamSession({
    required String sessionToken,
    required String topic,
    String language = 'en',
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/exam/start');
    final rawBody = utf8.encode(jsonEncode({'topic': topic, 'language': language}));
    await _logger.info(
      category: AppLogCategory.api,
      event: 'exam.start.request',
      message: 'Starting exam session.',
      traceId: traceId,
      context: {'topic': topic, 'language': language},
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
  }) async {
    final traceId = _newTraceId();
    final uri = Uri.parse('$baseUrl/v1/exam/submit');
    final rawBody = utf8.encode(
        jsonEncode({'session_id': sessionId, 'answers': answers}));
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
    final uri =
        Uri.parse('$baseUrl/v1/exam/results').replace(queryParameters: {
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

/// A single speaking prompt item returned by `GET /v1/speaking/prompts`.
class SpeakingPromptItem {
  const SpeakingPromptItem({
    required this.id,
    this.wordSenseId,
    required this.targetText,
    this.viHint,
    this.pronunciationTip,
    this.commonMistake,
    this.difficulty,
    this.topic,
  });

  factory SpeakingPromptItem.fromJson(Map<String, dynamic> json) {
    return SpeakingPromptItem(
      id: json['id'] as String? ?? '',
      wordSenseId: json['word_sense_id'] as String?,
      targetText: json['target_text'] as String? ?? '',
      viHint: json['vi_hint'] as String?,
      pronunciationTip: json['pronunciation_tip_vi'] as String?,
      commonMistake: json['common_mistake_vi'] as String?,
      difficulty: json['difficulty'] as String?,
      topic: json['topic'] as String?,
    );
  }

  final String id;
  final String? wordSenseId;
  final String targetText;
  final String? viHint;
  final String? pronunciationTip;
  final String? commonMistake;
  final String? difficulty;
  final String? topic;
}

// ─── Exam response models ────────────────────────────────────────────────────

/// A single question inside an exam session response.
class ExamQuestion {
  const ExamQuestion({
    required this.questionId,
    required this.ordinal,
    required this.promptWord,
    required this.choices,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      questionId: json['question_id'] as String? ?? '',
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
      promptWord: json['prompt_word'] as String? ?? '',
      choices: ((json['choices'] as List<dynamic>?) ?? [])
          .whereType<String>()
          .toList(),
    );
  }

  final String questionId;
  final int ordinal;
  final String promptWord;
  final List<String> choices;
}

/// Full exam session returned by `POST /v1/exam/start`.
class ExamSessionResponse {
  const ExamSessionResponse({
    required this.sessionId,
    required this.topic,
    required this.language,
    required this.questionCount,
    required this.expiresAt,
    required this.questions,
  });

  factory ExamSessionResponse.fromJson(Map<String, dynamic> json) {
    return ExamSessionResponse(
      sessionId: json['session_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] as String? ?? '',
      questions: ((json['questions'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ExamQuestion.fromJson)
          .toList(),
    );
  }

  final String sessionId;
  final String topic;
  final String language;
  final int questionCount;
  final String expiresAt;
  final List<ExamQuestion> questions;
}

/// Result returned by `POST /v1/exam/submit`.
class ExamSubmitResponse {
  const ExamSubmitResponse({
    required this.attemptId,
    required this.sessionId,
    required this.topic,
    required this.language,
    this.difficultyLevel,
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePct,
    required this.passed,
    this.certificateId,
    required this.createdAt,
  });

  factory ExamSubmitResponse.fromJson(Map<String, dynamic> json) {
    return ExamSubmitResponse(
      attemptId: json['attempt_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      difficultyLevel: json['difficulty_level'] as String?,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      scorePct: (json['score_pct'] as num?)?.toDouble() ?? 0,
      passed: json['passed'] == true,
      certificateId: json['certificate_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final String attemptId;
  final String sessionId;
  final String topic;
  final String language;
  final String? difficultyLevel;
  final int totalQuestions;
  final int correctCount;
  final double scorePct;
  final bool passed;
  final String? certificateId;
  final String createdAt;
}

/// A single item in the exam results list.
class ExamResultItem {
  const ExamResultItem({
    required this.attemptId,
    required this.topic,
    required this.language,
    this.difficultyLevel,
    required this.scorePct,
    required this.passed,
    required this.createdAt,
    this.certificateId,
  });

  factory ExamResultItem.fromJson(Map<String, dynamic> json) {
    return ExamResultItem(
      attemptId: json['attempt_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      difficultyLevel: json['difficulty_level'] as String?,
      scorePct: (json['score_pct'] as num?)?.toDouble() ?? 0,
      passed: json['passed'] == true,
      createdAt: json['created_at'] as String? ?? '',
      certificateId: json['certificate_id'] as String?,
    );
  }

  final String attemptId;
  final String topic;
  final String language;
  final String? difficultyLevel;
  final double scorePct;
  final bool passed;
  final String createdAt;
  final String? certificateId;
}

/// Paginated exam results returned by `GET /v1/exam/results`.
class ExamResultsPage {
  const ExamResultsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory ExamResultsPage.fromJson(Map<String, dynamic> json) {
    return ExamResultsPage(
      items: ((json['items'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ExamResultItem.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
    );
  }

  final List<ExamResultItem> items;
  final int total;
  final int page;
  final int limit;
}

/// Public certificate returned by `GET /v1/exam/certificate/:id`.
class ExamCertificate {
  const ExamCertificate({
    required this.certificateId,
    required this.topic,
    required this.language,
    this.difficultyLevel,
    required this.scorePct,
    required this.issuedAt,
    required this.disclaimer,
  });

  factory ExamCertificate.fromJson(Map<String, dynamic> json) {
    return ExamCertificate(
      certificateId: json['certificate_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      difficultyLevel: json['difficulty_level'] as String?,
      scorePct: (json['score_pct'] as num?)?.toDouble() ?? 0,
      issuedAt: json['issued_at'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }

  final String certificateId;
  final String topic;
  final String language;
  final String? difficultyLevel;
  final double scorePct;
  final String issuedAt;
  final String disclaimer;
}

/// Lightweight summary returned by `GET /v1/content-packs`.
class ContentPackSummary {
  const ContentPackSummary({
    required this.id,
    required this.language,
    required this.version,
    required this.status,
    required this.createdAt,
    this.publishedAt,
  });

  factory ContentPackSummary.fromJson(Map<String, dynamic> json) {
    return ContentPackSummary(
      id: json['id'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      version: (json['version'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      publishedAt: json['published_at'] as String?,
    );
  }

  final String id;
  final String language;
  final int version;
  final String status;
  final String createdAt;
  final String? publishedAt;
}

/// A single vocabulary entry inside a content pack.
class ContentPackItem {
  const ContentPackItem({
    required this.id,
    required this.wordSenseId,
    required this.createdAt,
  });

  factory ContentPackItem.fromJson(Map<String, dynamic> json) {
    return ContentPackItem(
      id: json['id'] as String? ?? '',
      wordSenseId: json['word_sense_id'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final String id;
  final String wordSenseId;
  final String createdAt;
}

/// Full content pack returned by `GET /v1/content-packs/:id`.
class ContentPack extends ContentPackSummary {
  const ContentPack({
    required super.id,
    required super.language,
    required super.version,
    required super.status,
    required super.createdAt,
    super.publishedAt,
    required this.items,
  });

  factory ContentPack.fromJson(Map<String, dynamic> json) {
    final base = ContentPackSummary.fromJson(json);
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return ContentPack(
      id: base.id,
      language: base.language,
      version: base.version,
      status: base.status,
      createdAt: base.createdAt,
      publishedAt: base.publishedAt,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ContentPackItem.fromJson)
          .toList(growable: false),
    );
  }

  final List<ContentPackItem> items;
}

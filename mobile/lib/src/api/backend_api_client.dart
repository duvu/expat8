import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../logging/logger.dart';
import '../models/article.dart';
import '../models/memorization_passage.dart';
import '../models/proficiency_state.dart';
import '../models/release_info.dart';
import '../models/review_state.dart';
import '../models/shadowing_video.dart';
import '../models/submitted_word.dart';
import '../models/user_session.dart';
import '../models/vocabulary_word.dart';
import '../models/workplace_sentence.dart';
import 'models/content_models.dart';
import 'models/exam_models.dart';
import 'models/game_models.dart';
import 'models/learning_models.dart';
import 'models/speaking_models.dart';

// Barrel exports for backward compatibility.
export 'models/content_models.dart';
export 'models/exam_models.dart';
export 'models/game_models.dart';
export 'models/learning_models.dart';
export 'models/speaking_models.dart';

/// Typed access to the Expat8 backend. Every request goes through [_send]
/// (HMAC signing, timeout, request/response/timeout logging); endpoint
/// methods only describe the path, the payload and how to read the result.
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

  // ─── Learning ──────────────────────────────────────────────────────────────

  Future<ProficiencyState> fetchProficiency({
    required String deviceId,
    String language = 'en',
    String? sessionToken,
  }) async {
    final body = await _json('GET',
        _uri('/v1/proficiency', {'device_id': deviceId, 'language': language}),
        event: 'proficiency',
        failure: 'Proficiency fetch failed',
        sessionToken: sessionToken);
    return ProficiencyState.fromJson(body);
  }

  /// SRS states changed since [cursor] (`GET /v1/review/states`).
  Future<ReviewStatesPage> fetchReviewStates({
    required String deviceId,
    required String language,
    String? cursor,
    String? sessionToken,
  }) async {
    final body = await _json(
        'GET',
        _uri('/v1/review/states', {
          'device_id': deviceId,
          'language': language,
          if (cursor != null) 'cursor': cursor,
        }),
        event: 'review.states',
        failure: 'Review states fetch failed',
        sessionToken: sessionToken);
    return ReviewStatesPage(
      items: _items(body, ServerReviewState.fromJson),
      nextCursor: body['next_cursor'] as String?,
      hasMore: body['has_more'] == true,
    );
  }

  Future<StudyEventResult> submitStudyEvent({
    required String deviceId,
    required Map<String, dynamic> event,
    String language = 'en',
    String? sessionToken,
  }) async {
    final body = await _json('POST', _uri('/v1/study-events'),
        event: 'study_event',
        failure: 'Study-event submit failed',
        json: {'device_id': deviceId, 'language': language, ...event},
        sessionToken: sessionToken);
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
    String? level,
  }) async {
    final body = await _json('POST', _uri('/v1/learning/cards'),
        event: 'learning_cards',
        failure: 'Learning-card batch failed',
        json: {
          'device_id': deviceId,
          'limit': limit,
          'target_language': targetLanguage,
          'card_mode': 'new',
          // Session study-level override; omitted means the learner's own level.
          if (level != null) 'level': level,
        },
        sessionToken: sessionToken,
        logContext: {
          'limit': limit,
          'target_language': targetLanguage,
          'level': level,
        });
    return LearningCardBatch(
      items: _items(body, VocabularyWord.fromJson),
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
    final body = await _json(
        'GET',
        _uri('/v1/workplace-sentences/recent',
            {'limit': '$limit', 'target_language': targetLanguage}),
        event: 'workplace_sentences',
        failure: 'Workplace sentence batch failed',
        sessionToken: sessionToken);
    return _items(body, WorkplaceSentence.fromJson);
  }

  Future<CacheInventoryResult> syncCacheInventory({
    required String deviceId,
    required List<String> serverWordIds,
    DateTime? observedAt,
    String? sessionToken,
  }) async {
    final body = await _json('PUT', _uri('/v1/user-word-cache'),
        event: 'cache_inventory',
        failure: 'Cache inventory sync failed',
        category: AppLogCategory.sync,
        json: {
          'device_id': deviceId,
          'server_word_ids': serverWordIds,
          'observed_at':
              (observedAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
        },
        sessionToken: sessionToken,
        logContext: {'server_word_ids_count': serverWordIds.length});
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
    String? language,
  }) async {
    final body = await _json('POST', _uri('/v1/study-events/sync'),
        event: 'sync',
        failure: 'Study-event sync failed',
        category: AppLogCategory.sync,
        json: {
          'device_id': deviceId,
          if (language != null) 'language': language,
          'events': events,
        },
        sessionToken: sessionToken,
        logContext: {'events_count': events.length});
    return SyncResult(
      acceptedEventIds: List<String>.from(
        body['accepted_event_ids'] as List? ?? const [],
      ),
      rejectedEvents: List<Map<String, dynamic>>.from(
        body['rejected_events'] as List? ?? const [],
      ),
      duplicateEventIds: List<String>.from(
        body['duplicates'] as List? ?? const [],
      ),
      proficiency: body['proficiency'] is Map<String, dynamic>
          ? ProficiencyState.fromJson(
              body['proficiency'] as Map<String, dynamic>)
          : null,
    );
  }

  // ─── Submitted words & shadowing ──────────────────────────────────────────

  Future<SubmittedWord> createSubmittedWord({
    required String localSubmissionId,
    required String deviceId,
    required String term,
    required String targetLanguage,
    String? sessionToken,
  }) async {
    final body = await _json('POST', _uri('/v1/user-submitted-words'),
        event: 'submitted_word.create',
        failure: 'Submitted-word create failed',
        json: {
          'device_id': deviceId,
          'term': term,
          'target_language': targetLanguage,
        },
        sessionToken: sessionToken);
    return SubmittedWord.fromJson(body, localSubmissionId: localSubmissionId);
  }

  Future<List<SubmittedWord>> fetchSubmittedWords({
    required String deviceId,
    int limit = 50,
    String? sessionToken,
  }) async {
    final body = await _json(
        'GET',
        _uri('/v1/user-submitted-words',
            {'device_id': deviceId, 'limit': '$limit'}),
        event: 'submitted_word.list',
        failure: 'Submitted-word fetch failed',
        sessionToken: sessionToken);
    return _items(
        body,
        (item) => SubmittedWord.fromJson(item,
            localSubmissionId: (item['id'] as String?) ?? ''));
  }

  Future<List<ShadowingVideo>> fetchShadowingVideos({
    required String deviceId,
    int limit = 50,
    String? sessionToken,
  }) async {
    final body = await _json(
        'GET',
        _uri(
            '/v1/shadowing/videos', {'device_id': deviceId, 'limit': '$limit'}),
        event: 'shadowing.list',
        failure: 'Shadowing video fetch failed',
        sessionToken: sessionToken);
    return _items(body, ShadowingVideo.fromJson);
  }

  Future<ShadowingVideo> importShadowingVideo({
    required String deviceId,
    required String sourceUrl,
    String? sessionToken,
  }) async =>
      ShadowingVideo.fromJson(await _json('POST', _uri('/v1/shadowing/videos'),
          event: 'shadowing.import',
          failure: 'Shadowing video import failed',
          json: {'device_id': deviceId, 'source_url': sourceUrl},
          sessionToken: sessionToken));

  Future<ShadowingVideo> fetchShadowingVideoDetail({
    required String entryId,
    required String deviceId,
    String? sessionToken,
  }) async =>
      ShadowingVideo.fromJson(await _json(
          'GET', _uri('/v1/shadowing/videos/$entryId', {'device_id': deviceId}),
          event: 'shadowing.detail',
          failure: 'Shadowing video detail failed',
          sessionToken: sessionToken));

  // ─── Accounts ──────────────────────────────────────────────────────────────

  Future<UserSession> registerUser({
    required String identifier,
    required String password,
    String? displayName,
    String? deviceId,
  }) async =>
      UserSession.fromJson(await _json('POST', _uri('/v1/users/register'),
          event: 'auth.register',
          failure: 'Registration failed',
          category: AppLogCategory.auth,
          json: {
            'identifier': identifier,
            'password': password,
            if (displayName != null) 'display_name': displayName,
            if (deviceId != null) 'device_id': deviceId,
          },
          logContext: {
            'has_display_name': displayName != null,
            'has_device_id': deviceId != null,
          }));

  Future<UserSession> signIn({
    required String identifier,
    required String password,
    String? deviceId,
  }) async =>
      UserSession.fromJson(await _json('POST', _uri('/v1/users/sign-in'),
          event: 'auth.sign_in',
          failure: 'Sign-in failed',
          category: AppLogCategory.auth,
          json: {
            'identifier': identifier,
            'password': password,
            if (deviceId != null) 'device_id': deviceId,
          },
          logContext: {
            'has_device_id': deviceId != null
          }));

  Future<void> signOut({required UserSession session}) =>
      _call('POST', _uri('/v1/users/sign-out'),
          event: 'auth.sign_out',
          failure: 'Sign-out failed',
          category: AppLogCategory.auth,
          json: const <String, Object?>{},
          sessionToken: session.sessionToken);

  // ─── Diagnostics & games ───────────────────────────────────────────────────

  Future<void> uploadLogArchive({
    required String payload,
    required String fileName,
    required String deviceId,
    String? sessionToken,
    String sourceLabel = 'mobile',
    String contentType = 'text/plain; charset=utf-8',
  }) =>
      _call('POST', _uri('/v1/mobile/log-archives'),
          event: 'log_archive.upload',
          failure: 'Log archive upload failed',
          rawBody: Uint8List.fromList(utf8.encode(payload)),
          headers: {
            'content-type': contentType,
            'x-expat8-device-id': deviceId,
            'x-expat8-log-source': sourceLabel,
            'x-expat8-log-filename': fileName,
          },
          sessionToken: sessionToken,
          logContext: {
            'file_name': fileName,
            'device_id': deviceId,
            'has_session_token': sessionToken != null,
          });

  /// Uploads finished game rounds (idempotent by `client_round_id`).
  Future<GameRoundSyncResult> syncGameRounds({
    required String deviceId,
    required List<Map<String, dynamic>> rounds,
    String? sessionToken,
  }) async {
    final body = await _json('POST', _uri('/v1/games/rounds'),
        event: 'games.rounds',
        failure: 'Game round sync failed',
        json: {'device_id': deviceId, 'rounds': rounds},
        sessionToken: sessionToken);
    List<String> ids(String key) =>
        List<String>.from(body[key] as List? ?? const []);
    return GameRoundSyncResult(
      acceptedRoundIds: ids('accepted_round_ids'),
      duplicateRoundIds: ids('duplicates'),
      rejectedRounds: List<Map<String, dynamic>>.from(
        body['rejected_rounds'] as List? ?? const [],
      ),
    );
  }

  /// Weekly leaderboard for signed-in learners.
  Future<GameLeaderboard> fetchGameLeaderboard({
    required String sessionToken,
    required String game,
    required String mode,
  }) async =>
      GameLeaderboard.fromJson(await _json(
          'GET', _uri('/v1/games/leaderboard', {'game': game, 'mode': mode}),
          event: 'games.leaderboard',
          failure: 'Game leaderboard fetch failed',
          sessionToken: sessionToken));

  // ─── Speaking ──────────────────────────────────────────────────────────────

  /// Fetches the weekly speaking summary for [deviceId] (and optionally a
  /// signed-in user via [sessionToken]).
  Future<SpeakingWeeklySummary> fetchSpeakingSummary({
    required String deviceId,
    String language = 'en',
    String period = 'week',
    String? sessionToken,
  }) async =>
      SpeakingWeeklySummary.fromJson(await _json(
          'GET',
          _uri('/v1/speaking/summary',
              {'device_id': deviceId, 'language': language, 'period': period}),
          event: 'speaking.summary',
          failure: 'Fetch speaking summary failed',
          sessionToken: sessionToken));

  /// Fetches approved speaking prompts for offline drill sync.
  Future<List<SpeakingPromptItem>> fetchSpeakingPrompts({
    int limit = 100,
  }) async =>
      _items(
          await _json('GET', _uri('/v1/speaking/prompts', {'limit': '$limit'}),
              event: 'speaking.prompts',
              failure: 'Fetch speaking prompts failed'),
          SpeakingPromptItem.fromJson);

  // ─── Articles ──────────────────────────────────────────────────────────────

  Future<List<ManagedArticle>> listArticles({
    required String sessionToken,
  }) async =>
      _items(
          await _json('GET', _uri('/v1/articles'),
              event: 'articles.list',
              failure: 'List articles failed',
              sessionToken: sessionToken),
          ManagedArticle.fromJson);

  Future<ManagedArticle> createArticle({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
    String? sourceUrl,
  }) async =>
      ManagedArticle.fromJson(await _json('POST', _uri('/v1/articles'),
          event: 'articles.create',
          failure: 'Create article failed',
          json: {
            'title': title,
            'language': language,
            'raw_text': rawText,
            if (sourceUrl != null && sourceUrl.trim().isNotEmpty)
              'source_url': sourceUrl.trim(),
          },
          sessionToken: sessionToken,
          logContext: {'language': language}));

  Future<ManagedArticle> getArticle({
    required String sessionToken,
    required String articleId,
  }) async =>
      ManagedArticle.fromJson(await _json(
          'GET', _uri('/v1/articles/$articleId'),
          event: 'articles.detail',
          failure: 'Fetch article failed',
          sessionToken: sessionToken));

  Future<ArticleVocabularyResponse> getArticleVocabulary({
    required String sessionToken,
    required String articleId,
  }) async =>
      ArticleVocabularyResponse.fromJson(await _json(
          'GET', _uri('/v1/articles/$articleId/vocabulary'),
          event: 'articles.vocabulary',
          failure: 'Fetch article vocabulary failed',
          sessionToken: sessionToken));

  Future<void> deleteArticle({
    required String sessionToken,
    required String articleId,
  }) =>
      _call('DELETE', _uri('/v1/articles/$articleId'),
          event: 'articles.delete',
          failure: 'Delete article failed',
          sessionToken: sessionToken);

  // ─── Memorization passages ─────────────────────────────────────────────────

  Future<List<MemorizationPassage>> listPassages({
    required String sessionToken,
  }) async =>
      _items(
          await _json('GET', _uri('/v1/memorization/passages'),
              event: 'memorization.list_passages',
              failure: 'List passages failed',
              sessionToken: sessionToken),
          MemorizationPassage.fromJson);

  Future<MemorizationPassage> createPassage({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
  }) async =>
      MemorizationPassage.fromJson(await _json(
          'POST', _uri('/v1/memorization/passages'),
          event: 'memorization.create_passage',
          failure: 'Create passage failed',
          json: {'title': title, 'language': language, 'raw_text': rawText},
          sessionToken: sessionToken,
          logContext: {'language': language, 'title_length': title.length}));

  Future<MemorizationPassage> getPassage({
    required String sessionToken,
    required String passageId,
  }) async =>
      MemorizationPassage.fromJson(await _json(
          'GET', _uri('/v1/memorization/passages/$passageId'),
          event: 'memorization.get_passage',
          failure: 'Fetch passage failed',
          sessionToken: sessionToken,
          logContext: {'passage_id': passageId}));

  Future<void> deletePassage({
    required String sessionToken,
    required String passageId,
  }) =>
      _call('DELETE', _uri('/v1/memorization/passages/$passageId'),
          event: 'memorization.delete_passage',
          failure: 'Delete passage failed',
          sessionToken: sessionToken,
          logContext: {'passage_id': passageId});

  Future<List<MemorizationSegmentProgress>> getPassageProgress({
    required String sessionToken,
    required String passageId,
  }) async =>
      _items(
          await _json('GET',
              _uri('/v1/memorization/progress', {'passage_id': passageId}),
              event: 'memorization.get_progress',
              failure: 'Fetch passage progress failed',
              sessionToken: sessionToken,
              logContext: {'passage_id': passageId}),
          MemorizationSegmentProgress.fromJson);

  Future<void> upsertSegmentProgress({
    required String sessionToken,
    required List<Map<String, dynamic>> progressUpdates,
  }) =>
      _call('POST', _uri('/v1/memorization/progress'),
          event: 'memorization.upsert_progress',
          failure: 'Upsert segment progress failed',
          json: {'entries': progressUpdates},
          sessionToken: sessionToken,
          logContext: {'entry_count': progressUpdates.length});

  // ─── Exams ─────────────────────────────────────────────────────────────────

  /// Topics the signed-in user has studied words in for [language].
  Future<List<String>> fetchExamTopics({
    required String sessionToken,
    String language = 'en',
  }) async {
    final body = await _json(
        'GET', _uri('/v1/exam/topics', {'language': language}),
        event: 'exam.topics',
        failure: 'Fetch exam topics failed',
        sessionToken: sessionToken);
    return ((body['topics'] as List<dynamic>?) ?? [])
        .whereType<String>()
        .toList();
  }

  /// Generates a new exam session. Throws [BackendApiException] with
  /// `backendError == 'INSUFFICIENT_WORDS'` when fewer than 5 words are
  /// available for [language].
  Future<ExamSessionResponse> startExamSession({
    required String sessionToken,
    String language = 'en',
  }) async =>
      ExamSessionResponse.fromJson(await _json('POST', _uri('/v1/exam/start'),
          event: 'exam.start',
          failure: 'Start exam session failed',
          json: {'language': language},
          sessionToken: sessionToken,
          logContext: {'language': language}));

  /// Scores an exam session; [answers] are 0-based choice indices in
  /// question order.
  Future<ExamSubmitResponse> submitExamSession({
    required String sessionToken,
    required String sessionId,
    required List<int> answers,
    String? localAttemptId,
  }) async =>
      ExamSubmitResponse.fromJson(await _json('POST', _uri('/v1/exam/submit'),
          event: 'exam.submit',
          failure: 'Submit exam session failed',
          json: {
            'session_id': sessionId,
            'answers': answers,
            if (localAttemptId != null) 'local_attempt_id': localAttemptId,
          },
          sessionToken: sessionToken,
          logContext: {'session_id': sessionId}));

  /// The authenticated user's exam history.
  Future<ExamResultsPage> fetchExamResults({
    required String sessionToken,
    int page = 1,
    int limit = 20,
  }) async =>
      ExamResultsPage.fromJson(await _json(
          'GET', _uri('/v1/exam/results', {'page': '$page', 'limit': '$limit'}),
          event: 'exam.results',
          failure: 'Fetch exam results failed',
          sessionToken: sessionToken));

  /// Public certificate (no session required).
  Future<ExamCertificate> fetchExamCertificate({
    required String certificateId,
  }) async =>
      ExamCertificate.fromJson(await _json(
          'GET', _uri('/v1/exam/certificate/$certificateId'),
          event: 'exam.certificate',
          failure: 'Fetch exam certificate failed',
          logContext: {'certificate_id': certificateId}));

  // ─── Content packs & releases ──────────────────────────────────────────────

  /// Published content packs for [language]; [afterVersion] limits the list
  /// to newer packs (incremental sync). At most [limit] (1–200) results.
  Future<List<ContentPackSummary>> listContentPacks({
    String language = 'en',
    int? afterVersion,
    int limit = 100,
    String? sessionToken,
  }) async =>
      _items(
          await _json(
              'GET',
              _uri('/v1/content-packs', {
                'language': language,
                'limit': '$limit',
                if (afterVersion != null) 'after_version': '$afterVersion',
              }),
              event: 'content_packs.list',
              failure: 'List content packs failed',
              sessionToken: sessionToken),
          ContentPackSummary.fromJson);

  /// One published content pack, or `null` when it does not exist (404).
  Future<ContentPack?> fetchContentPack({
    required String id,
    String? sessionToken,
  }) async {
    final response = await _send('GET', _uri('/v1/content-packs/$id'),
        event: 'content_pack.fetch',
        sessionToken: sessionToken,
        logContext: {'pack_id': id});
    if (response.statusCode == 404) return null;
    _throwIfFailed(response, 'Fetch content pack failed');
    return ContentPack.fromJson(
        (await _decodeJson(response)) as Map<String, dynamic>);
  }

  /// The latest release for [platform], or `null` if there is none.
  Future<ReleaseInfo?> fetchLatestRelease({
    String platform = 'android',
  }) async {
    final body = await _json(
        'GET', _uri('/v1/releases/latest', {'platform': platform}),
        event: 'releases.latest', failure: 'Fetch latest release failed');
    final release = body['release'];
    return release == null
        ? null
        : ReleaseInfo.fromJson(release as Map<String, dynamic>);
  }

  /// Downloads the release APK for [releaseId] to a temporary file, calling
  /// [onProgress] with (bytesReceived, totalBytes). Returns the file path.
  Future<String> downloadRelease(
    String releaseId, {
    void Function(int received, int total)? onProgress,
  }) async {
    final traceId = _newTraceId();
    final uri = _uri('/v1/releases/$releaseId/download');
    await _logger.info(
      category: AppLogCategory.api,
      event: 'releases.download.request',
      message: 'Downloading release APK.',
      traceId: traceId,
      context: {'release_id': releaseId},
    );
    final request = http.Request('GET', uri)
      ..headers.addAll(_signedHeaders(method: 'GET', uri: uri));
    final streamedResponse = await _httpClient.send(request).timeout(timeout);
    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      await streamedResponse.stream.drain<void>();
      throw BackendApiException(
        'Release download failed: ${streamedResponse.statusCode}',
        statusCode: streamedResponse.statusCode,
      );
    }
    final totalBytes = streamedResponse.contentLength ?? 0;
    final filePath = '${io.Directory.systemTemp.path}/release-$releaseId.apk';
    final sink = io.File(filePath).openWrite();
    var received = 0;
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
        'bytes': received
      },
    );
    return filePath;
  }

  /// Whether the backend is ready (unsigned probe; never throws).
  Future<bool> checkBackendReadiness() async {
    try {
      final response = await _send('GET', _uri('/health/ready'),
          event: 'health.ready', signed: false);
      if (_isSuccess(response.statusCode)) return true;
      await _logger.warning(
        category: AppLogCategory.api,
        event: 'health.ready.unhealthy',
        message: 'Backend readiness probe reported unhealthy.',
        context: {'status_code': response.statusCode},
      );
      return false;
    } on Object catch (error) {
      if (error is! TimeoutException) {
        await _logger.warning(
          category: AppLogCategory.api,
          event: 'health.ready.failed',
          message: 'Backend readiness probe failed.',
          context: {'error': '$error'},
        );
      }
      return false;
    }
  }

  // ─── Transport ─────────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// Sends one request. [json] is encoded as the JSON body; [rawBody] is sent
  /// as-is with caller [headers]. Logs `<event>.request`, `.response` and
  /// `.timeout` (rethrowing the timeout) under [category].
  Future<http.Response> _send(
    String method,
    Uri uri, {
    required String event,
    Object? json,
    Uint8List? rawBody,
    Map<String, String> headers = const {},
    String? sessionToken,
    bool signed = true,
    AppLogCategory category = AppLogCategory.api,
    Map<String, Object?> logContext = const {},
  }) async {
    final traceId = _newTraceId();
    final body = rawBody ??
        (json == null
            ? null
            : Uint8List.fromList(utf8.encode(jsonEncode(json))));
    final requestHeaders = {
      if (json != null) 'content-type': 'application/json',
      ...headers,
      if (signed)
        ..._signedHeaders(
            method: method, uri: uri, body: body, sessionToken: sessionToken),
    };
    await _logger.info(
      category: category,
      event: '$event.request',
      message: '$method ${uri.path}',
      traceId: traceId,
      context: {
        'uri': uri.toString(),
        'timeout_ms': timeout.inMilliseconds,
        ...logContext,
      },
    );
    final stopwatch = Stopwatch()..start();
    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(requestHeaders);
      if (body != null) request.bodyBytes = body;
      response = await http.Response.fromStream(
          await _httpClient.send(request).timeout(timeout));
    } on TimeoutException catch (error) {
      await _logger.warning(
        category: category,
        event: '$event.timeout',
        message: '$method ${uri.path} timed out.',
        traceId: traceId,
        context: {
          'uri': uri.toString(),
          'timeout_ms': timeout.inMilliseconds,
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error': '$error',
          ...logContext,
        },
      );
      rethrow;
    }
    await _logger.info(
      category: category,
      event: '$event.response',
      message: '$method ${uri.path} → ${response.statusCode}',
      traceId: traceId,
      context: {
        'status_code': response.statusCode,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      },
    );
    return response;
  }

  /// [_send] that must succeed; returns the decoded JSON object.
  Future<Map<String, dynamic>> _json(
    String method,
    Uri uri, {
    required String event,
    required String failure,
    Object? json,
    String? sessionToken,
    AppLogCategory category = AppLogCategory.api,
    Map<String, Object?> logContext = const {},
  }) async {
    final response = await _send(method, uri,
        event: event,
        json: json,
        sessionToken: sessionToken,
        category: category,
        logContext: logContext);
    _throwIfFailed(response, failure);
    return (await _decodeJson(response)) as Map<String, dynamic>;
  }

  /// [_send] that must succeed; the response body is not needed.
  Future<void> _call(
    String method,
    Uri uri, {
    required String event,
    required String failure,
    Object? json,
    Uint8List? rawBody,
    Map<String, String> headers = const {},
    String? sessionToken,
    AppLogCategory category = AppLogCategory.api,
    Map<String, Object?> logContext = const {},
  }) async {
    final response = await _send(method, uri,
        event: event,
        json: json,
        rawBody: rawBody,
        headers: headers,
        sessionToken: sessionToken,
        category: category,
        logContext: logContext);
    _throwIfFailed(response, failure);
  }

  /// The `items` array of [body], parsed with [fromJson].
  List<T> _items<T>(Map<String, dynamic> body,
          T Function(Map<String, dynamic>) fromJson) =>
      [
        for (final item in body['items'] as List? ?? const [])
          if (item is Map<String, dynamic>) fromJson(item),
      ];

  static bool _isSuccess(int status) => status >= 200 && status < 300;

  void _throwIfFailed(http.Response response, String context) {
    if (_isSuccess(response.statusCode)) return;
    String? backendError;
    String? backendReason;
    try {
      // Error bodies are tiny: decode inline (this method is synchronous).
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

  String _newTraceId() => 'api_${DateTime.now().microsecondsSinceEpoch}';

  // ─── Request signing (see contracts/api.md) ────────────────────────────────

  /// A signed WebSocket address on the backend (the party relay). Call again
  /// for every connection attempt: each signature carries a fresh nonce,
  /// which the backend accepts only once.
  ({Uri uri, Map<String, String> headers}) signedSocket(String path) {
    final httpUri = _uri(path);
    return (
      uri: httpUri.replace(scheme: httpUri.scheme == 'https' ? 'wss' : 'ws'),
      headers: _signedHeaders(method: 'GET', uri: httpUri),
    );
  }

  Map<String, String> _signedHeaders({
    required String method,
    required Uri uri,
    Uint8List? body,
    String? sessionToken,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final nonce = _newNonce();
    final contentSha256 = _hashBody(body ?? Uint8List(0));
    final signature = _signCanonicalRequest(_buildCanonicalRequest(
      method: method,
      uri: uri,
      timestamp: timestamp,
      nonce: nonce,
      contentSha256: contentSha256,
    ));
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

  String _hashBody(Uint8List rawBody) =>
      base64Url.encode(sha256.convert(rawBody).bytes).replaceAll('=', '');

  String _buildCanonicalRequest({
    required String method,
    required Uri uri,
    required String timestamp,
    required String nonce,
    required String contentSha256,
  }) {
    final sortedParams = <String>[];
    for (final key in uri.queryParametersAll.keys.toList()..sort()) {
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
    final hmacDigest = Hmac(sha256, utf8.encode(appSecret))
        .convert(utf8.encode(canonicalRequest));
    return 'v1=${base64Url.encode(hmacDigest.bytes).replaceAll('=', '')}';
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

/// Responses above this size are decoded on a background isolate.
const _backgroundDecodeBytes = 16 * 1024;

/// Decodes a JSON response. Large bodies (card batches, article lists) are
/// UTF-8 + JSON decoded on a worker isolate so the UI thread keeps rendering;
/// small ones are decoded inline because spawning an isolate costs more.
Future<Object?> _decodeJson(http.Response response) {
  final bytes = response.bodyBytes;
  if (bytes.length < _backgroundDecodeBytes) {
    return Future.value(jsonDecode(response.body));
  }
  return Isolate.run(() => jsonDecode(utf8.decode(bytes)));
}

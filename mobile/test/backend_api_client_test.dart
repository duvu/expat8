import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/models/submitted_word.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('checks backend readiness without app credentials', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'ok': true, 'db': 'ok'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final ready = await apiClient.checkBackendReadiness();

    expect(ready, isTrue);
    expect(captured.method, 'GET');
    expect(captured.url.path, '/health/ready');
    expect(captured.headers.containsKey('x-expat8-app-id'), isFalse);
    expect(captured.headers.containsKey('authorization'), isFalse);
  });

  test('requests learning cards with post body and no word exclusions',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'target_mix': {'new': 10, 'review': 0},
          'actual_mix': {'new': 0, 'review': 0},
          'items': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    await apiClient.fetchLearningCards(
      deviceId: 'anonymous_device_1',
      limit: 10,
      sessionToken: 'session_1',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/learning/cards');
    expect(captured.url.query, isEmpty);
    expect(captured.headers['authorization'], 'Bearer session_1');
    expect(body['device_id'], 'anonymous_device_1');
    expect(body['limit'], 10);
    expect(body.containsKey('exclude_server_word_id'), false);
  });

  test('uploads sanitized log archives with app credentials and metadata',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'id': 'archive_1',
          'file_name': 'expat8_logs_20260505.txt',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    const payload = '# Expat8 mobile logs\n{"message":"xin chào"}\n';

    await apiClient.uploadLogArchive(
      payload: payload,
      fileName: 'expat8_logs_20260505.txt',
      deviceId: 'device_1',
      sessionToken: 'session_1',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/mobile/log-archives');
    expect(captured.headers['content-type'], 'text/plain; charset=utf-8');
    expect(captured.headers['x-expat8-device-id'], 'device_1');
    expect(captured.headers['x-expat8-log-source'], 'mobile');
    expect(
        captured.headers['x-expat8-log-filename'], 'expat8_logs_20260505.txt');
    expect(captured.headers['authorization'], 'Bearer session_1');
    expect(captured.bodyBytes, utf8.encode(payload));
    expect(
      captured.headers['x-expat8-content-sha256'],
      base64Url
          .encode(sha256.convert(utf8.encode(payload)).bytes)
          .replaceAll('=', ''),
    );
  });

  test('surfaces log archive upload failures', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'bad_request'}),
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    await expectLater(
      apiClient.uploadLogArchive(
        payload: '# Expat8 mobile logs\n',
        fileName: 'expat8_logs_20260505.txt',
        deviceId: 'device_1',
      ),
      throwsA(
        isA<BackendApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
                (error) => error.backendError, 'backendError', 'bad_request'),
      ),
    );
  });

  test('uses distinct high-entropy app credential nonces concurrently',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'target_mix': {'new': 10, 'review': 0},
          'actual_mix': {'new': 0, 'review': 0},
          'items': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    await Future.wait([
      apiClient.fetchLearningCards(deviceId: 'device_1', limit: 10),
      apiClient.fetchLearningCards(deviceId: 'device_1', limit: 10),
    ]);

    final nonces =
        requests.map((request) => request.headers['x-expat8-nonce']).toList();
    expect(nonces.toSet().length, 2);
    expect(nonces, everyElement(isNot(matches(RegExp(r'^mobile_\d+$')))));
  });

  test('parses proficiency fetch response', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'device_id': 'device_1',
          'scale': 'cefr',
          'level': 'A2',
          'level_index': 1,
          'level_changed': false,
          'consecutive_count': 3,
          'consecutive_rating_type': 'too_easy',
          'language': 'en',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final proficiency = await apiClient.fetchProficiency(deviceId: 'device_1');

    expect(proficiency.scale, 'cefr');
    expect(proficiency.level, 'A2');
    expect(proficiency.levelIndex, 1);
    expect(proficiency.consecutiveCount, 3);
    expect(proficiency.consecutiveRatingType, 'too_easy');
  });

  test('syncs local cache inventory to backend', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'stored_count': 2,
          'unknown_server_word_ids': ['missing_word'],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final result = await apiClient.syncCacheInventory(
      deviceId: 'device_1',
      serverWordIds: const ['word_1', 'word_2', 'missing_word'],
      observedAt: DateTime.utc(2026, 5, 5),
      sessionToken: 'session_1',
    );

    expect(captured.method, 'PUT');
    expect(captured.url.path, '/v1/user-word-cache');
    expect(captured.headers['authorization'], 'Bearer session_1');
    expect(jsonDecode(captured.body)['server_word_ids'],
        const ['word_1', 'word_2', 'missing_word']);
    expect(result.storedCount, 2);
    expect(result.unknownServerWordIds, const ['missing_word']);
  });

  test('creates submitted words with signed JSON body and parses immediate ready status', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'id': 'submission_1',
          'submitted_term': 'stubborn',
          'target_language': 'en',
          'status': 'ready',
          'resolution_type': 'generated_word',
          'failure_reason': null,
          'resolved_word': {
            'server_word_id': 'word_1',
            'term': 'stubborn',
            'language': 'en',
            'meaning_vi': 'bướng bỉnh',
            'part_of_speech': 'adjective',
            'ipa': '/ˈstʌbərn/',
            'vietnamese_pronunciation': 'stuh-burn',
            'example': 'He is stubborn about changing his plan.',
            'example_vi': 'Anh ay rat buong binh ve viec doi ke hoach.',
            'difficulty': 'B1',
            'topics': ['people'],
            'created_at': '2026-05-19T00:00:00.000Z',
          },
          'created_at': '2026-05-19T00:00:00.000Z',
          'updated_at': '2026-05-19T00:00:00.000Z',
          'resolved_at': '2026-05-19T00:00:00.000Z',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final submission = await apiClient.createSubmittedWord(
      localSubmissionId: 'local_submission_1',
      deviceId: 'device_1',
      term: 'stubborn',
      targetLanguage: 'en',
      sessionToken: 'session_1',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/user-submitted-words');
    expect(captured.headers['authorization'], 'Bearer session_1');
    expect(jsonDecode(captured.body), {
      'device_id': 'device_1',
      'term': 'stubborn',
      'target_language': 'en',
    });
    expect(submission.localSubmissionId, 'local_submission_1');
    expect(submission.serverSubmissionId, 'submission_1');
    expect(submission.status, SubmittedWordStatus.ready);
    expect(submission.resolutionType, SubmittedWordResolutionType.generatedWord);
    expect(submission.resolvedWord?.serverWordId, 'word_1');
  });

  test('fetches submitted words and parses ready resolved word payload', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'submission_1',
              'submitted_term': 'reliable',
              'target_language': 'en',
              'status': 'ready',
              'resolution_type': 'existing_word',
              'failure_reason': null,
              'resolved_word': {
                'server_word_id': 'word_1',
                'term': 'reliable',
                'language': 'en',
                'meaning_vi': 'dang tin cay',
                'part_of_speech': 'adjective',
                'ipa': '/rɪˈlaɪəbl/',
                'vietnamese_pronunciation': 'ri-lai-uh-bol',
                'example': 'She is reliable.',
                'example_vi': 'Co ay dang tin cay.',
                'difficulty': 'B1',
                'topics': ['work'],
                'created_at': '2026-05-05T00:00:00.000Z'
              },
              'created_at': '2026-05-19T00:00:00.000Z',
              'updated_at': '2026-05-19T00:00:05.000Z',
              'resolved_at': '2026-05-19T00:00:05.000Z',
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final items = await apiClient.fetchSubmittedWords(
      deviceId: 'device_1',
      sessionToken: 'session_1',
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/v1/user-submitted-words');
    expect(captured.url.queryParameters['device_id'], 'device_1');
    expect(items.single.serverSubmissionId, 'submission_1');
    expect(items.single.status, SubmittedWordStatus.ready);
    expect(items.single.resolutionType, SubmittedWordResolutionType.existingWord);
    expect(items.single.resolvedWord?.serverWordId, 'word_1');
  });

  test('fetches backend-selected learning card batches with metadata',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'target_mix': {'new': 10, 'review': 0},
          'actual_mix': {'new': 1, 'review': 0},
          'items': [
            {
              'server_word_id': 'word_1',
              'term': 'reliable',
              'language': 'en',
              'meaning_vi': 'dang tin cay',
              'part_of_speech': 'adjective',
              'ipa': '/rɪˈlaɪəbl/',
              'vietnamese_pronunciation': 'ri-lai-uh-bol',
              'example': 'She is reliable.',
              'example_vi': 'Co ay dang tin cay.',
              'difficulty': 'B1',
              'topics': ['work'],
              'created_at': '2026-05-05T00:00:00.000Z',
              'card_type': 'new',
              'selection_reason': 'new_available',
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final batch = await apiClient.fetchLearningCards(
      deviceId: 'device_1',
      limit: 10,
      sessionToken: 'session_1',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(captured.url.path, '/v1/learning/cards');
    expect(body['device_id'], 'device_1');
    expect(body['limit'], 10);
    expect(batch.targetMix.newCount, 10);
    expect(batch.actualMix.newCount, 1);
    expect(batch.items.single.cardType, LearningCardType.newCard);
  });

  test(
      'registers, signs in, signs out, and attaches bearer session to learning requests',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/v1/users/register') {
        return http.Response(
          jsonEncode({
            'user_id': 'user_1',
            'identifier': 'learner@example.com',
            'display_name': 'Learner',
            'session_token': 'session_register',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/users/sign-in') {
        return http.Response(
          jsonEncode({
            'user_id': 'user_1',
            'identifier': 'learner@example.com',
            'display_name': 'Learner',
            'session_token': 'session_sign_in',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/users/sign-out') {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      if (request.url.path == '/v1/proficiency') {
        return http.Response(jsonEncode({'level': 'A1'}), 200);
      }
      return http.Response(jsonEncode({'items': []}), 200);
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final registered = await apiClient.registerUser(
      identifier: 'Learner@Example.com',
      password: 'correct-password',
      displayName: 'Learner',
      deviceId: 'device_1',
    );
    final signedIn = await apiClient.signIn(
      identifier: 'learner@example.com',
      password: 'correct-password',
      deviceId: 'device_1',
    );
    await apiClient.fetchProficiency(
      deviceId: 'device_1',
      sessionToken: signedIn.sessionToken,
    );
    await apiClient.signOut(
      session: const UserSession(
        userId: 'user_1',
        identifier: 'learner@example.com',
        displayName: 'Learner',
        sessionToken: 'session_sign_in',
      ),
    );

    expect(registered.sessionToken, 'session_register');
    expect(signedIn.sessionToken, 'session_sign_in');
    expect(requests[0].headers['x-expat8-app-id'], 'expat8-mobile-app');
    expect(requests[2].headers['authorization'], 'Bearer session_sign_in');
    expect(requests[3].headers['authorization'], 'Bearer session_sign_in');
  });

  test('surfaces duplicate-user registration metadata from backend errors',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'user_exists'}),
        409,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    try {
      await apiClient.registerUser(
        identifier: 'learner@example.com',
        password: 'correct-password',
      );
      fail('Expected registerUser to throw');
    } on BackendApiException catch (error) {
      expect(error.statusCode, 409);
      expect(error.backendError, 'user_exists');
      expect(error.message, 'Registration failed: 409');
    }
  });

  test('surfaces invalid-credentials metadata from sign-in backend errors',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': 'invalid_credentials',
          'reason': 'user_not_found',
        }),
        401,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    try {
      await apiClient.signIn(
        identifier: 'learner@example.com',
        password: 'wrong-password',
      );
      fail('Expected signIn to throw');
    } on BackendApiException catch (error) {
      expect(error.statusCode, 401);
      expect(error.backendError, 'invalid_credentials');
      expect(error.backendReason, 'user_not_found');
      expect(error.message, 'Sign-in failed: 401');
    }
  });

  test('creates, lists, fetches, and deletes managed articles', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/v1/articles' && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'id': 'article_1',
            'title': 'My article',
            'source_url': 'https://example.com/article',
            'language': 'en',
            'visibility': 'private',
            'status': 'pending_processing',
            'processing_error': null,
            'created_at': '2026-05-10T00:00:00.000Z',
            'updated_at': '2026-05-10T00:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/articles' && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'article_1',
                'title': 'My article',
                'source_url': 'https://example.com/article',
                'language': 'en',
                'visibility': 'private',
                'status': 'processed',
                'processing_error': null,
                'created_at': '2026-05-10T00:00:00.000Z',
                'updated_at': '2026-05-10T00:10:00.000Z',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/articles/article_1' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'id': 'article_1',
            'title': 'My article',
            'source_url': 'https://example.com/article',
            'language': 'en',
            'visibility': 'private',
            'status': 'processed',
            'processing_error': null,
            'created_at': '2026-05-10T00:00:00.000Z',
            'updated_at': '2026-05-10T00:10:00.000Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/articles/article_1/vocabulary' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'article_id': 'article_1',
            'items': [
              {
                'term_id': 'term_1',
                'display_term': 'reliable',
                'word_sense_id': 'sense_1',
                'meaning_vi': 'dang tin cay',
                'part_of_speech': 'adjective',
                'ipa': '/rɪˈlaɪəbl/',
                'level': 'A1',
                'status': 'approved',
                'classification': 'article_keyword',
                'suggestion_type': 'word',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/v1/articles/article_1' &&
          request.method == 'DELETE') {
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'error': 'bad_request'}),
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final created = await apiClient.createArticle(
      sessionToken: 'session_1',
      title: 'My article',
      language: 'en',
      rawText: 'some text',
      sourceUrl: 'https://example.com/article',
    );
    final articles = await apiClient.listArticles(sessionToken: 'session_1');
    final detail = await apiClient.getArticle(
      sessionToken: 'session_1',
      articleId: 'article_1',
    );
    final vocabulary = await apiClient.getArticleVocabulary(
      sessionToken: 'session_1',
      articleId: 'article_1',
    );
    await apiClient.deleteArticle(
      sessionToken: 'session_1',
      articleId: 'article_1',
    );

    expect(created.id, 'article_1');
    expect(articles.single.status, 'processed');
    expect(detail.title, 'My article');
    expect(vocabulary.items.single.displayTerm, 'reliable');
    expect(requests.first.headers['authorization'], 'Bearer session_1');
    expect(requests.last.method, 'DELETE');
  });

  test('surfaces bad-request metadata from article creation errors', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'bad_request'}),
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    try {
      await apiClient.createArticle(
        sessionToken: 'session_1',
        title: 'My article',
        language: 'en',
        rawText: 'some text',
      );
      fail('Expected createArticle to throw');
    } on BackendApiException catch (error) {
      expect(error.statusCode, 400);
      expect(error.backendError, 'bad_request');
      expect(error.message, 'Create article failed: 400');
    }
  });

  // ─── Release endpoints ──────────────────────────────────────────────────────

  test('fetchLatestRelease returns ReleaseInfo when release exists', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/releases/latest');
      expect(request.url.queryParameters['platform'], 'android');
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'release': {
            'id': 'rel-1',
            'platform': 'android',
            'version_code': 10,
            'version_name': '2.1.0',
            'file_size_bytes': 15000000,
            'sha256': 'abcdef',
            'created_at': '2026-05-19T10:00:00.000Z',
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final release = await apiClient.fetchLatestRelease(platform: 'android');

    expect(release, isNotNull);
    expect(release!.id, 'rel-1');
    expect(release.versionCode, 10);
    expect(release.versionName, '2.1.0');
    expect(release.fileSizeBytes, 15000000);
    expect(release.sha256, 'abcdef');
  });

  test('fetchLatestRelease returns null when no release exists', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'release': null}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    final release = await apiClient.fetchLatestRelease();

    expect(release, isNull);
  });

  test('fetchLatestRelease throws on server error', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'internal_error'}),
        500,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'test-app-secret',
      httpClient: client,
    );

    expect(
      () => apiClient.fetchLatestRelease(),
      throwsA(isA<BackendApiException>()),
    );
  });
}

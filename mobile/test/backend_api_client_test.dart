import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
        jsonEncode({'error': 'invalid_credentials'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
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
      expect(error.message, 'Sign-in failed: 401');
    }
  });
}

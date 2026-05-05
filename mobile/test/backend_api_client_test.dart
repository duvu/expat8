import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('includes excluded server word ids and proficiency context when requesting another new word', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(jsonEncode({'items': []}), 200, headers: {
        'content-type': 'application/json',
      });
    });

    final apiClient = BackendApiClient(
      baseUrl: 'https://expat8.x51.vn',
      timeout: const Duration(seconds: 5),
      appId: 'expat8-mobile-app',
      appSecret: 'expat8-mobile-secret',
      httpClient: client,
    );

    await apiClient.fetchNewWords(
      limit: 1,
      excludeServerWordIds: const ['word_current', 'word_previous'],
      proficiencyLevel: 'B1',
      deviceId: 'device_1',
    );

    expect(requestedUri.path, '/v1/words/next');
    expect(requestedUri.queryParameters['proficiency_level'], 'B1');
    expect(requestedUri.queryParameters['device_id'], 'device_1');
    expect(
      requestedUri.queryParametersAll['exclude_server_word_id'],
      const ['word_current', 'word_previous'],
    );
  });

  test('parses proficiency fetch response', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'device_id': 'device_1',
          'level': 'A2',
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

    expect(proficiency.level, 'A2');
    expect(proficiency.consecutiveCount, 3);
    expect(proficiency.consecutiveRatingType, 'too_easy');
  });

  test('registers, signs in, signs out, and attaches bearer session to learning requests', () async {
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

  test('surfaces duplicate-user registration metadata from backend errors', () async {
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

  test('surfaces invalid-credentials metadata from sign-in backend errors', () async {
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

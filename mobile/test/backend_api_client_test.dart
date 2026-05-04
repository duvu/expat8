import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('includes excluded server word ids when requesting another new word', () async {
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
    );

    expect(requestedUri.path, '/v1/words/next');
    expect(
      requestedUri.queryParametersAll['exclude_server_word_id'],
      const ['word_current', 'word_previous'],
    );
  });
}
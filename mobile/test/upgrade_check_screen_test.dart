import 'dart:convert';

import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/ui/upgrade_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BackendApiClient _buildApiClient(MockClient mockClient) {
    return BackendApiClient(
      baseUrl: 'https://example.com',
      timeout: const Duration(seconds: 10),
      appId: 'test-app',
      appSecret: 'test-secret',
      httpClient: mockClient,
    );
  }

  testWidgets('shows update available when backend returns newer version',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/releases/latest') {
        return http.Response(
          jsonEncode({
            'release': {
              'id': 'release-1',
              'platform': 'android',
              'version_code': 99,
              'version_name': '2.0.0',
              'file_size_bytes': 15728640,
              'sha256': 'abc123',
              'created_at': '2026-05-19T12:00:00.000Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeCheckScreen(apiClient: _buildApiClient(client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('2.0.0'), findsOneWidget);
    expect(find.text('Download & Install'), findsOneWidget);
  });

  testWidgets('shows up to date when backend returns same or lower version',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/releases/latest') {
        return http.Response(
          jsonEncode({
            'release': {
              'id': 'release-1',
              'platform': 'android',
              'version_code': 1, // same as kAppVersionCode default
              'version_name': '1.0.0',
              'file_size_bytes': 10000000,
              'sha256': 'abc123',
              'created_at': '2026-05-19T12:00:00.000Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeCheckScreen(apiClient: _buildApiClient(client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App is up to date'), findsOneWidget);
    expect(find.text('Download & Install'), findsNothing);
  });

  testWidgets('shows up to date when backend returns null release',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/releases/latest') {
        return http.Response(
          jsonEncode({'release': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeCheckScreen(apiClient: _buildApiClient(client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App is up to date'), findsOneWidget);
  });

  testWidgets('shows error and retry when backend request fails',
      (tester) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'internal_error'}),
        500,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeCheckScreen(apiClient: _buildApiClient(client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not check for updates'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry button re-fetches latest release', (tester) async {
    int callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      if (callCount == 1) {
        return http.Response('', 500);
      }
      return http.Response(
        jsonEncode({
          'release': {
            'id': 'release-2',
            'platform': 'android',
            'version_code': 50,
            'version_name': '3.0.0',
            'file_size_bytes': 20000000,
            'sha256': 'def456',
            'created_at': '2026-05-19T12:00:00.000Z',
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UpgradeCheckScreen(apiClient: _buildApiClient(client)),
      ),
    );
    await tester.pumpAndSettle();

    // Should show error first
    expect(find.text('Retry'), findsOneWidget);

    // Tap retry
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Should now show update available
    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('3.0.0'), findsOneWidget);
  });
}

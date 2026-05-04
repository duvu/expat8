import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/study_event.dart';
import '../models/vocabulary_word.dart';

class BackendApiClient {
  BackendApiClient({
    required this.baseUrl,
    required this.timeout,
    required this.appId,
    required this.appSecret,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final String appId;
  final String appSecret;
  final http.Client _httpClient;

  Future<List<VocabularyWord>> fetchNewWords({
    int limit = 1,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
    List<String> excludeServerWordIds = const [],
  }) async {
    final queryEntries = <MapEntry<String, String>>[
      MapEntry('mode', 'new'),
      MapEntry('limit', '$limit'),
      MapEntry('source_language', sourceLanguage),
      MapEntry('target_language', targetLanguage),
      ...excludeServerWordIds.map(
        (serverWordId) => MapEntry('exclude_server_word_id', serverWordId),
      ),
    ];
    final query = queryEntries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final uri = Uri.parse('$baseUrl/v1/words/next').replace(query: query);
    final response = await _httpClient
      .get(uri, headers: _signedHeaders(method: 'GET', uri: uri))
      .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException('New-word feed failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List? ?? const [];
    return items
        .map((item) => VocabularyWord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VocabularyWord>> fetchRecentWords({
    int limit = 1000,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
  }) async {
    final uri = Uri.parse('$baseUrl/v1/words/recent').replace(queryParameters: {
      'limit': '$limit',
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
    });
    final response = await _httpClient
      .get(uri, headers: _signedHeaders(method: 'GET', uri: uri))
      .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException('Recent words failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List? ?? const [];
    return items
        .map((item) => VocabularyWord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SyncResult> syncStudyEvents({
    required String deviceId,
    required List<Map<String, dynamic>> events,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/study-events/sync');
    final payload = jsonEncode({'device_id': deviceId, 'events': events});
    final response = await _httpClient
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException('Study-event sync failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SyncResult(
      acceptedEventIds: List<String>.from(
        body['accepted_event_ids'] as List? ?? const [],
      ),
      rejectedEvents: List<Map<String, dynamic>>.from(
        body['rejected_events'] as List? ?? const [],
      ),
    );
  }
}

extension on BackendApiClient {
  Map<String, String> _signedHeaders({
    required String method,
    required Uri uri,
    Uint8List? body,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final nonce = 'mobile_${DateTime.now().microsecondsSinceEpoch}';
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
    };
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
      final values = [...(uri.queryParametersAll[key] ?? const <String>[])]..sort();
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
  });

  final List<String> acceptedEventIds;
  final List<Map<String, dynamic>> rejectedEvents;
}

class BackendApiException implements Exception {
  BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_event.dart';
import '../models/vocabulary_word.dart';

class BackendApiClient {
  BackendApiClient({
    required this.baseUrl,
    required this.timeout,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _httpClient;

  Future<List<VocabularyWord>> fetchNewWords({
    int limit = 1,
    String sourceLanguage = 'vi',
    String targetLanguage = 'en',
  }) async {
    final uri = Uri.parse('$baseUrl/v1/words/next').replace(queryParameters: {
      'mode': 'new',
      'limit': '$limit',
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
    });
    final response = await _httpClient.get(uri).timeout(timeout);
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
    final response = await _httpClient.get(uri).timeout(timeout);
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
    final response = await _httpClient
        .post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'device_id': deviceId, 'events': events}),
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

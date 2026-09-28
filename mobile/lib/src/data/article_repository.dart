import 'dart:convert';

import '../api/backend_api_client.dart';
import '../models/article.dart';
import 'local_database.dart';
import 'memorization_repository.dart' show CachedResult;

/// Articles are processed on the server, so creating one needs a connection.
/// Reading is offline-first: every list, article and vocabulary response is
/// cached per user and served from the cache when the backend is unreachable.
class ArticleRepository {
  ArticleRepository({required this.apiClient, this.localDb});

  final BackendApiClient apiClient;
  final LocalDatabase? localDb;

  static const _listKey = 'articles.cache.list';
  static String _articleKey(String id) => 'articles.cache.article.$id';
  static String _vocabularyKey(String id) => 'articles.cache.vocabulary.$id';

  /// Scopes cache keys to the signed-in account so accounts never see each
  /// other's articles on a shared device.
  Future<String> _scoped(String key) async {
    final session = await localDb?.loadUserSession();
    return '$key.${session?.userId ?? 'anonymous'}';
  }

  Future<List<ManagedArticle>> listArticles({required String sessionToken}) async =>
      (await loadArticles(sessionToken: sessionToken)).data;

  Future<CachedResult<List<ManagedArticle>>> loadArticles({
    required String sessionToken,
  }) async {
    try {
      final articles = await apiClient.listArticles(sessionToken: sessionToken);
      await _write(_listKey, [for (final a in articles) a.toJson()]);
      return CachedResult(articles, fromCache: false);
    } on Object {
      final cached = await _read(_listKey);
      if (cached is! List) rethrow;
      return CachedResult(
        [
          for (final a in cached.whereType<Map<String, dynamic>>())
            ManagedArticle.fromJson(a),
        ],
        fromCache: true,
      );
    }
  }

  Future<ManagedArticle> createArticle({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
    String? sourceUrl,
  }) {
    return apiClient.createArticle(
      sessionToken: sessionToken,
      title: title,
      language: language,
      rawText: rawText,
      sourceUrl: sourceUrl,
    );
  }

  Future<ManagedArticle> getArticle({
    required String sessionToken,
    required String articleId,
  }) async {
    try {
      final article = await apiClient.getArticle(
        sessionToken: sessionToken,
        articleId: articleId,
      );
      await _write(_articleKey(articleId), article.toJson());
      return article;
    } on Object {
      final cached = await _read(_articleKey(articleId));
      if (cached is Map<String, dynamic>) return ManagedArticle.fromJson(cached);
      final list = await _read(_listKey);
      if (list is List) {
        for (final a in list.whereType<Map<String, dynamic>>()) {
          if (a['id'] == articleId) return ManagedArticle.fromJson(a);
        }
      }
      rethrow;
    }
  }

  Future<ArticleVocabularyResponse> getArticleVocabulary({
    required String sessionToken,
    required String articleId,
  }) async {
    try {
      final vocabulary = await apiClient.getArticleVocabulary(
        sessionToken: sessionToken,
        articleId: articleId,
      );
      await _write(_vocabularyKey(articleId), vocabulary.toJson());
      return vocabulary;
    } on Object {
      final cached = await _read(_vocabularyKey(articleId));
      if (cached is Map<String, dynamic>) {
        return ArticleVocabularyResponse.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<void> deleteArticle({
    required String sessionToken,
    required String articleId,
  }) async {
    await apiClient.deleteArticle(
      sessionToken: sessionToken,
      articleId: articleId,
    );
    await localDb?.setSetting(await _scoped(_articleKey(articleId)), '');
    await localDb?.setSetting(await _scoped(_vocabularyKey(articleId)), '');
  }

  Future<void> _write(String key, Object value) async {
    await localDb?.setSetting(await _scoped(key), jsonEncode(value));
  }

  Future<Object?> _read(String key) async {
    final raw = await localDb?.getSetting(await _scoped(key));
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

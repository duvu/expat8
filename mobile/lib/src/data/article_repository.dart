import '../api/backend_api_client.dart';
import '../models/article.dart';

class ArticleRepository {
  ArticleRepository({required this.apiClient});

  final BackendApiClient apiClient;

  Future<List<ManagedArticle>> listArticles({required String sessionToken}) {
    return apiClient.listArticles(sessionToken: sessionToken);
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
  }) {
    return apiClient.getArticle(
      sessionToken: sessionToken,
      articleId: articleId,
    );
  }

  Future<ArticleVocabularyResponse> getArticleVocabulary({
    required String sessionToken,
    required String articleId,
  }) {
    return apiClient.getArticleVocabulary(
      sessionToken: sessionToken,
      articleId: articleId,
    );
  }

  Future<void> deleteArticle({
    required String sessionToken,
    required String articleId,
  }) {
    return apiClient.deleteArticle(
      sessionToken: sessionToken,
      articleId: articleId,
    );
  }
}

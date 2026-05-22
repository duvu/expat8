import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/article_repository.dart';
import 'package:expat8_language_app/src/models/article.dart';
import 'package:expat8_language_app/src/ui/articles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows articles and opens detail flow', (tester) async {
    final repository = _FakeArticleRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleManagementScreen(
          repository: repository,
          sessionToken: 'session_1',
          initialLanguage: 'en',
          supportedLanguages: const ['en', 'zh', 'vi'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My article'), findsOneWidget);
    expect(find.textContaining('processed'), findsOneWidget);
    await tester.tap(find.text('My article'));
    await tester.pumpAndSettle();

    expect(find.text('Article detail'), findsOneWidget);
    expect(find.text('reliable'), findsOneWidget);
  });

  testWidgets('create article returns to list and refreshes', (tester) async {
    final repository = _FakeArticleRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleManagementScreen(
          repository: repository,
          sessionToken: 'session_1',
          initialLanguage: 'en',
          supportedLanguages: const ['en', 'zh', 'vi'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('article_create_title')),
      'New article',
    );
    await tester.enterText(
      find.byKey(const Key('article_create_raw_text')),
      'hello world',
    );
    await tester.ensureVisible(find.byKey(const Key('article_create_submit')));
    await tester.tap(find.byKey(const Key('article_create_submit')));
    await tester.pumpAndSettle();

    expect(find.text('New article'), findsOneWidget);
  });

  testWidgets('deletes article after confirmation and shows success feedback',
      (tester) async {
    final repository = _FakeArticleRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleManagementScreen(
          repository: repository,
          sessionToken: 'session_1',
          initialLanguage: 'en',
          supportedLanguages: const ['en', 'zh', 'vi'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My article'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete article'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Article deleted.'), findsOneWidget);
    expect(find.text('My article'), findsNothing);
  });

  testWidgets('hides delete affordance when article lookup fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleDetailScreen(
          repository: _MissingArticleRepository(),
          sessionToken: 'session_1',
          articleId: 'missing_article',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete article'), findsNothing);
    expect(find.byType(IconButton), findsOneWidget);
  });
}

class _FakeArticleRepository extends ArticleRepository {
  _FakeArticleRepository()
      : super(
          apiClient: BackendApiClient(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'test-app',
            appSecret: 'test-secret',
          ),
        );

  final List<ManagedArticle> _articles = [
    ManagedArticle(
      id: 'article_1',
      title: 'My article',
      sourceUrl: 'https://example.com',
      language: 'en',
      visibility: 'private',
      status: 'processed',
      createdAt: DateTime.utc(2026, 5, 10),
      updatedAt: DateTime.utc(2026, 5, 10),
    ),
  ];

  @override
  Future<List<ManagedArticle>> listArticles({required String sessionToken}) async {
    return _articles;
  }

  @override
  Future<ManagedArticle> createArticle({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
    String? sourceUrl,
  }) async {
    final article = ManagedArticle(
      id: 'article_new',
      title: title,
      sourceUrl: sourceUrl,
      language: language,
      visibility: 'private',
      status: 'pending_processing',
      createdAt: DateTime.utc(2026, 5, 10),
      updatedAt: DateTime.utc(2026, 5, 10),
    );
    _articles.insert(0, article);
    return article;
  }

  @override
  Future<ManagedArticle> getArticle({
    required String sessionToken,
    required String articleId,
  }) async {
    return _articles.firstWhere((article) => article.id == articleId);
  }

  @override
  Future<ArticleVocabularyResponse> getArticleVocabulary({
    required String sessionToken,
    required String articleId,
  }) async {
    return ArticleVocabularyResponse(
      articleId: articleId,
      items: const [
        ArticleVocabularyItem(
          termId: 'term_1',
          displayTerm: 'reliable',
          wordSenseId: 'sense_1',
          meaningVi: 'dang tin cay',
          partOfSpeech: 'adjective',
          ipa: '/rɪˈlaɪəbl/',
          level: 'A1',
          status: 'approved',
          classification: 'article_keyword',
          suggestionType: 'word',
        ),
      ],
    );
  }

  @override
  Future<void> deleteArticle({
    required String sessionToken,
    required String articleId,
  }) async {
    _articles.removeWhere((article) => article.id == articleId);
  }
}

class _MissingArticleRepository extends ArticleRepository {
  _MissingArticleRepository()
      : super(
          apiClient: BackendApiClient(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'test-app',
            appSecret: 'test-secret',
          ),
        );

  @override
  Future<ManagedArticle> getArticle({
    required String sessionToken,
    required String articleId,
  }) async {
    throw BackendApiException(
      'Fetch article failed: 404',
      statusCode: 404,
      backendError: 'not_found',
    );
  }

  @override
  Future<ArticleVocabularyResponse> getArticleVocabulary({
    required String sessionToken,
    required String articleId,
  }) async {
    return ArticleVocabularyResponse(articleId: articleId, items: const []);
  }

  @override
  Future<List<ManagedArticle>> listArticles({required String sessionToken}) async {
    return const [];
  }

  @override
  Future<ManagedArticle> createArticle({
    required String sessionToken,
    required String title,
    required String language,
    required String rawText,
    String? sourceUrl,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteArticle({
    required String sessionToken,
    required String articleId,
  }) {
    throw UnimplementedError();
  }
}

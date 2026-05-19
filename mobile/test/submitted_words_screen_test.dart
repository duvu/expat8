import 'package:expat8_language_app/src/api/backend_api_client.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/data/word_repository.dart';
import 'package:expat8_language_app/src/models/submitted_word.dart';
import 'package:expat8_language_app/src/ui/submitted_words_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders failed submitted word status and failure reason',
      (tester) async {
    final repository = await _buildRepository([
      SubmittedWord(
        localSubmissionId: 'local_submission_1',
        serverSubmissionId: 'submission_1',
        submittedTerm: 'stubborn',
        targetLanguage: 'en',
        status: SubmittedWordStatus.failed,
        failureReason: 'Unable to generate a valid vocabulary item for this term.',
        createdAt: DateTime.utc(2026, 5, 19),
        updatedAt: DateTime.utc(2026, 5, 19),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SubmittedWordsScreen(
          repository: repository,
          initialLanguage: 'en',
          supportedLanguages: const ['en', 'zh', 'vi'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('stubborn'), findsOneWidget);
    expect(find.textContaining('Failed'), findsOneWidget);
    expect(
      find.textContaining('Unable to generate a valid vocabulary item'),
      findsOneWidget,
    );
  });

  testWidgets('renders immediate success copy for existing ready word',
      (tester) async {
    final repository = await _buildRepository([
      SubmittedWord(
        localSubmissionId: 'local_submission_2',
        serverSubmissionId: 'submission_2',
        submittedTerm: 'reliable',
        targetLanguage: 'en',
        status: SubmittedWordStatus.ready,
        resolutionType: SubmittedWordResolutionType.existingWord,
        createdAt: DateTime.utc(2026, 5, 19),
        updatedAt: DateTime.utc(2026, 5, 19),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SubmittedWordsScreen(
          repository: repository,
          initialLanguage: 'en',
          supportedLanguages: const ['en', 'zh', 'vi'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Added (already existed)'), findsOneWidget);
  });
}

Future<_FakeSubmittedWordRepository> _buildRepository(
  List<SubmittedWord> items,
) async {
  final database = await LocalDatabase.open(
    databaseName:
        'submitted_words_screen_test_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return _FakeSubmittedWordRepository(database: database, items: items);
}

class _FakeSubmittedWordRepository extends WordRepository {
  _FakeSubmittedWordRepository({
    required super.database,
    required this.items,
  }) : super(
          apiClient: BackendApiClient(
            baseUrl: 'http://unused',
            timeout: Duration.zero,
            appId: 'test-app',
            appSecret: 'test-secret',
          ),
        );

  List<SubmittedWord> items;

  @override
  Future<List<SubmittedWord>> refreshSubmittedWords() async => items;

  @override
  Future<List<SubmittedWord>> loadSubmittedWords() async => items;
}

import 'package:expat8_language_app/src/data/seed_vocabulary_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns empty list when asset is missing', () async {
    const loader = SeedVocabularyLoader(
      bundleReader: _StubBundleReader(<String, String>{}),
    );

    final words = await loader.loadForLanguage('en');

    expect(words, isEmpty);
  });

  test('returns empty list when asset is malformed JSON', () async {
    const loader = SeedVocabularyLoader(
      bundleReader: _StubBundleReader(<String, String>{
        'assets/seed_vocab/en.json': 'not json',
      }),
    );

    final words = await loader.loadForLanguage('en');

    expect(words, isEmpty);
  });

  test('parses bundled vocabulary entries', () async {
    const loader = SeedVocabularyLoader(
      bundleReader: _StubBundleReader(<String, String>{
        'assets/seed_vocab/zh.json': '''[
          {
            "server_word_id": "seed_zh_test",
            "term": "测试",
            "language": "zh",
            "meaning_vi": "kiểm tra",
            "part_of_speech": "noun",
            "ipa": "",
            "vietnamese_pronunciation": "cèshì",
            "example": "这是一个测试。",
            "example_vi": "Đây là một bài kiểm tra.",
            "difficulty": "HSK1",
            "topics": ["sample"],
            "created_at": "2026-05-08T00:00:00.000Z"
          }
        ]''',
      }),
    );

    final words = await loader.loadForLanguage('zh');

    expect(words, hasLength(1));
    expect(words.single.term, '测试');
    expect(words.single.language, 'zh');
    expect(words.single.serverWordId, 'seed_zh_test');
  });

  test('loads bundled English seed asset for the running app', () async {
    const loader = SeedVocabularyLoader();

    final words = await loader.loadForLanguage('en');

    expect(words, hasLength(100),
        reason: 'mobile/assets/seed_vocab/en.json should bundle 100 entries');
    expect(words.every((word) => word.language == 'en'), isTrue);
    expect(words.map((word) => word.serverWordId).toSet(), hasLength(100));
    expect(words.map((word) => word.term).toSet(), hasLength(100));
  });

  test('loads bundled Chinese seed asset for the running app', () async {
    const loader = SeedVocabularyLoader();

    final words = await loader.loadForLanguage('zh');

    expect(words, isNotEmpty,
        reason: 'mobile/assets/seed_vocab/zh.json should bundle entries');
    expect(words.every((word) => word.language == 'zh'), isTrue);
  });
}

class _StubBundleReader extends AssetBundleReader {
  const _StubBundleReader(this._assets);

  final Map<String, String> _assets;

  @override
  Future<String?> loadString(String path) async => _assets[path];
}

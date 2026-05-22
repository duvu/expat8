import 'package:expat8_language_app/src/data/workplace_sentence_seed_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns empty list when workplace sentence asset is missing', () async {
    const loader = WorkplaceSentenceSeedLoader(
      bundleReader: _StubBundleReader(<String, String>{}),
    );

    final sentences = await loader.loadForLanguage('en');

    expect(sentences, isEmpty);
  });

  test('parses bundled workplace sentence entries', () async {
    const loader = WorkplaceSentenceSeedLoader(
      bundleReader: _StubBundleReader(<String, String>{
        'assets/seed_workplace_sentences/en.json': '''[
          {
            "sentence_id": "seed_sentence_1",
            "text": "Please review the latest draft.",
            "language": "en",
            "meaning_vi": "Hay xem ban nhap moi nhat.",
            "topic": "documents",
            "source_title": "Starter",
            "generation_source": "bundled_workplace_sentences",
            "is_bundled": true,
            "created_at": "2026-05-16T00:00:00.000Z"
          }
        ]''',
      }),
    );

    final sentences = await loader.loadForLanguage('en');

    expect(sentences, hasLength(1));
    expect(sentences.single.serverSentenceId, 'seed_sentence_1');
    expect(sentences.single.topic, 'documents');
    expect(sentences.single.isBundled, true);
  });

  test('loads bundled English workplace sentence asset for the running app',
      () async {
    const loader = WorkplaceSentenceSeedLoader();

    final sentences = await loader.loadForLanguage('en');

    expect(sentences, hasLength(200));
    expect(sentences.every((sentence) => sentence.language == 'en'), isTrue);
    expect(
      sentences.map((sentence) => sentence.serverSentenceId).toSet(),
      hasLength(sentences.length),
    );
    expect(
      sentences.map((sentence) => sentence.text).toSet(),
      hasLength(sentences.length),
    );
  });
}

class _StubBundleReader extends AssetBundleReader {
  const _StubBundleReader(this._assets);

  final Map<String, String> _assets;

  @override
  Future<String?> loadString(String path) async => _assets[path];
}

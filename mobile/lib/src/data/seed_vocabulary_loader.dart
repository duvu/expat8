import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/vocabulary_word.dart';

/// Loads bundled vocabulary seed packaged under `assets/seed_vocab/`.
///
/// Each supported language has its own JSON file containing an array of
/// vocabulary entries that can be deserialized via [VocabularyWord.fromJson].
/// The loader returns an empty list when the asset is missing or malformed —
/// callers can then fall back to a backend top-up.
class SeedVocabularyLoader {
  const SeedVocabularyLoader({AssetBundleReader? bundleReader})
      : _bundleReader = bundleReader ?? const _RootBundleReader();

  final AssetBundleReader _bundleReader;

  static String assetPathFor(String language) =>
      'assets/seed_vocab/$language.json';

  Future<List<VocabularyWord>> loadForLanguage(String language) async {
    final raw = await _bundleReader.loadString(assetPathFor(language));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(VocabularyWord.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

/// Indirection over [rootBundle] so tests can inject in-memory fixtures.
abstract class AssetBundleReader {
  const AssetBundleReader();

  Future<String?> loadString(String path);
}

class _RootBundleReader extends AssetBundleReader {
  const _RootBundleReader();

  @override
  Future<String?> loadString(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      return null;
    }
  }
}

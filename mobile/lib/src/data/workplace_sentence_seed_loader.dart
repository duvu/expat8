import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/workplace_sentence.dart';

class WorkplaceSentenceSeedLoader {
  const WorkplaceSentenceSeedLoader({AssetBundleReader? bundleReader})
      : _bundleReader = bundleReader ?? const _RootBundleReader();

  final AssetBundleReader _bundleReader;

  static String assetPathFor(String language) =>
      'assets/seed_workplace_sentences/$language.json';

  Future<List<WorkplaceSentence>> loadForLanguage(String language) async {
    final raw = await _bundleReader.loadString(assetPathFor(language));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WorkplaceSentence.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

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

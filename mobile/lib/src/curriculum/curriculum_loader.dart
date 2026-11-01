import 'package:flutter/services.dart' show rootBundle;

import 'curriculum.dart';

/// Loads the bundled curriculum of a subject once and keeps it.
class CurriculumLoader {
  CurriculumLoader({Future<String> Function(String path)? readAsset})
      : _readAsset = readAsset ?? rootBundle.loadString;

  final Future<String> Function(String path) _readAsset;
  final Map<String, Future<Curriculum>> _cache = {};

  static String assetPathFor(String subject) =>
      'assets/curriculum/$subject.json';

  Future<Curriculum> load(String subject) => _cache.putIfAbsent(subject,
      () async => Curriculum.parse(await _readAsset(assetPathFor(subject))));
}

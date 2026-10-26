import 'dart:math';

import 'package:expat8_language_app/src/models/study_level.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyWord _word(String id, String difficulty, DateTime createdAt) {
  return VocabularyWord(
    localId: id,
    serverWordId: id,
    term: id,
    language: 'en',
    meaningVi: 'meaning',
    partOfSpeech: 'noun',
    ipa: '/x/',
    vietnamesePronunciation: 'x',
    example: 'x',
    exampleVi: 'x',
    difficulty: difficulty,
    topics: const [],
    status: WordStatus.newWord,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  test('normalizes labels per scale', () {
    expect(normalizeStudyLevel('b1', 'cefr'), 'B1');
    expect(normalizeStudyLevel('intermediate', 'cefr'), 'B1');
    expect(normalizeStudyLevel('3', 'hsk'), 'HSK3');
    expect(normalizeStudyLevel('HSK2', 'hsk'), 'HSK2');
    expect(normalizeStudyLevel('B1', 'hsk'), isNull);
    expect(normalizeStudyLevel(null, 'cefr'), isNull);
  });

  test('offers the right options per scale', () {
    expect(studyLevelsForScale('cefr'), ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
    expect(studyLevelsForScale('hsk').first, 'HSK1');
  });

  test('picks the same level first, newest first', () {
    final picked = pickWordNearLevel([
      _word('old_b1', 'B1', DateTime.utc(2026, 1, 1)),
      _word('new_b1', 'B1', DateTime.utc(2026, 3, 1)),
      _word('a1', 'A1', DateTime.utc(2026, 5, 1)),
    ], level: 'B1', scale: 'cefr');
    expect(picked?.localId, 'new_b1');
  });

  test('falls back to the nearest level, preferring the higher one on ties',
      () {
    final picked = pickWordNearLevel([
      _word('a2', 'A2', DateTime.utc(2026, 5, 1)),
      _word('b2', 'B2', DateTime.utc(2026, 1, 1)),
      _word('a1', 'A1', DateTime.utc(2026, 5, 1)),
    ], level: 'B1', scale: 'cefr');
    expect(picked?.localId, 'b2');
  });

  test('words with unknown levels rank last', () {
    final picked = pickWordNearLevel([
      _word('mystery', 'wizard', DateTime.utc(2026, 5, 1)),
      _word('c2', 'C2', DateTime.utc(2026, 1, 1)),
    ], level: 'A1', scale: 'cefr');
    expect(picked?.localId, 'c2');
  });

  test(
      'with a random source about 80% come from the level and 20% from lower levels',
      () {
    final words = [
      for (var i = 0; i < 20; i++)
        _word('b1_$i', 'B1', DateTime.utc(2026, 1, 1)),
      for (var i = 0; i < 20; i++)
        _word('a1_$i', 'A1', DateTime.utc(2026, 1, 1)),
      for (var i = 0; i < 20; i++)
        _word('a2_$i', 'A2', DateTime.utc(2026, 1, 1)),
      for (var i = 0; i < 20; i++)
        _word('b2_$i', 'B2', DateTime.utc(2026, 1, 1)),
    ];
    final random = Random(42);
    final counts = <String, int>{};
    for (var i = 0; i < 2000; i++) {
      final picked = pickWordNearLevel(words,
          level: 'B1', scale: 'cefr', random: random, lowerShare: 0.2)!;
      counts[picked.difficulty] = (counts[picked.difficulty] ?? 0) + 1;
    }
    expect(counts['B1']!, inInclusiveRange(1500, 1700));
    expect(counts['A1']! + counts['A2']!, inInclusiveRange(300, 500));
    expect(counts['A1']!, greaterThan(100));
    expect(counts['A2']!, greaterThan(100));
    expect(counts.containsKey('B2'), isFalse);
  });

  test(
      'lowerShare 0 keeps a chosen level pure, and the lowest level has nothing below',
      () {
    final words = [
      _word('b1', 'B1', DateTime.utc(2026, 1, 1)),
      _word('a1', 'A1', DateTime.utc(2026, 1, 1)),
    ];
    final random = Random(1);
    for (var i = 0; i < 50; i++) {
      expect(
          pickWordNearLevel(words, level: 'B1', scale: 'cefr', random: random)
              ?.localId,
          'b1');
      expect(
          pickWordNearLevel(words,
                  level: 'A1', scale: 'cefr', random: random, lowerShare: 0.2)
              ?.localId,
          'a1');
    }
  });

  test('random pick falls back to the nearest level when the level is empty',
      () {
    final picked = pickWordNearLevel([
      _word('a1', 'A1', DateTime.utc(2026, 1, 1)),
      _word('c2', 'C2', DateTime.utc(2026, 1, 1)),
    ], level: 'B2', scale: 'cefr', random: Random(3));
    expect(picked, isNotNull);
  });
}

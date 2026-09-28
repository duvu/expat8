import 'dart:math';

import 'package:expat8_language_app/src/games/word_blaster/question_generator.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_blaster_mode.dart';
import 'package:expat8_language_app/src/games/word_blaster/word_pool.dart';
import 'package:expat8_language_app/src/models/vocabulary_word.dart';
import 'package:flutter_test/flutter_test.dart';

import 'word_blaster_fixtures.dart';

final now = DateTime.utc(2026, 9, 28, 12);

WordPool poolOf(List<VocabularyWord> words, {int seed = 1}) => (buildWordPool(
        words: words,
        learnerLevelIndex: 1,
        now: now,
        random: Random(seed)) as WordPoolReady)
    .pool;

void main() {
  group('word pool', () {
    test('needs at least 12 usable words', () {
      final result = buildWordPool(
        words: sampleVocabulary().take(11).toList(),
        learnerLevelIndex: 0,
        now: now,
        random: Random(1),
      );
      expect(result, isA<WordPoolInsufficient>());
      expect((result as WordPoolInsufficient).available, 11);
    });

    test('prioritises due reviews, then recent, then new words', () {
      final due = [
        for (var i = 0; i < 30; i++)
          vocab('due$i', 'nghĩa hạn $i',
              status: WordStatus.review,
              nextReviewAt: now.subtract(const Duration(hours: 1))),
      ];
      final recent = [
        for (var i = 0; i < 30; i++)
          vocab('recent$i', 'nghĩa gần $i',
              status: WordStatus.learning,
              nextReviewAt: now.add(const Duration(days: 2))),
      ];
      final fresh = [
        for (var i = 0; i < 30; i++) vocab('new$i', 'nghĩa mới $i')
      ];
      final tooHard = [
        for (var i = 0; i < 30; i++) vocab('c2word$i', 'khó $i', level: 'C2'),
      ];

      final pool = poolOf([...due, ...recent, ...fresh, ...tooHard]);
      final terms = pool.roundWords.map((w) => w.term).toList();
      expect(terms, hasLength(40));
      expect(terms.where((t) => t.startsWith('due')).length, 20);
      expect(terms.where((t) => t.startsWith('recent')).length, 12);
      expect(terms.where((t) => t.startsWith('new')).length, 8);
      expect(terms.where((t) => t.startsWith('c2word')), isEmpty);
    });

    test('back-fills when a category is missing', () {
      final pool = poolOf(sampleVocabulary()); // all new words
      expect(pool.roundWords, hasLength(30));
    });

    test('maps CEFR and HSK labels to level indexes', () {
      expect(levelIndexOf('A1'), 0);
      expect(levelIndexOf('b2'), 3);
      expect(levelIndexOf('HSK3'), 2);
      expect(levelIndexOf('unknown'), 0);
    });
  });

  group('question generator', () {
    test('classic: meaning prompt, English options, exactly one correct', () {
      final generator = QuestionGenerator(
        pool: poolOf(sampleVocabulary()),
        mode: WordBlasterMode.classic,
        random: Random(3),
      );
      for (var i = 0; i < 50; i++) {
        final q = generator.next(distractors: 3);
        expect(q.options, hasLength(4));
        expect(q.options.toSet(), hasLength(4));
        expect(q.answer, q.word.term);
        expect(q.prompt, q.word.meaningVi);
      }
    });

    test('reverse uses meanings as answers', () {
      final q = QuestionGenerator(
        pool: poolOf(sampleVocabulary()),
        mode: WordBlasterMode.reverse,
        random: Random(4),
      ).next(distractors: 2);
      expect(q.prompt, q.word.term);
      expect(q.answer, q.word.meaningVi);
      expect(q.promptHint, q.word.ipa);
    });

    test('listening has audio and no visible prompt', () {
      final q = QuestionGenerator(
        pool: poolOf(sampleVocabulary()),
        mode: WordBlasterMode.listening,
        random: Random(5),
      ).next(distractors: 2);
      expect(q.prompt, isEmpty);
      expect(q.audioText, q.word.term);
    });

    test('fill the gap blanks the target in the example', () {
      final q = QuestionGenerator(
        pool: poolOf(sampleVocabulary()),
        mode: WordBlasterMode.fillGap,
        random: Random(6),
      ).next(distractors: 2);
      expect(q.prompt, contains('____'));
      expect(q.prompt.toLowerCase(), isNot(contains(q.word.term)));
    });

    test('is deterministic for the same seed', () {
      List<String> run() {
        final g = QuestionGenerator(
          pool: poolOf(sampleVocabulary(), seed: 9),
          mode: WordBlasterMode.classic,
          random: Random(9),
        );
        return [
          for (var i = 0; i < 20; i++) g.next(distractors: 3).options.join('|')
        ];
      }

      expect(run(), run());
    });

    test('distractors never share the meaning of the answer', () {
      final answer = vocab('reliable', 'đáng tin cậy', pos: 'adjective');
      final synonym = vocab('trustworthy', 'Đáng tin cậy', pos: 'adjective');
      final partial = vocab('trust', 'tin cậy', pos: 'noun');
      final picks = pickDistractors(
        word: answer,
        candidates: [answer, synonym, partial, ...sampleVocabulary()],
        count: 4,
        random: Random(1),
      );
      final terms = picks.map((w) => w.term);
      expect(terms, isNot(contains('trustworthy')));
      expect(terms, isNot(contains('trust')));
      expect(terms, isNot(contains('reliable')));
      expect(picks, hasLength(4));
    });

    test('prefers same part of speech', () {
      final answer = vocab('curious', 'tò mò', pos: 'adjective');
      final picks = pickDistractors(
        word: answer,
        candidates: sampleVocabulary(),
        count: 3,
        random: Random(2),
      );
      expect(picks.every((w) => w.partOfSpeech == 'adjective'), isTrue);
    });

    test('distractor count grows with waves', () {
      expect(QuestionGenerator.distractorsForWave(1), 2);
      expect(QuestionGenerator.distractorsForWave(4), 3);
      expect(QuestionGenerator.distractorsForWave(9), 4);
    });

    test('generation is fast', () {
      final generator = QuestionGenerator(
        pool: poolOf([
          for (var i = 0; i < 800; i++)
            vocab('word$i', 'nghĩa $i', level: 'A2'),
        ]),
        mode: WordBlasterMode.classic,
        random: Random(1),
      );
      final watch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        generator.next(distractors: 4);
      }
      expect(watch.elapsedMilliseconds / 100, lessThan(5));
    });
  });

  test('normalizeMeaning strips Vietnamese diacritics and punctuation', () {
    expect(normalizeMeaning('  Đáng TIN cậy! '), 'dang tin cay');
    expect(meaningsOverlap('dang tin cay', 'tin cay'), isTrue);
    expect(meaningsOverlap('cay nen', 'cay cau'), isFalse);
  });
}

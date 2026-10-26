import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/math/math_round.dart';
import 'package:expat8_language_app/src/games/math/math_skills.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math_checker.dart';

void main() {
  test('every level produces correct answers within its range', () {
    for (final level in MathLevel.values) {
      final generator =
          MathProblemGenerator(level: level, random: Random(level.index));
      for (var i = 0; i < 400; i++) {
        generator.difficulty = (i % 11) / 10;
        final p = generator.next();
        expect(solveProblem(p.text), p.answer, reason: '$level ${p.text}');
        if (!p.signed) {
          expect(p.answer, greaterThanOrEqualTo(0), reason: p.text);
        }
        if (p.op == MathOp.divide) {
          final parts = p.text.split(' ÷ ').map(int.parse).toList();
          expect(parts[0] % parts[1], 0, reason: 'exact division ${p.text}');
        }
        if (level == MathLevel.grade1) {
          final numbers = RegExp(r'\d+')
              .allMatches(p.text)
              .map((m) => int.parse(m.group(0)!));
          expect(numbers.every((n) => n <= 20), isTrue, reason: p.text);
          expect(p.answer, lessThanOrEqualTo(20), reason: p.text);
          expect(p.op, anyOf(MathOp.add, MathOp.subtract));
        }
        if (level == MathLevel.grade2) {
          expect(p.answer, lessThanOrEqualTo(100), reason: p.text);
        }
      }
    }
  });

  test('grade 3 is mostly times tables and division facts', () {
    final generator =
        MathProblemGenerator(level: MathLevel.grade3, random: Random(4));
    final ops = [for (var i = 0; i < 300; i++) generator.next().op];
    final tableFacts =
        ops.where((o) => o == MathOp.multiply || o == MathOp.divide).length;
    expect(tableFacts, greaterThan(200));
  });

  test('choices include the answer once, are distinct, close and non-negative',
      () {
    final random = Random(9);
    for (final level in MathLevel.values) {
      final generator = MathProblemGenerator(level: level, random: random);
      for (var i = 0; i < 200; i++) {
        final p = generator.next();
        final choices = plausibleChoices(p, random);
        expect(choices.length, 4);
        expect(choices.toSet().length, 4);
        expect(choices.where((c) => c == p.answer).length, 1);
        expect(choices.every((c) => c >= 0 || p.signed), isTrue);
        if (p.signed && p.answer != 0) {
          expect(choices, contains(-p.answer), reason: 'sign flip ${p.text}');
        }
        // Distractors stay close so the child must compute, not estimate.
        final spread = max(12, p.answer.abs() ~/ 4 + 12);
        expect(
            choices
                .every((c) => (c - p.answer).abs() <= spread || c == -p.answer),
            isTrue,
            reason: '${p.text} $choices');
      }
    }
  });

  test('difficulty rises with fast correct answers and drops after misses', () {
    final generator = MathProblemGenerator(level: MathLevel.grade2);
    final start = generator.difficulty;
    for (var i = 0; i < 5; i++) {
      generator.recordResult(
          correct: true, elapsed: const Duration(milliseconds: 1500));
    }
    expect(generator.difficulty, greaterThan(start));
    final high = generator.difficulty;
    generator.recordResult(correct: false, elapsed: const Duration(seconds: 3));
    expect(generator.difficulty, lessThan(high));
  });

  test('hints teach a strategy and contain the right answer', () {
    expect(additionProblem(8, 7).hint, 'Make ten: 8 + 2 + 5 = 15');
    expect(subtractionProblem(15, 7).hint, 'Back to ten: 15 − 5 − 2 = 8');
    expect(multiplicationProblem(7, 9).hint, contains('63'));
    expect(multiplicationProblem(34, 6).hint, contains('204'));
    expect(divisionProblem(56, 8).hint, 'Think times table: 8 × 7 = 56');
    expect(multiplicationProblem(7, 8).key, multiplicationProblem(8, 7).key);
  });

  test('missed facts are replayed until answered right twice', () async {
    final storage = InMemoryGameStorage();
    final skills = MathSkillTracker(storage);
    await skills.load();
    final fact = multiplicationProblem(7, 8);
    skills.record(MathLevel.grade3, fact,
        correct: false, elapsed: const Duration(seconds: 5));
    expect(skills.weakItems(MathLevel.grade3).single.item.key, fact.key);

    final generator = MathProblemGenerator(
      level: MathLevel.grade3,
      random: Random(1),
      weakFacts: skills,
      replayShare: 1,
    );
    expect(generator.next().key, fact.key);

    await skills.save();
    final reloaded = MathSkillTracker(storage);
    await reloaded.load();
    expect(reloaded.weakItems(MathLevel.grade3), hasLength(1));

    reloaded.record(MathLevel.grade3, fact,
        correct: true, elapsed: const Duration(seconds: 2));
    expect(reloaded.weakItems(MathLevel.grade3), hasLength(1));
    reloaded.record(MathLevel.grade3, fact,
        correct: true, elapsed: const Duration(seconds: 2));
    expect(reloaded.weakItems(MathLevel.grade3), isEmpty);
    expect(reloaded.statsFor(MathLevel.grade3).answered, 3); // 1 miss + 2 right
  });

  test('round log rewards speed and streaks and lists missed problems', () {
    final skills = MathSkillTracker(InMemoryGameStorage());
    final log = MathRoundLog(
      level: MathLevel.grade1,
      generator: MathProblemGenerator(level: MathLevel.grade1),
      skills: skills,
    );
    final fast = log.submit(additionProblem(2, 3),
        correct: true, elapsed: const Duration(milliseconds: 500));
    final slow = log.submit(additionProblem(4, 3),
        correct: true, elapsed: const Duration(seconds: 7));
    expect(fast, greaterThan(slow - 1));
    expect(fast, greaterThan(15));
    log.submit(additionProblem(8, 7),
        correct: false, elapsed: const Duration(seconds: 3), given: '14');
    expect(log.combo, 0);
    expect(log.bestCombo, 2);
    expect(log.missed.single.text, '8 + 7');
    expect(log.accuracy, closeTo(2 / 3, 0.001));
  });
}

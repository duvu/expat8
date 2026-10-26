import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/math/math_round.dart';
import 'package:expat8_language_app/src/games/math/math_skills.dart';
import 'package:expat8_language_app/src/games/math/number_tower.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_catalog.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math_test_utils.dart';

TowerSession tower(MathLevel level, {int seed = 8}) => TowerSession(
      log: MathRoundLog(
        level: level,
        generator: MathProblemGenerator(level: level, random: Random(seed)),
        skills: MathSkillTracker(InMemoryGameStorage()),
      ),
      random: Random(seed),
    );

/// Two blocks on the board that make the target.
(TowerBlock, TowerBlock)? solvingPair(TowerSession s) {
  final all = s.blocks.toList();
  for (var i = 0; i < all.length; i++) {
    for (var j = i + 1; j < all.length; j++) {
      final a = all[i].value, b = all[j].value;
      if ((s.rules.product ? a * b : a + b) == s.target)
        return (all[i], all[j]);
    }
  }
  return null;
}

void main() {
  test('every level always offers a target that two blocks can make', () {
    for (final level in MathLevel.values) {
      final s = tower(level, seed: level.index);
      for (var i = 0; i < 15 && !s.isOver; i++) {
        final pair = solvingPair(s);
        expect(pair, isNotNull, reason: '$level target ${s.target}');
        s.tap(pair!.$1);
        expect(s.tap(pair.$2), TowerOutcome.cleared);
      }
      expect(s.log.correctCount, greaterThan(0));
    }
  });

  test('grade 3 trains times tables; grade 1 trains bonds to ten', () {
    expect(TowerRules.of(MathLevel.grade3).product, isTrue);
    expect(TowerRules.of(MathLevel.grade1).product, isFalse);
    expect(TowerRules.of(MathLevel.grade1).maxBlock, 9);
  });

  test('overshooting the sum clears the pick and records the miss', () {
    final s = tower(MathLevel.grade1);
    final sorted = s.blocks.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    TowerOutcome outcome = TowerOutcome.selected;
    for (final b in sorted) {
      outcome = s.tap(b);
      if (outcome != TowerOutcome.selected) break;
    }
    if (outcome == TowerOutcome.cleared) return; // hit the target exactly
    expect(outcome, TowerOutcome.wrong);
    expect(s.selected, isEmpty);
    expect(s.log.missed, hasLength(1));
  });

  test('blocks keep dropping until the tower is full', () {
    final s = tower(MathLevel.grade2);
    var seconds = 0.0;
    while (!s.isOver && seconds < 600) {
      s.update(0.5);
      seconds += 0.5;
    }
    expect(s.isOver, isTrue);
    expect(s.blocks.length, TowerSession.columnsCount * TowerSession.rows);
  });

  testWidgets('tap blocks to make targets in Grade 3 (multiply), then fill up',
      (tester) async {
    final ctx = mathContext(seed: 2);
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.tower),
        level: 'grade3', theme: 'Easter eggs');
    expect(find.text('Two blocks that multiply to'), findsOneWidget);

    // Read the board the way the child sees it.
    Map<Key, int> board() => {
          for (final e in find
              .byWidgetPredicate((w) =>
                  w is GestureDetector &&
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('tower-block-'))
              .evaluate())
            e.widget.key!: int.parse(tester
                .widget<Text>(find.descendant(
                    of: find.byWidget(e.widget), matching: find.byType(Text)))
                .data!),
        };
    int target() => int.parse(
        tester.widget<Text>(find.byKey(const ValueKey('tower-target'))).data!);

    var made = 0;
    for (var round = 0; round < 3; round++) {
      await frames(tester, 20); // let dropping blocks land
      final blocks = board().entries.toList();
      final goal = target();
      MapEntry<Key, int>? first, second;
      for (var i = 0; i < blocks.length && first == null; i++) {
        for (var j = i + 1; j < blocks.length; j++) {
          if (blocks[i].value * blocks[j].value == goal) {
            first = blocks[i];
            second = blocks[j];
            break;
          }
        }
      }
      expect(first, isNotNull, reason: 'target $goal not makeable');
      await tester.tap(find.byKey(first!.key));
      await tester.pump();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('tower-selection')))
              .data,
          '${first.value} = ${first.value}');
      await tester.tap(find.byKey(second!.key));
      await tester.pump();
      made++;
    }
    expect(made, 3);
    expect(
        int.parse(tester
            .widget<Text>(find.byKey(const ValueKey('math-score')))
            .data!),
        greaterThanOrEqualTo(30));

    final result = find.byKey(const ValueKey('math-result-headline'));
    for (var i = 0; i < 2500 && result.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    expect(find.text('Tower full!'), findsOneWidget);
  });
}

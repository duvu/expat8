import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/math/math_round.dart';
import 'package:expat8_language_app/src/games/math/math_skills.dart';
import 'package:expat8_language_app/src/games/quiz/whack_game.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_catalog.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math_test_utils.dart';

WhackSession whack({MathLevel level = MathLevel.grade3}) => WhackSession(
      log: MathRoundLog(
        level: level,
        generator: MathProblemGenerator(level: level, random: Random(6)),
        skills: MathSkillTracker(InMemoryGameStorage()),
      ),
      random: Random(6),
    );

/// Advances until a fully raised mole matching [test] is up; returns its hole.
int waitForMole(WhackSession s, bool Function(Mole m) test) {
  for (var i = 0; i < 400; i++) {
    s.update(0.05);
    for (var h = 0; h < s.holes.length; h++) {
      final m = s.holes[h];
      if (m != null && !m.hit && m.raised >= 1 && test(m)) return h;
    }
  }
  fail('no matching mole appeared');
}

void main() {
  test('the answer keeps popping up and whacking it scores', () {
    final s = whack();
    for (var round = 0; round < 5; round++) {
      final answer = s.problem.answerText;
      final hole = waitForMole(s, (m) => m.value == answer);
      expect(s.whack(hole), WhackOutcome.correct);
    }
    expect(s.log.correctCount, 5);
    expect(s.log.score, greaterThan(50));
  });

  test('a wrong whack costs two seconds', () {
    final s = whack();
    final hole = waitForMole(s, (m) => m.value != s.problem.answerText);
    final before = s.timeLeft;
    expect(s.whack(hole), WhackOutcome.wrong);
    expect(
        s.timeLeft, closeTo(before - WhackSession.wrongPenaltySeconds, 0.01));
    expect(s.log.missed, hasLength(1));
  });

  test('moles stay up for less time as the streak grows; round lasts 60 s', () {
    final s = whack();
    final relaxed = s.upSeconds;
    for (var i = 0; i < 6; i++) {
      s.whack(waitForMole(s, (m) => m.value == s.problem.answerText));
    }
    expect(s.upSeconds, lessThan(relaxed));
    while (!s.isOver) {
      s.update(0.5);
    }
    expect(s.clock, lessThanOrEqualTo(WhackSession.roundSeconds + 0.5));
  });

  testWidgets('whack the answer on screen, then time runs out', (tester) async {
    final ctx = mathContext(seed: 4);
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.moles),
        level: 'grade3');
    String problem() => tester
        .widget<QuizPromptText>(find.byKey(const ValueKey('whack-problem')))
        .text;

    var whacked = 0;
    for (var i = 0; i < 300 && whacked < 3; i++) {
      final answer = evaluate(problem());
      final target = find.byKey(ValueKey('whack-value-$answer'));
      if (target.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 200)); // fully up
        if (target.evaluate().isEmpty) continue;
        await tester.tap(target.first, warnIfMissed: false);
        await tester.pump();
        if (evaluate(problem()) != answer) whacked++;
      } else {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    expect(whacked, 3);

    final result = find.byKey(const ValueKey('math-result-headline'));
    for (var i = 0; i < 800 && result.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    expect(find.text('Time\'s up!'), findsOneWidget);
    final board = await ctx.scoresFor(QuizGameKind.moles).load('grade3');
    expect(board.single.score, greaterThanOrEqualTo(30));
  });
}

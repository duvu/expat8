import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/math/math_race.dart';
import 'package:expat8_language_app/src/games/math/math_round.dart';
import 'package:expat8_language_app/src/games/math/math_skills.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math_test_utils.dart';

RaceSession race({MathLevel level = MathLevel.grade1}) => RaceSession(
      log: MathRoundLog(
        level: level,
        generator: MathProblemGenerator(level: level, random: Random(2)),
        skills: MathSkillTracker(InMemoryGameStorage()),
      ),
    );

Future<void> typeNumber(WidgetTester tester, int value) async {
  for (final digit in '$value'.split('')) {
    await tester.tap(find.byKey(ValueKey('math-key-$digit')));
    await tester.pump();
  }
}

String problemText(WidgetTester tester) {
  final text = tester
      .widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('race-problem')),
          matching: find.byType(Text)))
      .data!;
  return text.split(' = ').first;
}

void main() {
  test('fast correct answers win the race against the level pace', () {
    final r = race();
    while (!r.finished) {
      r.update(0.8); // answering in 0.8 s, well under the 4 s target
      r.submit(r.problem.answer);
    }
    expect(r.position, 1);
    expect(r.placeBonus, 100);
    expect(r.log.correctCount, lessThanOrEqualTo(RaceSession.answersToFinish));
  });

  test('slow answers let the computer cars finish first', () {
    final r = race();
    while (!r.finished) {
      r.update(9); // far slower than the level pace
      r.submit(r.problem.answer);
    }
    expect(r.position, 3);
  });

  test('wrong answers do not move the car; three quick ones give nitro', () {
    final r = race();
    r.update(0.5);
    expect(r.submit(r.problem.answer + 1), RaceAnswer.wrong);
    expect(r.player, 0);
    final results = <RaceAnswer>[];
    for (var i = 0; i < 3; i++) {
      r.update(0.5);
      results.add(r.submit(r.problem.answer));
    }
    expect(results.last, RaceAnswer.nitro);
    final before = r.player;
    r.update(1);
    expect(r.player, greaterThan(before));
  });

  testWidgets('type answers on the keypad and finish the race', (tester) async {
    final ctx = mathContext();
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.race),
        theme: 'Easter eggs');
    expect(find.byKey(const ValueKey('race-problem')), findsOneWidget);

    // A wrong answer stays on screen so the child can correct it.
    final first = evaluate(problemText(tester));
    await typeNumber(tester, first + 1);
    await tester.tap(find.byKey(const ValueKey('math-key-ok')));
    await tester.pump();
    expect(find.text('Not quite, try again!'), findsOneWidget);
    for (var i = 0; i < '${first + 1}'.length; i++) {
      await tester.tap(find.byKey(const ValueKey('math-key-back')));
      await tester.pump();
    }

    final result = find.byKey(const ValueKey('math-result-headline'));
    for (var i = 0; i < 40 && result.evaluate().isEmpty; i++) {
      await typeNumber(tester, evaluate(problemText(tester)));
      await tester.tap(find.byKey(const ValueKey('math-key-ok')));
      await frames(tester, 3);
    }
    await settle(tester);
    expect(find.text('You won the race!'), findsOneWidget);
    final board = await ctx.scoresFor(QuizGameKind.race).load('grade1');
    expect(board.single.score, greaterThan(100));
  });
}

import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/quiz/duel_game.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/math/math_round.dart';
import 'package:expat8_language_app/src/games/math/math_skills.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_catalog.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math_test_utils.dart';

MathRoundLog duelLog(MathLevel level, int seed) => MathRoundLog(
      level: level,
      generator: MathProblemGenerator(level: level, random: Random(seed)),
      skills: MathSkillTracker(InMemoryGameStorage()),
    );

void main() {
  test('each player has their own level; first to 10 wins', () {
    final duel = DuelSession(
        [duelLog(MathLevel.grade5, 1), duelLog(MathLevel.grade1, 2)]);
    expect(duel.players[0].level, MathLevel.grade5);
    expect(duel.players[1].level, MathLevel.grade1);
    for (var i = 0; i < DuelSession.pointsToWin; i++) {
      duel.update(1);
      expect(duel.answer(1, duel.players[1].problem.answerText),
          DuelAnswer.correct);
    }
    expect(duel.winner, 1);
    expect(
        duel.answer(0, duel.players[0].problem.answerText), DuelAnswer.locked);
  });

  test('a wrong tap freezes that player for 1.5 s only', () {
    final duel = DuelSession(
        [duelLog(MathLevel.grade2, 1), duelLog(MathLevel.grade2, 2)]);
    final p0 = duel.players[0];
    expect(duel.answer(0, '${p0.problem.answerText}0'), DuelAnswer.wrong);
    expect(duel.answer(0, p0.problem.answerText), DuelAnswer.locked);
    expect(
        duel.answer(1, duel.players[1].problem.answerText), DuelAnswer.correct);
    duel.update(DuelSession.lockSeconds + 0.01);
    expect(duel.answer(0, p0.problem.answerText), DuelAnswer.correct);
    expect(p0.log.missed, hasLength(1));
  });

  testWidgets('pick Player 2 level, duel to 10 and see both reviews',
      (tester) async {
    final ctx = mathContext(seed: 3);
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.duel),
        level: 'grade4');
    await tester.tap(find.byKey(const ValueKey('duel-p2-grade1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('duel-start')));
    await frames(tester, 5);
    expect(find.text('Player 2 · Grade 1 · 0/10'), findsOneWidget);

    String problem(int i) => tester
        .widget<QuizPromptText>(find.byKey(ValueKey('duel-problem-$i')))
        .text;

    // Player 2 (upside down) misses once and is frozen.
    final p2 = evaluate(problem(1));
    final wrong = tester
        .widgetList<FilledButton>(find.byWidgetPredicate((w) =>
            w is FilledButton &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('duel-1-choice-')))
        .map((b) =>
            int.parse((b.key! as ValueKey<String>).value.split('-').last))
        .firstWhere((v) => v != p2);
    await tester.tap(find.byKey(ValueKey('duel-1-choice-$wrong')));
    await tester.pump();
    expect(find.text('Frozen!'), findsOneWidget);

    // Player 1 answers ten in a row.
    for (var i = 0; i < 10; i++) {
      final answer = evaluate(problem(0));
      await tester.tap(find.byKey(ValueKey('duel-0-choice-$answer')));
      await frames(tester, 2);
    }
    await settle(tester);
    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Let\'s fix these'), findsOneWidget);
  });
}

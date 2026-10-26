import 'dart:math';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/games_hub_screen.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/math/math_round.dart';
import 'package:expat8_language_app/src/games/math/math_skills.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_ui.dart';
import 'package:expat8_language_app/src/games/quiz/blaster_game.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'math_test_utils.dart';

BlasterSession blasterSession({MathLevel level = MathLevel.grade1}) =>
    BlasterSession(
      log: MathRoundLog(
        level: level,
        generator: MathProblemGenerator(level: level, random: Random(3)),
        skills: MathSkillTracker(InMemoryGameStorage()),
      ),
      random: Random(3),
    )..start();

void main() {
  test('correct answers score and clear the target; landing costs a life', () {
    final s = blasterSession();
    final first = s.target!;
    final (outcome, points) = s.answer(first.problem.answerText);
    expect(outcome, BlasterOutcome.correct);
    expect(points, greaterThanOrEqualTo(10));
    expect(s.falling.contains(first), isFalse);
    expect(s.target, isNotNull);

    // Let everything land three times.
    var landed = 0;
    while (!s.isOver) {
      landed += s.update(0.1).length;
    }
    expect(landed, BlasterSession.startingLives);
    expect(s.lives, 0);
    expect(s.log.missed, isNotEmpty);
  });

  test('a wrong answer pushes the target down instead of ending the game', () {
    final s = blasterSession();
    final target = s.target!;
    final before = target.y;
    final (outcome, _) = s.answer('${target.problem.answerText}0');
    expect(outcome, BlasterOutcome.wrong);
    expect(target.y, greaterThan(before));
    expect(s.lives, BlasterSession.startingLives);
    expect(s.log.combo, 0);
  });

  test('it speeds up and adds problems as the child gets them right', () {
    final s = blasterSession();
    final slow = s.fallSeconds;
    for (var i = 0; i < 24; i++) {
      s.answer(s.target!.problem.answerText);
    }
    expect(s.fallSeconds, lessThan(slow));
    expect(s.maxOnScreen, 3);
  });

  testWidgets('play a Grade 2 Easter round: answers score, landing ends it',
      (tester) async {
    final ctx = mathContext();
    await openPlay(tester, quizGameHome(ctx, QuizGameKind.blaster),
        level: 'grade2', theme: 'Easter eggs');
    expect(find.byType(QuizToken), findsWidgets);
    expect(await ctx.level(QuizGameKind.blaster), MathLevel.grade2);

    for (var i = 0; i < 3; i++) {
      final answer = evaluate(targetLabel(tester));
      await tester.tap(find.byKey(ValueKey('blaster-choice-$answer')));
      await frames(tester, 2);
    }
    final score =
        tester.widget<Text>(find.byKey(const ValueKey('math-score'))).data;
    expect(int.parse(score!), greaterThanOrEqualTo(30));

    // Stop answering: problems land until the hearts run out (each frame
    // advances at most 0.1 s of game time).
    final result = find.byKey(const ValueKey('math-result-headline'));
    for (var i = 0; i < 900 && result.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    expect(find.byKey(const ValueKey('math-result-headline')), findsOneWidget);
    expect(find.text('Let\'s fix these'), findsOneWidget);
    final board = await ctx.scoresFor(QuizGameKind.blaster).load('grade2');
    expect(board.single.score, greaterThanOrEqualTo(30));
  });

  testWidgets('games hub lists Number Blaster', (tester) async {
    final ctx = mathContext();
    await tester.pumpWidget(
        MaterialApp(home: GamesHubScreen(storage: ctx.storage, quiz: ctx)));
    expect(find.text('Number Blaster'), findsOneWidget);
    await tester.tap(find.text('Number Blaster'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-journey')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('math-play')), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('math-play')), findsOneWidget);
  });
}

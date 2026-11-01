import 'dart:math';

import 'package:expat8_language_app/src/games/english/english_quiz.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/party/party_engine.dart';
import 'package:expat8_language_app/src/games/quiz/duel_game.dart';
import 'package:expat8_language_app/src/games/party/party_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

PartyPlayer player(String id, dynamic level, {int seed = 1}) => PartyPlayer(
    id: id, name: id, log: partyRoundLog(level, random: Random(seed)));

List<Map<String, dynamic>> to(List<PartyOut> out, String id) => [
      for (final o in out)
        if (o.to == id) o.message
    ];

List<Map<String, dynamic>> broadcast(List<PartyOut> out) => [
      for (final o in out)
        if (o.to == null) o.message
    ];

Map<String, dynamic> lastQuestion(List<PartyOut> out, String id) =>
    to(out, id).lastWhere((m) => m['t'] == PartyMsg.question);

void main() {
  group('Quiz Night', () {
    late QuizNightEngine engine;

    setUp(() {
      engine = QuizNightEngine(rounds: 2, questionMs: 10000, pauseMs: 2000)
        ..addPlayer(player('mom', MathLevel.values.last, seed: 1))
        ..addPlayer(player('kid', MathLevel.values.first, seed: 2));
    });

    test('each player gets a question at their own level, no answer sent', () {
      final out = engine.start(0);
      final mom = lastQuestion(out, 'mom');
      final kid = lastQuestion(out, 'kid');
      expect(mom['round'], 1);
      expect(mom['ms_left'], 10000);
      expect(mom['choices'], hasLength(4));
      expect(mom.containsKey('answer'), isFalse);
      expect(mom['qid'], isNot(kid['qid']));
      expect(engine.scoreboard.map((p) => p.level).toSet(), hasLength(2));
    });

    test('a round ends as soon as everyone answered; duplicates ignored', () {
      final start = engine.start(0);
      final momQ = lastQuestion(start, 'mom');
      final kidQ = lastQuestion(start, 'kid');

      final first = engine.answer(
          'mom', momQ['qid'], engine.correctChoiceFor('mom')!, 1500);
      expect(to(first, 'mom').single['correct'], isTrue);
      expect(to(first, 'mom').single['points'], greaterThan(0));
      expect(engine.answer('mom', momQ['qid'], 0, 1600), isEmpty);

      final wrong = (engine.correctChoiceFor('kid')! + 1) % 4;
      final second = engine.answer('kid', kidQ['qid'], wrong, 3000);
      final kidResult = to(second, 'kid').single;
      expect(kidResult['correct'], isFalse);
      expect(kidResult['answer'], isNotEmpty);
      final roundEnd = broadcast(second).single;
      expect(roundEnd['t'], PartyMsg.roundEnd);
      expect(roundEnd['round'], 1);

      // After the pause, round 2; after it, the final ranking.
      expect(engine.tick(1999 + 3000), isEmpty);
      final round2 = engine.tick(2000 + 3000);
      expect(lastQuestion(round2, 'kid')['round'], 2);
      expect(engine.tick(5000 + 10000).last.message['t'], PartyMsg.roundEnd);
      final finished = engine.tick(5000 + 10000 + 2000);
      expect(finished.single.message['t'], PartyMsg.finished);
      expect(engine.finished, isTrue);
      final ranking = (finished.single.message['players'] as List)
          .map((p) => PartyPlayerView.fromJson(p as Map<String, dynamic>))
          .toList();
      expect(ranking.first.id, 'mom');
    });

    test('late answers are rejected and time out as misses', () {
      final q = lastQuestion(engine.start(0), 'kid');
      final timeout = engine.tick(10000);
      expect(to(timeout, 'kid').single['correct'], isFalse);
      expect(engine.answer('kid', q['qid'], 0, 10001), isEmpty);
    });

    test('a player dropping mid-round does not stall it; they can resume', () {
      final start = engine.start(0);
      final momQ = lastQuestion(start, 'mom');
      engine.answer('mom', momQ['qid'], 0, 1000);
      final dropped = engine.disconnect('kid', 2000);
      expect(broadcast(dropped).last['t'], PartyMsg.roundEnd);

      final round2 = engine.tick(4000);
      expect(to(round2, 'kid'), isEmpty, reason: 'offline players skip');
      final back = engine.resume('kid', 4500);
      expect(back.first.message['t'], PartyMsg.lobby);
      expect(
          engine.scoreboard.singleWhere((p) => p.id == 'kid').connected, true);
    });
  });

  group('Duel', () {
    test('right answers bring the next question; first to 10 wins', () {
      final engine = DuelEngine()
        ..addPlayer(player('dad', EnglishLevel.values.last, seed: 3))
        ..addPlayer(player('kid', MathLevel.values.first, seed: 4));
      var out = engine.start(0);
      var now = 0;
      String qid(String id) => lastQuestion(out, id)['qid'] as String;

      // A wrong answer locks the kid for 1.5 s.
      final wrong = (engine.correctChoiceFor('kid')! + 1) % 4;
      final locked = engine.answer('kid', qid('kid'), wrong, now += 500);
      expect(to(locked, 'kid').single['lock_ms'], 1500);
      expect(
          engine.answer(
              'kid', qid('kid'), engine.correctChoiceFor('kid')!, now += 500),
          isEmpty,
          reason: 'still locked');

      for (var i = 0; i < DuelSession.pointsToWin; i++) {
        out = engine.answer(
            'dad', qid('dad'), engine.correctChoiceFor('dad')!, now += 700);
        expect(to(out, 'dad').first['correct'], isTrue);
      }
      expect(engine.finished, isTrue);
      final ranking = out.last.message;
      expect(ranking['t'], PartyMsg.finished);
      expect((ranking['players'] as List).first['id'], 'dad');
      expect((ranking['players'] as List).first['score'], 10);
    });
  });

  test('party round logs never touch saved skill trackers', () {
    final a = partyRoundLog(MathLevel.values.first);
    final b = partyRoundLog(MathLevel.values.first);
    expect(identical(a.skills, b.skills), isFalse);
  });
}

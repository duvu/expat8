import 'dart:math';

import 'package:expat8_language_app/src/curriculum/local_skill_answer_sink.dart';
import 'package:expat8_language_app/src/curriculum/skill_answer_sink.dart';
import 'package:expat8_language_app/src/curriculum/skill_mastery.dart';
import 'package:expat8_language_app/src/data/local_database.dart';
import 'package:expat8_language_app/src/games/common/game_audio.dart';
import 'package:expat8_language_app/src/games/common/game_settings.dart';
import 'package:expat8_language_app/src/games/english/english_quiz.dart';
import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/math/math_problem.dart';
import 'package:expat8_language_app/src/games/party/party_client.dart';
import 'package:expat8_language_app/src/games/party/party_engine.dart';
import 'package:expat8_language_app/src/games/party/party_host.dart';
import 'package:expat8_language_app/src/games/party/party_protocol.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:expat8_language_app/src/models/user_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements SkillAnswerSink {
  final answers = <SkillAnswer>[];

  @override
  void record(SkillAnswer answer) => answers.add(answer);
}

Future<void> _until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

SkillAnswer _answer(String skill, {bool correct = true}) => SkillAnswer(
    skillId: skill,
    correct: correct,
    elapsedMs: 1000,
    answeredAtMs: DateTime.now().millisecondsSinceEpoch);

Future<LocalDatabase> _database(String name) => LocalDatabase.open(
    databaseName: 'skill_${name}_${DateTime.now().microsecondsSinceEpoch}.db');

QuizGameContext _context(SkillAnswerSink? sink) {
  final storage = InMemoryGameStorage();
  final settings = GameSettings(storage);
  return QuizGameContext(
    storage: storage,
    settings: settings,
    audio: GameAudio.silent(settings),
    skillSink: sink,
    randomFactory: () => Random(1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('local database', () {
    test('each account sees only its own answers', () async {
      final db = await _database('owners');
      await db.addSkillAnswer(_answer('math.a'), ownerUserId: 'mai');
      await db.addSkillAnswer(_answer('math.a'), ownerUserId: 'mai');
      await db.addSkillAnswer(_answer('math.b'), ownerUserId: 'an');
      await db.addSkillAnswer(_answer('math.c'), ownerUserId: null);

      expect((await db.skillAnswers(ownerUserId: 'mai')).length, 2);
      expect(
          (await db.skillAnswers(ownerUserId: 'an')).single.skillId, 'math.b');
      expect(
          (await db.skillAnswers(ownerUserId: null)).single.skillId, 'math.c');
    });

    test('answers can be limited to a subject', () async {
      final db = await _database('subject');
      await db.addSkillAnswer(_answer('math.a'), ownerUserId: 'mai');
      await db.addSkillAnswer(_answer('science.a'), ownerUserId: 'mai');
      final math = await db.skillAnswers(ownerUserId: 'mai', subject: 'math');
      expect(math.single.skillId, 'math.a');
    });

    test('signed in and signed out answers go to different owners', () async {
      final db = await _database('sink2');
      final sink = LocalSkillAnswerSink(db);

      sink.record(_answer('math.signed-out'));
      await _waitFor(
          () async => (await db.skillAnswers(ownerUserId: null)).length == 1);

      await db.saveUserSession(const UserSession(
          userId: 'mai', identifier: 'mai@example.com', sessionToken: 'token'));
      sink.record(_answer('math.signed-in'));
      await _waitFor(
          () async => (await db.skillAnswers(ownerUserId: 'mai')).length == 1);

      expect((await db.skillAnswers(ownerUserId: null)).single.skillId,
          'math.signed-out');
      expect((await db.skillAnswers(ownerUserId: 'mai')).single.skillId,
          'math.signed-in');
    });
  });

  group('round log', () {
    test('records skill-tagged math answers', () {
      final sink = _Sink();
      final log = _context(sink).roundLog(MathLevel.grade3);
      final problem = multiplicationProblem(7, 8);

      log.submit(problem,
          correct: true, elapsed: const Duration(milliseconds: 1500));
      log.submit(problem,
          correct: false, elapsed: const Duration(milliseconds: 2500));

      expect(sink.answers, hasLength(2));
      expect(sink.answers.first.skillId, problem.skillId);
      expect(sink.answers.first.correct, isTrue);
      expect(sink.answers.first.elapsedMs, 1500);
      expect(sink.answers.last.correct, isFalse);
    });

    test('does not record items without a skill', () {
      final sink = _Sink();
      final log = _context(sink).roundLog(EnglishLevel.grade6);
      final item =
          EnglishSource(level: EnglishLevel.grade6, random: Random(1)).next();
      expect(item.skillId, isNull);

      log.submit(item,
          correct: true, elapsed: const Duration(milliseconds: 900));

      expect(sink.answers, isEmpty);
    });

    test('works without a sink', () {
      final log = _context(null).roundLog(MathLevel.grade3);
      expect(
          log.submit(multiplicationProblem(2, 3),
              correct: true, elapsed: const Duration(seconds: 1)),
          greaterThan(0));
    });
  });

  group('party', () {
    test('every phone records only its own answers; the host none', () async {
      final host = PartyHost(
        engine: QuizNightEngine(rounds: 1, questionMs: 20000, pauseMs: 100),
        subject: QuizSubject.math,
        mode: PartyMode.quizNight,
        roomName: 'Room',
        tickInterval: const Duration(milliseconds: 20),
      );
      final server = LanPartyServer(host);
      await server.start();
      final sinks = [_Sink(), _Sink()];
      final clients = <PartyClient>[];
      for (final (i, sink) in sinks.indexed) {
        final client = PartyClient(Uri.parse('ws://127.0.0.1:${server.port}'));
        client.skillSink = sink;
        clients.add(client);
        await client.open();
        await _until(() => client.stage == PartyStage.choosing);
        client.join(
            name: 'P$i', levelId: QuizSubject.math.levels[2 + i * 4].id);
        await _until(() => client.stage == PartyStage.lobby);
      }
      await _until(() => clients.every((c) => c.players.length == 2));

      host.startGame();
      await _until(() => clients.every((c) => c.stage == PartyStage.question));
      // The first player answers right, the second wrong.
      final right = host.engine.correctChoiceFor(clients[0].playerId!)!;
      final other = host.engine.correctChoiceFor(clients[1].playerId!)!;
      clients[0].answer(right);
      clients[1].answer((other + 1) % clients[1].question!.choices.length);
      await _until(() => sinks.every((s) => s.answers.isNotEmpty));

      expect(sinks[0].answers, hasLength(1));
      expect(sinks[1].answers, hasLength(1));
      expect(sinks[0].answers.single.correct, isTrue);
      expect(sinks[1].answers.single.correct, isFalse);
      expect(sinks[0].answers.single.source, 'party');
      expect(sinks[0].answers.single.skillId, startsWith('math.'));
      expect(host.engine.players.values.every((p) => p.log.skillSink == null),
          isTrue);

      for (final c in clients) {
        await c.leave();
      }
      await server.close();
    });

    test('the question carries the skill but never the answer', () {
      final engine = QuizNightEngine(rounds: 1);
      final log = partyRoundLog(MathLevel.grade3, random: Random(2));
      engine.addPlayer(PartyPlayer(id: 'p1', name: 'An', log: log));
      final out = engine.start(0);
      final question = out
          .map((o) => o.message)
          .singleWhere((m) => m['t'] == PartyMsg.question);
      expect(question['skill'], startsWith('math.'));
      expect(question.containsKey('answer'), isFalse);
    });
  });
}

Future<void> _waitFor(Future<bool> Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!await condition()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

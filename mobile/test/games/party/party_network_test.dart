import 'package:expat8_language_app/src/games/party/party_client.dart';
import 'package:expat8_language_app/src/games/party/party_engine.dart';
import 'package:expat8_language_app/src/games/party/party_host.dart';
import 'package:expat8_language_app/src/games/party/party_protocol.dart';
import 'package:expat8_language_app/src/games/party/room_address.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:flutter_test/flutter_test.dart';

final _all = <PartyClient>[];

/// Waits until [condition] holds (the network is real, so not instant).
Future<void> until(bool Function() condition,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail(
          'timed out waiting at ${StackTrace.current.toString().split('\n')[1]}; '
          'stages: ${[
        for (final c in _all) '${c.playerId}:${c.stage.name}:r${c.round}'
      ]}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<PartyClient> joined(
    LanPartyServer server, String name, String level) async {
  final client = PartyClient(Uri.parse('ws://127.0.0.1:${server.port}'),
      heartbeat: const Duration(milliseconds: 200));
  _all.add(client);
  await client.open();
  await until(() => client.stage == PartyStage.choosing);
  client.join(name: name, levelId: level);
  await until(() => client.stage == PartyStage.lobby);
  return client;
}

void main() {
  late PartyHost host;
  late LanPartyServer server;
  late List<PartyClient> clients;

  tearDown(() async {
    for (final c in clients) {
      await c.leave();
    }
    await server.close();
  });

  test('three phones play a whole Quiz Night over the network', () async {
    host = PartyHost(
      // Long enough not to expire on a busy test machine; everyone answers,
      // so rounds end early anyway.
      engine: QuizNightEngine(rounds: 2, questionMs: 20000, pauseMs: 300),
      subject: QuizSubject.math,
      mode: PartyMode.quizNight,
      roomName: "Mom's room",
      tickInterval: const Duration(milliseconds: 20),
    );
    server = LanPartyServer(host);
    await server.start();
    final levels = QuizSubject.math.levels;
    clients = [
      await joined(server, 'Mom', levels.last.id),
      await joined(server, 'An', levels.first.id),
      await joined(server, 'Binh', levels[2].id),
    ];
    final [mom, an, binh] = clients;
    expect(mom.roomName, "Mom's room");
    expect(mom.levels, hasLength(levels.length));
    await until(() => clients.every((c) => c.players.length == 3));
    expect(an.players.map((p) => p.level).toSet(), hasLength(3));

    // A latecomer cannot join a game in progress.
    host.startGame();
    await until(() => clients.every((c) => c.stage == PartyStage.question));
    final late = PartyClient.lan(RoomAddress('127.0.0.1', server.port));
    clients.add(late);
    await late.open();
    await until(() => late.stage == PartyStage.choosing);
    late.join(name: 'Late', levelId: levels.first.id);
    await until(() => late.stage == PartyStage.rejected);
    expect(late.rejectReason, PartyReject.started);

    for (var round = 1; round <= 2; round++) {
      await until(() => [mom, an, binh]
          .every((c) => c.stage == PartyStage.question && c.round == round));
      final anStages = <PartyStage>[];
      void record() => anStages.add(an.stage);
      an.addListener(record);
      for (final c in [mom, an, binh]) {
        c.answer(host.engine.correctChoiceFor(c.playerId!)!);
      }
      await until(() => anStages.contains(PartyStage.roundEnd));
      an.removeListener(record);
      if (round == 1) {
        // An's WiFi drops between rounds; the seat and score survive.
        final scoreBefore =
            an.players.singleWhere((p) => p.id == an.playerId).score;
        final seen = <PartyStage>[];
        an.addListener(() => seen.add(an.stage));
        await an.simulateDrop();
        await until(() =>
            seen.contains(PartyStage.reconnecting) &&
            an.stage != PartyStage.reconnecting);
        expect(an.players.singleWhere((p) => p.id == an.playerId).score,
            scoreBefore);
      }
    }
    await until(
        () => [mom, an, binh].every((c) => c.stage == PartyStage.finished));
    expect(mom.ranking, hasLength(3));
    expect(mom.ranking.every((p) => p.score > 0), isTrue,
        reason: 'everyone answered right twice');
    expect(mom.lastResult!.correct, isTrue);
  });

  test('Duel over the network: the first to 10 wins', () async {
    host = PartyHost(
      engine: DuelEngine(),
      subject: QuizSubject.english,
      mode: PartyMode.duel,
      roomName: 'Duel',
      tickInterval: const Duration(milliseconds: 20),
    );
    server = LanPartyServer(host);
    await server.start();
    final levels = QuizSubject.english.levels;
    clients = [
      await joined(server, 'Dad', levels.last.id),
      await joined(server, 'Chi', levels.first.id),
    ];
    final [dad, chi] = clients;
    host.startGame();
    await until(() => clients.every((c) => c.stage == PartyStage.question));
    for (var i = 0; i < 10; i++) {
      final qid = dad.question!.qid;
      dad.answer(host.engine.correctChoiceFor(dad.playerId!)!);
      await until(
          () => dad.stage == PartyStage.finished || dad.question!.qid != qid);
    }
    await until(() => chi.stage == PartyStage.finished);
    expect(chi.ranking.first.name, 'Dad');
    expect(chi.ranking.first.score, 10);
  });

  test('room codes round-trip and pick the WiFi address', () {
    const address = RoomAddress('192.168.1.23', 51034);
    expect(address.code, matches(RegExp(r'^[0-9A-Z]{5}-[0-9A-Z]{5}$')));
    expect(RoomAddress.fromCode(address.code), address);
    expect(
        RoomAddress.fromCode(address.code.toLowerCase().replaceAll('-', ' ')),
        address);
    expect(RoomAddress.fromCode('hello'), isNull);
    expect(
        pickLanAddress([
          ('tun0', '10.113.213.20'), // VPN
          ('rmnet_data0', '10.20.30.40'), // mobile data
          ('wlan0', '192.168.1.23'),
        ]),
        '192.168.1.23');
    expect(pickLanAddress([('pdp_ip0', '10.1.1.1')]), isNull);
  });
}

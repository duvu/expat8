import 'dart:convert';
import 'dart:io';

import 'package:expat8_language_app/src/games/party/party_client.dart';
import 'package:expat8_language_app/src/games/party/party_engine.dart';
import 'package:expat8_language_app/src/games/party/party_host.dart';
import 'package:expat8_language_app/src/games/party/party_protocol.dart';
import 'package:expat8_language_app/src/games/party/party_relay_host.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backend relay's framing (backend/src/party_relay.js), in miniature.
class FakeRelay {
  late final HttpServer server;
  WebSocket? host;
  final guests = <String, WebSocket>{};
  final announced = <String>{};
  int _next = 0;
  static const code = 'ABC123';
  static const token = 'host-token';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      final ws = await WebSocketTransformer.upgrade(request);
      if (path == PartyRelay.hostPath) {
        ws.listen((raw) => _fromHost(ws, jsonDecode(raw as String)),
            onDone: () => host = identical(host, ws) ? null : host);
      } else {
        final id = 'g${++_next}';
        guests[id] = ws;
        if (host != null) _announce(id);
        ws.listen(
          (raw) {
            if (announced.contains(id)) {
              _toHost({'from': id, 'm': jsonDecode(raw as String)});
            }
          },
          onDone: () {
            guests.remove(id);
            _toHost({'from': id, 'closed': true});
          },
        );
      }
    });
  }

  void _announce(String id) {
    announced.add(id);
    _toHost({'from': id, 'open': true});
  }

  void _toHost(Map<String, dynamic> frame) {
    final ws = host;
    if (ws != null && ws.readyState == WebSocket.open)
      ws.add(jsonEncode(frame));
  }

  /// The host's connection drops (the relay keeps the room and its guests).
  Future<void> dropHost() async {
    final ws = host!;
    host = null;
    await ws.close();
  }

  void _fromHost(WebSocket ws, Map<String, dynamic> frame) {
    if (frame['t'] == 'relay_host') {
      if (frame['resume'] != null && frame['resume'] != token) return;
      host = ws;
      ws.add(jsonEncode({
        't': 'relay_room',
        'code': code,
        'host_token': token,
        'guests': [...announced.where(guests.containsKey)],
      }));
      for (final id in guests.keys.where((id) => !announced.contains(id))) {
        _announce(id);
      }
    } else if (frame['to'] case final String to) {
      guests[to]?.add(jsonEncode(frame['m']));
    }
  }

  PartyRelay get relay => PartyRelay((path) => (
        uri: Uri.parse('ws://127.0.0.1:${server.port}$path'),
        headers: const {},
      ));
}

Future<void> until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('online codes are 6 tolerant characters', () {
    expect(parseOnlineRoomCode(' abc-1o2 '), 'ABC102');
    expect(parseOnlineRoomCode('ABCDE-FGHJK'), isNull, reason: 'a LAN code');
    expect(parseOnlineRoomCode('ABU123'), isNull, reason: 'U is not used');
  });

  test('a party through the relay survives the host losing its connection',
      () async {
    final relay = FakeRelay();
    await relay.start();
    final host = PartyHost(
      engine: QuizNightEngine(rounds: 2, questionMs: 20000, pauseMs: 200),
      subject: QuizSubject.math,
      mode: PartyMode.quizNight,
      roomName: "Grandma's room",
      tickInterval: const Duration(milliseconds: 20),
    );
    final room = RelayPartyHost(host, relay.relay);
    final code = await room.start();
    expect(code, FakeRelay.code);

    final levels = QuizSubject.math.levels;
    final players = <PartyClient>[];
    for (final (name, level) in [('Grandma', levels[4]), ('Chi', levels[0])]) {
      final c = relay.relay.client(code);
      players.add(c);
      await c.open();
      await until(() => c.stage == PartyStage.choosing);
      c.join(name: name, levelId: level.id);
    }
    await until(() => players.every((c) => c.players.length == 2));
    expect(players.first.roomName, "Grandma's room");

    host.startGame();
    for (var round = 1; round <= 2; round++) {
      await until(() => players
          .every((c) => c.stage == PartyStage.question && c.round == round));
      if (round == 2) {
        // Grandma's phone loses the internet for a moment mid-question.
        await relay.dropHost();
        await until(() => relay.host != null); // resumed with the token
      }
      for (final c in players) {
        c.answer(host.engine.correctChoiceFor(c.playerId!)!);
      }
    }
    await until(() => players.every((c) => c.stage == PartyStage.finished));
    expect(players.first.ranking.every((p) => p.score > 0), isTrue);

    for (final c in players) {
      await c.leave();
    }
    await room.close();
    await relay.server.close(force: true);
  });
}

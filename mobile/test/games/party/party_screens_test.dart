import 'dart:async';

import 'package:expat8_language_app/src/games/game_storage.dart';
import 'package:expat8_language_app/src/games/party/party_client.dart';
import 'package:expat8_language_app/src/games/party/party_engine.dart';
import 'package:expat8_language_app/src/games/party/party_home_screen.dart';
import 'package:expat8_language_app/src/games/party/party_host.dart';
import 'package:expat8_language_app/src/games/party/party_play_screen.dart';
import 'package:expat8_language_app/src/games/party/party_protocol.dart';
import 'package:expat8_language_app/src/games/party/room_address.dart';
import 'package:expat8_language_app/src/games/party/room_discovery.dart';
import 'package:expat8_language_app/src/games/quiz/quiz_game_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDiscovery implements RoomDiscovery {
  final rooms = StreamController<List<PartyRoom>>();

  @override
  Future<void> advertise(
      {required String name,
      required int port,
      required PartyMode mode}) async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Stream<List<PartyRoom>> browse() => rooms.stream;
}

void main() {
  testWidgets('nearby rooms are listed; a bad code is refused', (tester) async {
    final discovery = _FakeDiscovery();
    await tester.pumpWidget(MaterialApp(
      home:
          PartyHomeScreen(storage: InMemoryGameStorage(), discovery: discovery),
    ));
    expect(find.text('Looking for rooms on this WiFi…'), findsOneWidget);

    discovery.rooms.add([
      const PartyRoom(
          name: "Mom's room",
          address: RoomAddress('192.168.1.5', 4040),
          mode: PartyMode.quizNight),
    ]);
    await tester.pump();
    expect(find.text("Mom's room"), findsOneWidget);
    expect(find.text('Quiz Night'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('party-code')), 'nope');
    await tester.tap(find.text('Join'));
    await tester.pump();
    expect(find.text('That is not a room code.'), findsOneWidget);
  });

  testWidgets('a guest picks a name and level, then waits in the lobby',
      (tester) async {
    late LanPartyServer server;
    late PartyClient guest;
    await tester.runAsync(() async {
      server = LanPartyServer(PartyHost(
        engine: QuizNightEngine(),
        subject: QuizSubject.english,
        mode: PartyMode.quizNight,
        roomName: "Dad's room",
      ));
      await server.start();
      guest = PartyClient.lan(RoomAddress('127.0.0.1', server.port));
      await guest.open();
      while (guest.stage != PartyStage.choosing) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpWidget(MaterialApp(home: PartyPlayScreen(client: guest)));
    expect(find.text("Dad's room"), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('party-name')), 'Chi');
    final level = QuizSubject.english.levels.first;
    await tester.tap(find.byKey(ValueKey('party-level-${level.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('party-join')));
    await tester.runAsync(() async {
      while (guest.stage != PartyStage.lobby || guest.players.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Chi (you)'), findsOneWidget);
    expect(find.text('Waiting for the host to start…'), findsOneWidget);

    await tester.runAsync(guest.leave);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(server.close);
  });
}

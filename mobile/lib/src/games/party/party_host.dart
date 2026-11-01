import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../quiz/quiz_game_context.dart';
import 'party_engine.dart';
import 'party_protocol.dart';

/// One player's connection to the host, whatever carries it (a LAN socket,
/// or a guest behind the internet relay).
abstract interface class PartyLink {
  void send(Map<String, dynamic> message);
  void close();
}

/// Runs a party on this phone: seats players, feeds their answers to the
/// [engine] and sends out what it decides. Transport-agnostic — a
/// [LanPartyServer] or an internet relay attaches each player's [PartyLink]
/// and reports its messages; the host's own player connects through the same
/// path as everyone else.
class PartyHost {
  PartyHost({
    required this.engine,
    required this.subject,
    required this.mode,
    required this.roomName,
    this.maxPlayers = 8,
    this.tickInterval = const Duration(milliseconds: 200),
    this.heartbeatTimeout = const Duration(seconds: 15),
    this.resumeWindow = const Duration(seconds: 30),
    Random? random,
  }) : _random = random ?? Random.secure();

  final PartyEngine engine;
  final QuizSubject subject;
  final PartyMode mode;
  final String roomName;
  final int maxPlayers;
  final Duration tickInterval;

  /// A connection silent for this long (no ping) is closed.
  final Duration heartbeatTimeout;

  /// How long a dropped player's seat and score wait for them to come back.
  final Duration resumeWindow;

  final Random _random;
  final _clock = Stopwatch()..start();
  final Map<PartyLink, _Connection> _connections = {};
  final Map<String, _Seat> _seats = {};
  Timer? _ticker;
  int _nextPlayer = 0;

  int get _now => _clock.elapsedMilliseconds;

  int get playerCount => _seats.length;

  void start() {
    _ticker ??= Timer.periodic(tickInterval, (_) => _onTick());
  }

  /// Starts the game for everyone seated.
  void startGame() {
    if (engine.started) return;
    _send([...engine.start(_now), engine.lobbyMessage()]);
  }

  void close() {
    _ticker?.cancel();
    for (final link in _connections.keys.toList()) {
      link.close();
    }
    _connections.clear();
  }

  /// A player connected: greet them with the room's details.
  void attach(PartyLink link) {
    final connection = _connections[link] = _Connection(link, _now);
    connection.send(partyMessage(PartyMsg.room, {
      'room': roomName,
      'subject': subject.name,
      'mode': mode.name,
      'levels': [
        for (final level in subject.levels)
          {'id': level.id, 'label': level.label},
      ],
    }));
  }

  void onMessage(PartyLink link, Object? data) {
    final connection = _connections[link];
    if (connection != null) _onData(connection, data);
  }

  void onClosed(PartyLink link) {
    final connection = _connections.remove(link);
    if (connection != null) _onClosed(connection);
  }

  /// Re-sends everyone their current state (after the relay was unreachable
  /// and messages may have been lost).
  void resyncAll() {
    for (final seat in _seats.values) {
      if (seat.connection != null) _send(engine.resume(seat.playerId, _now));
    }
  }

  void _onData(_Connection connection, Object? data) {
    connection.lastSeenMs = _now;
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(data as String) as Map<String, dynamic>;
    } on Object {
      return; // Not ours: ignore.
    }
    switch (message['t']) {
      case PartyMsg.hello:
        _onHello(connection, message);
      case PartyMsg.answer:
        final seat = connection.seat;
        final qid = message['qid'];
        final choice = message['choice'];
        if (seat == null || qid is! String || choice is! int) return;
        _send(engine.answer(seat.playerId, qid, choice, _now));
      case PartyMsg.ping:
        connection.send(partyMessage(PartyMsg.pong));
    }
  }

  void _onHello(_Connection connection, Map<String, dynamic> hello) {
    if (connection.seat != null) return;
    if (hello['v'] != partyProtocolVersion) {
      return _reject(connection, PartyReject.version);
    }
    final token = hello['token'];
    final returning = _seats.values.where((s) => s.token == token).firstOrNull;
    if (returning != null) {
      returning.connection?.link.close();
      returning
        ..connection = connection
        ..droppedAtMs = null;
      connection.seat = returning;
      connection.send(_welcome(returning));
      return _send(engine.resume(returning.playerId, _now));
    }
    if (engine.started) return _reject(connection, PartyReject.started);
    if (_seats.length >= maxPlayers) {
      return _reject(connection, PartyReject.full);
    }
    final name = (hello['name'] as String? ?? '').trim();
    final seat = _Seat(
      playerId: 'p${++_nextPlayer}',
      token: [for (var i = 0; i < 4; i++) _random.nextInt(1 << 32)].join('-'),
    )..connection = connection;
    _seats[seat.playerId] = seat;
    connection.seat = seat;
    engine.addPlayer(PartyPlayer(
      id: seat.playerId,
      name: name.isEmpty ? 'Player $_nextPlayer' : name,
      log: partyRoundLog(subject.levelFromId(hello['level'] as String?)),
    ));
    connection.send(_welcome(seat));
    _send([engine.lobbyMessage()]);
  }

  Map<String, dynamic> _welcome(_Seat seat) => partyMessage(PartyMsg.welcome, {
        'player': seat.playerId,
        'token': seat.token,
      });

  void _reject(_Connection connection, String reason) {
    connection.send(partyMessage(PartyMsg.reject, {'reason': reason}));
    connection.link.close();
  }

  void _onClosed(_Connection connection) {
    final seat = connection.seat;
    if (seat != null && identical(seat.connection, connection)) {
      seat
        ..connection = null
        ..droppedAtMs = _now;
    }
  }

  void _onTick() {
    final now = _now;
    for (final c in _connections.values.toList()) {
      if (now - c.lastSeenMs > heartbeatTimeout.inMilliseconds) {
        onClosed(c.link);
        c.link.close();
      }
    }
    for (final seat in _seats.values.toList()) {
      final dropped = seat.droppedAtMs;
      if (dropped == null || now - dropped < resumeWindow.inMilliseconds) {
        continue;
      }
      seat.droppedAtMs = null;
      if (engine.started) {
        _send(engine.disconnect(seat.playerId, now));
      } else {
        // Left the lobby: free the seat.
        _seats.remove(seat.playerId);
        engine.players.remove(seat.playerId);
        _send([engine.lobbyMessage()]);
      }
    }
    _send(engine.tick(now));
  }

  void _send(List<PartyOut> out) {
    for (final o in out) {
      final target = o.to;
      if (target == null) {
        for (final seat in _seats.values) {
          seat.connection?.send(o.message);
        }
      } else {
        _seats[target]?.connection?.send(o.message);
      }
    }
  }
}

class _Connection {
  _Connection(this.link, this.lastSeenMs);

  final PartyLink link;
  int lastSeenMs;
  _Seat? seat;

  void send(Map<String, dynamic> message) => link.send(message);
}

/// Serves a [PartyHost] on the local network: a WebSocket server on a free
/// port of this phone.
class LanPartyServer {
  LanPartyServer(this.host);

  final PartyHost host;
  HttpServer? _server;

  /// The port the party listens on (after [start]).
  int get port => _server!.port;

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    host.start();
    server.listen(_onRequest);
  }

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    final link = _SocketLink(socket);
    host.attach(link);
    socket.listen(
      (data) => host.onMessage(link, data),
      onDone: () => host.onClosed(link),
      onError: (Object _) => host.onClosed(link),
      cancelOnError: true,
    );
  }

  Future<void> close() async {
    host.close();
    await _server?.close(force: true);
  }
}

class _SocketLink implements PartyLink {
  _SocketLink(this.socket);

  final WebSocket socket;

  @override
  void send(Map<String, dynamic> message) {
    if (socket.readyState == WebSocket.open) socket.add(jsonEncode(message));
  }

  @override
  void close() => socket.close();
}

class _Seat {
  _Seat({required this.playerId, required this.token});

  final String playerId;

  /// Lets a dropped player take their seat back (same score, same game).
  final String token;
  _Connection? connection;
  int? droppedAtMs;
}

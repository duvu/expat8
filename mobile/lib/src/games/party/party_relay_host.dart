import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'party_client.dart';
import 'party_host.dart';

/// A signed backend WebSocket address; produced afresh for every connection
/// (see BackendApiClient.signedSocket).
typedef SignedSocket = ({Uri uri, Map<String, String> headers}) Function(
    String path);

/// The internet relay on the Expat8 backend: for families who are not on the
/// same WiFi. The host phone still runs the game; the relay only forwards.
class PartyRelay {
  const PartyRelay(this.signedSocket);

  final SignedSocket signedSocket;

  static const hostPath = '/v1/party/host';
  static String joinPath(String code) => '/v1/party/join/$code';

  /// A player joining the online room [code] (the host's own player too, so
  /// everyone's answers travel the same way and speed points stay fair).
  PartyClient client(String code) {
    final path = joinPath(code);
    return PartyClient(signedSocket(path).uri,
        headers: () => signedSocket(path).headers);
  }

  Future<WebSocket> connectHost() {
    final socket = signedSocket(hostPath);
    return WebSocket.connect(socket.uri.toString(), headers: socket.headers)
        .timeout(const Duration(seconds: 8));
  }
}

/// Online room codes: 6 characters, tolerant of case, spaces, dashes and
/// letters people mistake for digits (LAN codes have 10). Null otherwise.
String? parseOnlineRoomCode(String raw) {
  final code = raw
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');
  return RegExp(r'^[0-9A-HJKMNP-TV-Z]{6}$').hasMatch(code) ? code : null;
}

/// Serves a [PartyHost] through the internet relay: each guest behind the
/// relay becomes a [PartyLink]. Survives a short loss of the host's
/// connection by taking the room back with its host token.
class RelayPartyHost {
  RelayPartyHost(this.host, this.relay, {this.resumeFor = _resumeFor});

  static const _resumeFor = Duration(seconds: 25);

  final PartyHost host;
  final PartyRelay relay;
  final Duration resumeFor;

  /// The room code to share (after [start]).
  String? code;
  String? _hostToken;
  WebSocket? _upstream;
  final Map<String, _RelayLink> _links = {};
  Completer<void>? _roomReady;
  bool _closed = false;

  /// Opens the room; returns its code.
  Future<String> start() async {
    host.start();
    await _open();
    return code!;
  }

  Future<void> _open() async {
    final socket = await relay.connectHost();
    _upstream = socket;
    final ready = _roomReady = Completer<void>();
    socket.listen(_onFrame, onDone: _onUpstreamDone, cancelOnError: true);
    socket.add(jsonEncode({
      't': 'relay_host',
      if (_hostToken != null) 'resume': _hostToken,
    }));
    await ready.future.timeout(const Duration(seconds: 8));
  }

  void _onFrame(Object? data) {
    final Map<String, dynamic> frame;
    try {
      frame = jsonDecode(data as String) as Map<String, dynamic>;
    } on Object {
      return;
    }
    if (frame['t'] == 'relay_room') {
      final resumed = _hostToken != null;
      code = frame['code'] as String;
      _hostToken = frame['host_token'] as String;
      if (resumed) {
        // Guests who left while we were away; then catch everyone up.
        final present = {...(frame['guests'] as List).cast<String>()};
        for (final id in _links.keys.toList()) {
          if (!present.contains(id)) host.onClosed(_links.remove(id)!);
        }
        host.resyncAll();
      }
      _roomReady?.complete();
      return;
    }
    final id = frame['from'];
    if (id is! String) return;
    if (frame['open'] == true) {
      final link = _links[id] = _RelayLink(id, this);
      host.attach(link);
    } else if (frame['closed'] == true) {
      final link = _links.remove(id);
      if (link != null) host.onClosed(link);
    } else if (frame['m'] case final Map<String, dynamic> message) {
      final link = _links[id];
      if (link != null) host.onMessage(link, jsonEncode(message));
    }
  }

  void _onUpstreamDone() {
    _upstream = null;
    if (!_closed) unawaited(_resume());
  }

  Future<void> _resume() async {
    final giveUpAt = DateTime.now().add(resumeFor);
    while (!_closed && DateTime.now().isBefore(giveUpAt)) {
      try {
        await _open();
        return;
      } on Object {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    // The relay gave the room up: every guest is gone.
    for (final link in _links.values.toList()) {
      host.onClosed(link);
    }
    _links.clear();
  }

  void _sendUpstream(Map<String, dynamic> frame) {
    final socket = _upstream;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(frame));
    }
  }

  /// Ends the room for everyone.
  Future<void> close() async {
    _closed = true;
    host.close();
    _sendUpstream({'t': 'relay_end'});
    final socket = _upstream;
    _upstream = null;
    unawaited(socket?.close());
  }
}

class _RelayLink implements PartyLink {
  _RelayLink(this.id, this.relay);

  final String id;
  final RelayPartyHost relay;

  @override
  void send(Map<String, dynamic> message) =>
      relay._sendUpstream({'to': id, 'm': message});

  @override
  void close() => relay._sendUpstream({'close': id});
}

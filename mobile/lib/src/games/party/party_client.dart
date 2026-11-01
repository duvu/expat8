import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../curriculum/skill_answer_sink.dart';
import '../../curriculum/skill_mastery.dart';
import 'party_protocol.dart';
import 'room_address.dart';

/// Where the player is in the party.
enum PartyStage {
  connecting,

  /// Connected; choose a name and level, then [PartyClient.join].
  choosing,
  lobby,
  question,

  /// Answered; waiting for the others (Quiz Night).
  answered,
  roundEnd,
  finished,
  rejected,

  /// Connection lost; retrying with the seat token.
  reconnecting,
  closed,
}

class PartyLevelOption {
  const PartyLevelOption(this.id, this.label);

  final String id;
  final String label;
}

class PartyQuestion {
  PartyQuestion({
    required this.qid,
    required this.text,
    required this.choices,
    required this.deadline,
    required this.timeLimit,
    this.round,
    this.rounds,
  });

  final String qid;
  final String text;
  final List<String> choices;

  /// Local time the answer must arrive by; null when there is no limit.
  final DateTime? deadline;

  /// The time there was to answer when the question arrived.
  final Duration timeLimit;
  final int? round;
  final int? rounds;
}

class PartyResult {
  const PartyResult({
    required this.qid,
    required this.correct,
    required this.answer,
    required this.points,
    this.hint,
  });

  final String qid;
  final bool correct;
  final String answer;
  final int points;
  final String? hint;
}

/// One player's connection to a party (the host's own player too, over
/// loopback). Exposes the party state for the UI and survives short WiFi
/// drops by reconnecting with its seat token.
class PartyClient extends ChangeNotifier {
  PartyClient(
    this.uri, {
    this.headers,
    this.heartbeat = const Duration(seconds: 5),
    this.resumeFor = const Duration(seconds: 30),
    this.connectTimeout = const Duration(seconds: 6),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// A party on the local network.
  factory PartyClient.lan(RoomAddress address) =>
      PartyClient(Uri(scheme: 'ws', host: address.host, port: address.port));

  /// The party's WebSocket address (a LAN host or the internet relay).
  final Uri uri;

  /// Builds the connect headers; called on every (re)connect so a signed
  /// request never reuses a nonce.
  final Map<String, String> Function()? headers;
  final Duration heartbeat;
  final Duration resumeFor;
  final Duration connectTimeout;
  final DateTime Function() _now;

  PartyStage stage = PartyStage.connecting;
  String? roomName;
  String? subject;
  PartyMode? mode;
  List<PartyLevelOption> levels = const [];
  String? playerId;
  List<PartyPlayerView> players = const [];
  bool started = false;
  PartyQuestion? question;
  PartyResult? lastResult;
  DateTime? lockedUntil;
  int? round;
  int? rounds;
  List<PartyPlayerView> ranking = const [];
  String? rejectReason;

  /// Records this player's own answers to skill-tagged questions.
  SkillAnswerSink? skillSink;

  // Per question id: its curriculum skill and when it was shown / answered.
  final Map<String, _Tracked> _tracked = {};

  WebSocket? _socket;
  Timer? _pinger;
  String? _token;
  Map<String, dynamic>? _hello;
  bool _disposed = false;

  /// Connects and waits for the room's details ([PartyStage.choosing]).
  Future<void> open() async {
    await _connect();
  }

  Future<void> _connect() async {
    final socket =
        await WebSocket.connect(uri.toString(), headers: headers?.call())
            .timeout(connectTimeout);
    if (_disposed) {
      await socket.close();
      return;
    }
    _socket = socket;
    socket.listen(_onData, onDone: _onDone, cancelOnError: true);
    _pinger?.cancel();
    _pinger = Timer.periodic(heartbeat, (_) => _send(PartyMsg.ping));
    // Coming back after a drop: take the seat again.
    if (_hello != null) _send(PartyMsg.hello, {..._hello!, 'token': _token});
  }

  /// Takes a seat as [name] playing at [levelId].
  void join({required String name, required String levelId}) {
    _hello = {'name': name, 'level': levelId};
    _send(PartyMsg.hello, _hello!);
  }

  bool get isLocked => lockedUntil != null && _now().isBefore(lockedUntil!);

  void answer(int choice) {
    final q = question;
    if (q == null || stage != PartyStage.question || isLocked) return;
    _send(PartyMsg.answer, {'qid': q.qid, 'choice': choice});
    _tracked[q.qid]?.answeredAt ??= _now();
    if (mode == PartyMode.quizNight) _setStage(PartyStage.answered);
  }

  void _send(String type, [Map<String, dynamic> body = const {}]) {
    final socket = _socket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(partyMessage(type, body)));
    }
  }

  void _onData(Object? data) {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(data as String) as Map<String, dynamic>;
    } on Object {
      return;
    }
    List<PartyPlayerView> playerList() => [
          for (final p in m['players'] as List)
            PartyPlayerView.fromJson(p as Map<String, dynamic>),
        ];
    switch (m['t']) {
      case PartyMsg.room:
        roomName = m['room'] as String?;
        subject = m['subject'] as String?;
        mode = PartyMode.values.asNameMap()[m['mode']];
        levels = [
          for (final l in m['levels'] as List)
            PartyLevelOption(l['id'] as String, l['label'] as String),
        ];
        if (_hello == null) _setStage(PartyStage.choosing);
      case PartyMsg.welcome:
        playerId = m['player'] as String;
        _token = m['token'] as String;
        if (stage == PartyStage.choosing || stage == PartyStage.connecting) {
          _setStage(PartyStage.lobby);
        }
      case PartyMsg.reject:
        rejectReason = m['reason'] as String?;
        _setStage(PartyStage.rejected);
      case PartyMsg.lobby:
        players = playerList();
        started = m['started'] as bool? ?? false;
        if (stage == PartyStage.reconnecting) {
          _setStage(started ? PartyStage.answered : PartyStage.lobby);
        }
        _notify();
      case PartyMsg.question:
        final msLeft = (m['ms_left'] as num?)?.toInt() ?? 0;
        question = PartyQuestion(
          qid: m['qid'] as String,
          text: m['text'] as String,
          choices: [for (final c in m['choices'] as List) c as String],
          deadline:
              msLeft > 0 ? _now().add(Duration(milliseconds: msLeft)) : null,
          timeLimit: Duration(milliseconds: msLeft),
          round: (m['round'] as num?)?.toInt(),
          rounds: (m['rounds'] as num?)?.toInt(),
        );
        if (m['skill'] case final String skill) {
          _tracked
            ..clear()
            ..[question!.qid] = _Tracked(skill, _now());
        }
        round = question!.round ?? round;
        rounds = question!.rounds ?? rounds;
        lockedUntil = null;
        _setStage(PartyStage.question);
      case PartyMsg.result:
        lastResult = PartyResult(
          qid: m['qid'] as String,
          correct: m['correct'] as bool,
          answer: m['answer'] as String,
          points: (m['points'] as num).toInt(),
          hint: m['hint'] as String?,
        );
        _recordSkill(lastResult!);
        final lockMs = (m['lock_ms'] as num?)?.toInt() ?? 0;
        if (lockMs > 0) {
          lockedUntil = _now().add(Duration(milliseconds: lockMs));
        }
        _notify();
      case PartyMsg.roundEnd:
        players = playerList();
        _setStage(PartyStage.roundEnd);
      case PartyMsg.finished:
        ranking = playerList();
        _setStage(PartyStage.finished);
    }
  }

  void _recordSkill(PartyResult result) {
    final tracked = _tracked.remove(result.qid);
    if (tracked == null) return;
    // An unanswered question (time ran out) took the whole time limit.
    final elapsed = (tracked.answeredAt ?? _now()).difference(tracked.shownAt);
    skillSink?.record(SkillAnswer(
      skillId: tracked.skillId,
      correct: result.correct,
      elapsedMs: elapsed.inMilliseconds,
      answeredAtMs: _now().millisecondsSinceEpoch,
      source: 'party',
    ));
  }

  void _onDone() {
    _pinger?.cancel();
    _socket = null;
    if (_disposed ||
        stage == PartyStage.finished ||
        stage == PartyStage.rejected) {
      return;
    }
    if (_token == null) return _setStage(PartyStage.closed);
    _setStage(PartyStage.reconnecting);
    unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    final giveUpAt = _now().add(resumeFor);
    while (!_disposed && _now().isBefore(giveUpAt)) {
      try {
        await _connect();
        return;
      } on Object {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    if (!_disposed) _setStage(PartyStage.closed);
  }

  void _setStage(PartyStage next) {
    stage = next;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Cuts the connection as a WiFi drop would (the client then reconnects).
  @visibleForTesting
  Future<void> simulateDrop() async => _socket?.close();

  /// Leaves the party.
  Future<void> leave() async {
    _disposed = true;
    _pinger?.cancel();
    final socket = _socket;
    _socket = null;
    // Not awaited: leaving must not hang on a peer that never answers the
    // close handshake.
    unawaited(socket?.close());
  }

  @override
  void dispose() {
    unawaited(leave());
    super.dispose();
  }
}

class _Tracked {
  _Tracked(this.skillId, this.shownAt);

  final String skillId;
  final DateTime shownAt;
  DateTime? answeredAt;
}

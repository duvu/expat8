/// Messages of a LAN party: JSON over a WebSocket, host-authoritative.
///
/// Guests only display questions and send the index of their choice; the host
/// generates every question (at each player's own level), keeps the answers
/// and scores. Times travel as "milliseconds left", never as clock readings,
/// so devices with different clocks stay fair.
library;

const partyProtocolVersion = 1;

/// Message types.
abstract final class PartyMsg {
  // Guest → host.
  static const hello = 'hello';
  static const answer = 'answer';
  static const ping = 'ping';

  // Host → guest.
  /// Sent as soon as a socket connects: room name, subject, mode and the
  /// levels to choose from before saying hello.
  static const room = 'room';
  static const welcome = 'welcome';
  static const reject = 'reject';
  static const lobby = 'lobby';
  static const question = 'question';
  static const result = 'result';
  static const roundEnd = 'round_end';
  static const finished = 'final';
  static const pong = 'pong';
}

/// Why a guest could not join.
abstract final class PartyReject {
  static const started = 'already_started';
  static const full = 'room_full';
  static const version = 'version';

  // Sent by the internet relay.
  static const noRoom = 'no_room';
  static const roomClosed = 'room_closed';
}

Map<String, dynamic> partyMessage(String type,
        [Map<String, dynamic> body = const {}]) =>
    {'v': partyProtocolVersion, 't': type, ...body};

/// A player as everyone sees them on the scoreboard.
class PartyPlayerView {
  const PartyPlayerView({
    required this.id,
    required this.name,
    required this.level,
    required this.score,
    required this.connected,
  });

  factory PartyPlayerView.fromJson(Map<String, dynamic> json) =>
      PartyPlayerView(
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as String,
        score: (json['score'] as num).toInt(),
        connected: json['connected'] as bool? ?? true,
      );

  final String id;
  final String name;

  /// The level's label, e.g. "Grade 3".
  final String level;
  final int score;
  final bool connected;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'score': score,
        'connected': connected,
      };
}

/// The party games.
enum PartyMode {
  /// Everyone answers one question per round; fast right answers score more.
  quizNight('Quiz Night'),

  /// Everyone races through their own questions; first to 10 wins.
  duel('Duel');

  const PartyMode(this.title);

  final String title;
}

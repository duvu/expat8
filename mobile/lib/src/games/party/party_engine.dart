import 'dart:math';

import 'package:flutter/foundation.dart';

import '../english/english_quiz.dart';
import '../game_storage.dart';
import '../math/math_problem.dart';
import '../math/math_round.dart';
import '../math/math_skills.dart';
import '../quiz/duel_game.dart';
import '../quiz/quiz_core.dart';
import '../quiz/quiz_round.dart';
import 'party_protocol.dart';

/// A message for one player ([to]) or for everyone (null).
class PartyOut {
  const PartyOut(this.message, {this.to});

  final Map<String, dynamic> message;
  final String? to;
}

/// A round log for a party player with throwaway skill trackers: other
/// family members' answers never become the host's own weak items.
QuizRoundLog partyRoundLog(QuizLevel level, {Random? random}) {
  final storage = InMemoryGameStorage();
  if (level is MathLevel) {
    return MathRoundLog(
      level: level,
      generator: MathProblemGenerator(level: level, random: random),
      skills: MathSkillTracker(storage),
    );
  }
  if (level is EnglishLevel) {
    return EnglishRoundLog(
      level: level,
      generator: EnglishSource(level: level, random: random),
      skills: EnglishSkillTracker(storage),
    );
  }
  throw ArgumentError.value(level, 'level', 'unknown subject');
}

class PartyPlayer {
  PartyPlayer({required this.id, required this.name, required this.log});

  final String id;
  final String name;
  final QuizRoundLog log;
  bool connected = true;

  PartyPlayerView view(int score) => PartyPlayerView(
        id: id,
        name: name,
        level: log.level.label,
        score: score,
        connected: connected,
      );
}

/// The rules of one party game. Pure: the host feeds it joins, answers and
/// clock ticks (milliseconds) and sends whatever messages it returns.
abstract class PartyEngine {
  PartyEngine();

  /// Builds the engine for [mode].
  factory PartyEngine.forMode(PartyMode mode) => switch (mode) {
        PartyMode.quizNight => QuizNightEngine(),
        PartyMode.duel => DuelEngine(),
      };

  final Map<String, PartyPlayer> players = {};

  /// Each player's current question.
  final Map<String, _Asked> _asked = {};

  bool get started;
  bool get finished;

  /// Seats a player in the lobby (the host refuses joins once started).
  void addPlayer(PartyPlayer player) => players[player.id] = player;

  /// The score that decides the winner.
  int scoreOf(PartyPlayer player) => player.log.score;

  List<PartyPlayerView> get scoreboard =>
      [for (final p in players.values) p.view(scoreOf(p))];

  PartyOut lobbyMessage() => PartyOut(partyMessage(PartyMsg.lobby, {
        'players': [for (final p in scoreboard) p.toJson()],
        'started': started,
      }));

  List<PartyOut> start(int nowMs);
  List<PartyOut> answer(String playerId, String qid, int choice, int nowMs);
  List<PartyOut> tick(int nowMs);

  /// The player left or their connection dropped (the host already waited
  /// for them to come back).
  List<PartyOut> disconnect(String playerId, int nowMs) {
    players[playerId]?.connected = false;
    return [lobbyMessage()];
  }

  /// Everything a reconnecting player needs to catch up.
  List<PartyOut> resume(String playerId, int nowMs) {
    players[playerId]?.connected = true;
    return [lobbyMessage(), ...currentQuestionFor(playerId, nowMs)];
  }

  List<PartyOut> currentQuestionFor(String playerId, int nowMs);

  /// Index of the right choice in [playerId]'s current question.
  @visibleForTesting
  int? correctChoiceFor(String playerId) {
    final asked = _asked[playerId];
    return asked?.choices.indexOf(asked.item.answerText);
  }

  PartyOut finalMessage() {
    final ranking = scoreboard..sort((a, b) => b.score.compareTo(a.score));
    return PartyOut(partyMessage(PartyMsg.finished, {
      'players': [for (final p in ranking) p.toJson()],
    }));
  }
}

/// A question asked to one player.
class _Asked {
  _Asked(this.qid, this.item, this.choices, this.askedAtMs);

  final String qid;
  final QuizItem item;
  final List<String> choices;
  final int askedAtMs;
  bool answered = false;

  Map<String, dynamic> message(int msLeft, {int? round, int? rounds}) =>
      partyMessage(PartyMsg.question, {
        'qid': qid,
        'text': item.text,
        'choices': choices,
        'ms_left': msLeft,
        // Which curriculum skill this trains, for the player's own progress
        // (never the answer).
        if (item.skillId != null) 'skill': item.skillId,
        if (round != null) 'round': round,
        if (rounds != null) 'rounds': rounds,
      });
}

PartyOut _result(String to, _Asked asked,
        {required bool correct, required int points, int lockMs = 0}) =>
    PartyOut(
      partyMessage(PartyMsg.result, {
        'qid': asked.qid,
        'correct': correct,
        'answer': asked.item.answerText,
        'points': points,
        if (!correct && asked.item.hint != null) 'hint': asked.item.hint,
        if (lockMs > 0) 'lock_ms': lockMs,
      }),
      to: to,
    );

enum _Phase { lobby, question, pause, finished }

/// Quiz Night: every round, each player answers one question at their own
/// level within [questionMs]. Points come from [QuizRoundLog.submit], which
/// rewards speed relative to the level's target time, so a parent on a hard
/// level and a child on an easy one compete fairly.
class QuizNightEngine extends PartyEngine {
  QuizNightEngine({
    this.rounds = 10,
    this.questionMs = 20000,
    this.pauseMs = 4000,
  });

  final int rounds;
  final int questionMs;
  final int pauseMs;

  _Phase _phase = _Phase.lobby;
  int round = 0;
  int _phaseEndsAtMs = 0;

  @override
  bool get started => _phase != _Phase.lobby;

  @override
  bool get finished => _phase == _Phase.finished;

  @override
  List<PartyOut> start(int nowMs) {
    if (started || players.isEmpty) return const [];
    return _nextRound(nowMs);
  }

  List<PartyOut> _nextRound(int nowMs) {
    if (round == rounds) {
      _phase = _Phase.finished;
      return [finalMessage()];
    }
    round++;
    _phase = _Phase.question;
    _phaseEndsAtMs = nowMs + questionMs;
    _asked.clear();
    final out = <PartyOut>[];
    for (final p in players.values.where((p) => p.connected)) {
      final item = p.log.generator.next();
      final asked = _Asked(
          'r$round-${p.id}', item, p.log.generator.choicesFor(item), nowMs);
      _asked[p.id] = asked;
      out.add(PartyOut(asked.message(questionMs, round: round, rounds: rounds),
          to: p.id));
    }
    return out;
  }

  @override
  List<PartyOut> answer(String playerId, String qid, int choice, int nowMs) {
    final asked = _asked[playerId];
    final player = players[playerId];
    if (_phase != _Phase.question ||
        asked == null ||
        player == null ||
        asked.qid != qid ||
        asked.answered ||
        nowMs > _phaseEndsAtMs ||
        choice < 0 ||
        choice >= asked.choices.length) {
      return const [];
    }
    asked.answered = true;
    final given = asked.choices[choice];
    final correct = given == asked.item.answerText;
    final points = player.log.submit(asked.item,
        correct: correct,
        elapsed: Duration(milliseconds: nowMs - asked.askedAtMs),
        given: given);
    return [
      _result(playerId, asked, correct: correct, points: points),
      if (_everyoneAnswered) ..._endRound(nowMs),
    ];
  }

  bool get _everyoneAnswered => players.values
      .where((p) => p.connected)
      .every((p) => _asked[p.id]?.answered ?? true);

  List<PartyOut> _endRound(int nowMs) {
    final out = <PartyOut>[];
    // Unanswered questions time out as misses.
    for (final MapEntry(key: id, value: asked) in _asked.entries) {
      if (asked.answered) continue;
      asked.answered = true;
      final player = players[id];
      if (player == null) continue;
      player.log.submit(asked.item,
          correct: false, elapsed: Duration(milliseconds: questionMs));
      if (player.connected) {
        out.add(_result(id, asked, correct: false, points: 0));
      }
    }
    _phase = _Phase.pause;
    _phaseEndsAtMs = nowMs + pauseMs;
    out.add(PartyOut(partyMessage(PartyMsg.roundEnd, {
      'round': round,
      'rounds': rounds,
      'players': [for (final p in scoreboard) p.toJson()],
    })));
    return out;
  }

  @override
  List<PartyOut> tick(int nowMs) {
    if (nowMs < _phaseEndsAtMs) return const [];
    return switch (_phase) {
      _Phase.question => _endRound(nowMs),
      _Phase.pause => _nextRound(nowMs),
      _ => const [],
    };
  }

  @override
  List<PartyOut> disconnect(String playerId, int nowMs) => [
        ...super.disconnect(playerId, nowMs),
        if (_phase == _Phase.question && _everyoneAnswered) ..._endRound(nowMs),
      ];

  @override
  List<PartyOut> currentQuestionFor(String playerId, int nowMs) {
    final asked = _asked[playerId];
    if (_phase != _Phase.question || asked == null || asked.answered) {
      return const [];
    }
    return [
      PartyOut(
          asked.message(_phaseEndsAtMs - nowMs, round: round, rounds: rounds),
          to: playerId)
    ];
  }
}

/// Duel for any number of devices: everyone races through their own
/// questions (the existing [DuelSession] rules: first to
/// [DuelSession.pointsToWin], a wrong answer locks you for 1.5 s).
class DuelEngine extends PartyEngine {
  DuelSession? _session;
  final List<String> _order = [];
  int _lastTickMs = 0;
  int _questionCount = 0;

  @override
  bool get started => _session != null;

  @override
  bool get finished => _session?.winner != null;

  @override
  List<PartyOut> start(int nowMs) {
    if (started || players.isEmpty) return const [];
    _order.addAll(players.keys);
    _session = DuelSession([for (final id in _order) players[id]!.log]);
    _lastTickMs = nowMs;
    return [
      for (final id in _order)
        if (players[id]!.connected) _ask(id, nowMs),
    ];
  }

  DuelPlayer _duelPlayer(String id) => _session!.players[_order.indexOf(id)];

  /// Right answers, as in [DuelSession] (first to 10 wins).
  @override
  int scoreOf(PartyPlayer player) =>
      started ? _duelPlayer(player.id).points : 0;

  /// The player's current problem (the session already drew it).
  PartyOut _ask(String id, int nowMs) {
    final p = _duelPlayer(id);
    final asked = _Asked(
        'd${++_questionCount}-$id', p.problem, List.of(p.choices), nowMs);
    _asked[id] = asked;
    return PartyOut(asked.message(0), to: id);
  }

  @override
  List<PartyOut> answer(String playerId, String qid, int choice, int nowMs) {
    final session = _session;
    final asked = _asked[playerId];
    if (session == null ||
        finished ||
        asked == null ||
        asked.qid != qid ||
        choice < 0 ||
        choice >= asked.choices.length) {
      return const [];
    }
    _advanceClock(nowMs);
    final outcome =
        session.answer(_order.indexOf(playerId), asked.choices[choice]);
    if (outcome == DuelAnswer.locked) return const [];
    if (outcome == DuelAnswer.wrong) {
      return [
        _result(playerId, asked,
            correct: false,
            points: 0,
            lockMs: (DuelSession.lockSeconds * 1000).round()),
      ];
    }
    return [
      _result(playerId, asked, correct: true, points: 1),
      lobbyMessage(), // live scoreboard
      if (finished) finalMessage() else _ask(playerId, nowMs),
    ];
  }

  void _advanceClock(int nowMs) {
    _session!.update((nowMs - _lastTickMs) / 1000);
    _lastTickMs = nowMs;
  }

  @override
  List<PartyOut> tick(int nowMs) {
    if (_session != null && !finished) _advanceClock(nowMs);
    return const [];
  }

  @override
  List<PartyOut> currentQuestionFor(String playerId, int nowMs) {
    final asked = _asked[playerId];
    if (!started || finished || asked == null) return const [];
    return [PartyOut(asked.message(0), to: playerId)];
  }
}

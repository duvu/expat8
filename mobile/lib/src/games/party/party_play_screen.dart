import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../common/game_activity.dart';
import '../common/game_theme.dart';
import '../quiz/quiz_ui.dart';
import 'party_client.dart';
import 'party_host.dart';
import 'party_protocol.dart';

/// The party as one player sees it, from choosing a level to the podium.
/// The host's phone also passes [host] (to start the game) and [roomCode].
class PartyPlayScreen extends StatefulWidget {
  const PartyPlayScreen({
    required this.client,
    this.host,
    this.roomCode,
    this.defaultName = '',
    this.onName,
    this.online = false,
    super.key,
  });

  final PartyClient client;
  final PartyHost? host;
  final String? roomCode;

  /// The room is on the internet relay (others join only by its code).
  final bool online;
  final String defaultName;

  /// Remembers the name a guest typed.
  final ValueChanged<String>? onName;

  @override
  State<PartyPlayScreen> createState() => _PartyPlayScreenState();
}

class _PartyPlayScreenState extends State<PartyPlayScreen>
    with GameActivityScope {
  static const _theme = GameVisualTheme.space;
  Timer? _clock;

  PartyClient get _client => widget.client;

  @override
  void initState() {
    super.initState();
    _client.addListener(_onChange);
    // Redraws the countdown and the lock while a question is open.
    _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_client.stage == PartyStage.question && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _client.removeListener(_onChange);
    unawaited(_client.leave());
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = QuizPalette.of(_theme);
    // The space backdrop and panels are dark: so is every text and control.
    return Theme(data: AppTheme.dark(), child: _scaffold(palette));
  }

  Widget _scaffold(QuizPalette palette) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.text,
        title: Text(_client.roomName ?? 'Party'),
        actions: [
          if (_client.round case final round?)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('Round $round/${_client.rounds}',
                    style: TextStyle(
                        color: palette.text, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: QuizBackdrop(
        theme: _theme,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_client.stage == PartyStage.reconnecting)
                  _Banner('Reconnecting…', palette: palette),
                Expanded(child: _stage(palette)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage(QuizPalette palette) => switch (_client.stage) {
        PartyStage.connecting ||
        PartyStage.reconnecting =>
          const Center(child: CircularProgressIndicator()),
        PartyStage.choosing => _JoinForm(
            client: _client,
            defaultName: widget.defaultName,
            onName: widget.onName,
            palette: palette,
          ),
        PartyStage.lobby => _Lobby(
            client: _client,
            host: widget.host,
            roomCode: widget.roomCode,
            online: widget.online,
            palette: palette,
          ),
        PartyStage.question => _Question(client: _client, palette: palette),
        PartyStage.answered => _Panel(
            palette: palette,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_client.lastResult case final result?)
                _ResultLine(result, palette: palette),
              const SizedBox(height: 12),
              Text('Waiting for the others…',
                  style: TextStyle(color: palette.onPanel)),
            ]),
          ),
        PartyStage.roundEnd => _Scoreboard(
            title: 'After round ${_client.round}',
            players: _client.players,
            me: _client.playerId,
            palette: palette,
          ),
        PartyStage.finished => _Scoreboard(
            title: 'Final ranking',
            players: _client.ranking,
            me: _client.playerId,
            palette: palette,
            podium: true,
            footer: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        PartyStage.rejected => _Message(
            switch (_client.rejectReason) {
              PartyReject.started => 'This game has already started.',
              PartyReject.full => 'This room is full.',
              PartyReject.noRoom => 'No room has that code. Check it with '
                  'the host.',
              PartyReject.roomClosed => 'The host closed the room.',
              _ => 'This room uses a newer version of Expat8. Update the app.',
            },
            palette: palette,
          ),
        PartyStage.closed => _Message(
            'The connection to the room was lost.\n\n'
            'Same WiFi? On iPhone, allow Expat8 in Settings › Privacy & '
            'Security › Local Network.',
            palette: palette,
          ),
      };
}

class _Panel extends StatelessWidget {
  const _Panel({required this.palette, required this.child});

  final QuizPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {required this.palette});

  final String text;
  final QuizPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: palette.bad, borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white)),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.palette});

  final String text;
  final QuizPalette palette;

  @override
  Widget build(BuildContext context) => _Panel(
        palette: palette,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.onPanel, fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
        ]),
      );
}

/// Level choice shared by the host's setup and a guest's join form.
class PartyLevelPicker extends StatelessWidget {
  const PartyLevelPicker({
    required this.levels,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<PartyLevelOption> levels;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final level in levels)
            ChoiceChip(
              key: ValueKey('party-level-${level.id}'),
              label: Text(level.label),
              selected: level.id == selected,
              onSelected: (_) => onChanged(level.id),
            ),
        ],
      );
}

class _JoinForm extends StatefulWidget {
  const _JoinForm({
    required this.client,
    required this.defaultName,
    required this.onName,
    required this.palette,
  });

  final PartyClient client;
  final String defaultName;
  final ValueChanged<String>? onName;
  final QuizPalette palette;

  @override
  State<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<_JoinForm> {
  late final _name = TextEditingController(text: widget.defaultName);
  String? _level;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final name = _name.text.trim();
    return SingleChildScrollView(
      child: _Panel(
        palette: widget.palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${client.mode?.title ?? 'Party'} · ${client.subject ?? ''}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('party-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Your name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text('Your level'),
            const SizedBox(height: 8),
            PartyLevelPicker(
              levels: client.levels,
              selected: _level,
              onChanged: (id) => setState(() => _level = id),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('party-join'),
              onPressed: name.isEmpty || _level == null
                  ? null
                  : () {
                      widget.onName?.call(name);
                      client.join(name: name, levelId: _level!);
                    },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.client,
    required this.host,
    required this.roomCode,
    required this.online,
    required this.palette,
  });

  final PartyClient client;
  final PartyHost? host;
  final String? roomCode;
  final bool online;
  final QuizPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final host = this.host;
    return SingleChildScrollView(
      child: _Panel(
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (roomCode case final code?) ...[
              Text(online
                  ? 'Others (anywhere, on the internet): open Games › Play '
                      'together and type this code:'
                  : 'Others: open Games › Play together. This room shows up '
                      'by itself, or type the code:'),
              const SizedBox(height: 8),
              SelectableText(
                code,
                key: const ValueKey('party-room-code'),
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text('Keep this phone on this screen while you play.',
                  textAlign: TextAlign.center, style: textTheme.bodySmall),
              const Divider(height: 28),
            ],
            Text('Players (${client.players.length})',
                style: textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in client.players)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    child: Text(p.name.characters.first.toUpperCase())),
                title:
                    Text(p.id == client.playerId ? '${p.name} (you)' : p.name),
                subtitle: Text(p.level),
              ),
            const SizedBox(height: 12),
            if (host != null)
              FilledButton.icon(
                key: const ValueKey('party-start'),
                onPressed: client.players.length < 2 ? null : host.startGame,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(client.players.length < 2
                    ? 'Waiting for players…'
                    : 'Start ${client.mode?.title ?? ''}'),
              )
            else
              const Text('Waiting for the host to start…',
                  textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.client, required this.palette});

  final PartyClient client;
  final QuizPalette palette;

  @override
  Widget build(BuildContext context) {
    final question = client.question!;
    final left = question.deadline?.difference(DateTime.now()).inMilliseconds;
    final total = question.timeLimit.inMilliseconds;
    // Duel: the last answer's outcome flashes over the next question.
    final previous = client.mode == PartyMode.duel ? client.lastResult : null;
    final me = client.players.where((p) => p.id == client.playerId).firstOrNull;
    return Column(
      children: [
        if (left != null && total > 0)
          LinearProgressIndicator(
            value: (left / total).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: palette.accent,
          ),
        if (client.mode == PartyMode.duel && me != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${me.score} / 10',
                style: TextStyle(
                    color: palette.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
        const Spacer(),
        _Panel(
          palette: palette,
          child: QuizPromptText(question.text, color: palette.onPanel),
        ),
        const SizedBox(height: 12),
        if (previous != null) _ResultLine(previous, palette: palette),
        const Spacer(),
        QuizChoiceButtons(
          theme: GameVisualTheme.space,
          choices: question.choices,
          enabled: !client.isLocked,
          keyPrefix: 'party-choice',
          onPick: (value) => client.answer(question.choices.indexOf(value)),
        ),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine(this.result, {required this.palette});

  final PartyResult result;
  final QuizPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = result.correct ? palette.good : palette.bad;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          result.correct
              ? 'Correct! +${result.points}'
              : 'Answer: ${result.answer}',
          key: const ValueKey('party-result'),
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        if (!result.correct && result.hint != null)
          Text(result.hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text)),
      ],
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.title,
    required this.players,
    required this.me,
    required this.palette,
    this.podium = false,
    this.footer,
  });

  final String title;
  final List<PartyPlayerView> players;
  final String? me;
  final QuizPalette palette;
  final bool podium;
  final Widget? footer;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final ranked = [...players]..sort((a, b) => b.score.compareTo(a.score));
    return SingleChildScrollView(
      child: _Panel(
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final (i, p) in ranked.indexed)
              ListTile(
                key: ValueKey('party-rank-${p.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Text(
                    podium && i < _medals.length ? _medals[i] : '${i + 1}.',
                    style: const TextStyle(fontSize: 24)),
                title: Text(p.id == me ? '${p.name} (you)' : p.name,
                    style: TextStyle(
                        fontWeight:
                            p.id == me ? FontWeight.w800 : FontWeight.w500)),
                subtitle: Text(p.connected ? p.level : '${p.level} · offline'),
                trailing: Text('${p.score}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            if (footer case final footer?) ...[
              const SizedBox(height: 12),
              footer,
            ],
          ],
        ),
      ),
    );
  }
}

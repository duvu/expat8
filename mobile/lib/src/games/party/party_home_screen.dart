import 'dart:async';

import 'package:flutter/material.dart';

import '../../curriculum/skill_answer_sink.dart';
import '../game_storage.dart';
import '../quiz/quiz_core.dart';
import '../quiz/quiz_game_context.dart';
import 'party_client.dart';
import 'party_engine.dart';
import 'party_host.dart';
import 'party_play_screen.dart';
import 'party_protocol.dart';
import 'party_relay_host.dart';
import 'room_address.dart';
import 'room_discovery.dart';

/// Shown when a phone cannot reach a room: the usual causes, including the
/// iPhone's Local Network permission (iOS gives no way to check it).
const partyConnectionHint =
    'Make sure both phones are on the same WiFi. On iPhone, allow Expat8 in '
    'Settings › Privacy & Security › Local Network.';

/// Play together on the same WiFi: host a room on this phone, or join one
/// nearby (found automatically, or by typing its code).
class PartyHomeScreen extends StatefulWidget {
  const PartyHomeScreen({
    required this.storage,
    this.skillSink,
    required this.discovery,
    this.relay,
    super.key,
  });

  final GameStorage storage;

  /// Records the signed-in learner's answers to skill-tagged questions.
  final SkillAnswerSink? skillSink;
  final RoomDiscovery discovery;

  /// The internet relay; null hides online play (no backend configured).
  final PartyRelay? relay;

  @override
  State<PartyHomeScreen> createState() => _PartyHomeScreenState();
}

class _PartyHomeScreenState extends State<PartyHomeScreen> {
  static const _nameKey = 'party.name';

  late final Stream<List<PartyRoom>> _rooms;
  final _code = TextEditingController();
  String _name = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Browsing right away also brings up iOS's Local Network prompt early.
    _rooms = widget.discovery.browse().asBroadcastStream();
    widget.storage.read(_nameKey).then((name) {
      if (mounted && name != null) setState(() => _name = name);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join(PartyClient client, {required String failure}) async {
    if (_busy) return;
    setState(() => _busy = true);
    client.skillSink = widget.skillSink;
    try {
      await client.open();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PartyPlayScreen(
          client: client,
          defaultName: _name,
          onName: _rememberName,
        ),
      ));
    } on Object {
      await client.leave();
      _snack(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _joinLan(RoomAddress address) => _join(PartyClient.lan(address),
      failure: 'Could not reach that room. $partyConnectionHint');

  /// 6 characters: a room on the internet; 10: a room on this WiFi.
  void _joinByCode() {
    final relay = widget.relay;
    final online = parseOnlineRoomCode(_code.text);
    if (online != null && relay != null) {
      _join(relay.client(online),
          failure: 'Could not reach the game server. Check the internet '
              'connection.');
      return;
    }
    final address = RoomAddress.fromCode(_code.text);
    if (address == null) return _snack('That is not a room code.');
    _joinLan(address);
  }

  Future<void> _host() async {
    final setup = await showModalBottomSheet<_HostSetup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HostSetupSheet(
          defaultName: _name, canGoOnline: widget.relay != null),
    );
    if (setup == null || !mounted) return;
    await _rememberName(setup.name);
    final host = PartyHost(
      engine: PartyEngine.forMode(setup.mode),
      subject: setup.subject,
      mode: setup.mode,
      roomName: setup.roomName,
    );
    setState(() => _busy = true);
    try {
      if (setup.online) {
        await _hostOnline(host, setup);
      } else {
        await _hostOnWifi(host, setup);
      }
    } on Object {
      _snack(setup.online
          ? 'Could not open an online room. Check the internet connection.'
          : 'Could not open a room on this phone.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hostOnWifi(PartyHost host, _HostSetup setup) async {
    final lanIp = await localLanAddress();
    if (lanIp == null) {
      return _snack('Connect to WiFi (or turn on a hotspot) to host a party.');
    }
    final server = LanPartyServer(host);
    try {
      await server.start();
      unawaited(widget.discovery
          .advertise(name: setup.roomName, port: server.port, mode: setup.mode)
          .catchError((Object _) {})); // the room code still works
      await _play(
        PartyClient.lan(RoomAddress('127.0.0.1', server.port)),
        host: host,
        setup: setup,
        roomCode: RoomAddress(lanIp, server.port).code,
      );
    } finally {
      await widget.discovery.stopAdvertising().catchError((Object _) {});
      await server.close();
    }
  }

  Future<void> _hostOnline(PartyHost host, _HostSetup setup) async {
    final relay = widget.relay!;
    final room = RelayPartyHost(host, relay);
    try {
      final code = await room.start();
      // Through the relay like everyone else, so speed points stay fair.
      await _play(relay.client(code),
          host: host, setup: setup, roomCode: code, online: true);
    } finally {
      await room.close();
    }
  }

  /// The host's own player: joins the room, then plays until they leave.
  Future<void> _play(
    PartyClient player, {
    required PartyHost host,
    required _HostSetup setup,
    required String roomCode,
    bool online = false,
  }) async {
    player.skillSink = widget.skillSink;
    await player.open();
    player.join(name: setup.name, levelId: setup.level.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PartyPlayScreen(
        client: player,
        host: host,
        roomCode: roomCode,
        online: online,
      ),
    ));
  }

  Future<void> _rememberName(String name) async {
    _name = name;
    await widget.storage.write(_nameKey, name);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Play together')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Everyone on the same WiFi plays on their own phone, each at '
            'their own level.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('party-host'),
            onPressed: _busy ? null : _host,
            icon: const Icon(Icons.wifi_tethering_rounded),
            label: const Text('Host a party on this phone'),
          ),
          const SizedBox(height: 24),
          Text('Rooms nearby', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<PartyRoom>>(
            stream: _rooms,
            builder: (context, snapshot) {
              final rooms = snapshot.data ?? const [];
              if (rooms.isEmpty) {
                return const ListTile(
                  leading: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text('Looking for rooms on this WiFi…'),
                );
              }
              return Column(
                children: [
                  for (final room in rooms)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.groups_rounded),
                        title: Text(room.name),
                        subtitle: Text(room.mode?.title ?? 'Party'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _joinLan(room.address),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Join with a code', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('party-code'),
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Room code',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _joinByCode(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _busy ? null : _joinByCode,
                child: const Text('Join'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(partyConnectionHint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HostSetup {
  const _HostSetup({
    required this.name,
    required this.roomName,
    required this.subject,
    required this.mode,
    required this.level,
    required this.online,
  });

  /// Played over the internet relay instead of this WiFi.
  final bool online;

  final String name;
  final String roomName;
  final QuizSubject subject;
  final PartyMode mode;
  final QuizLevel level;
}

class _HostSetupSheet extends StatefulWidget {
  const _HostSetupSheet({required this.defaultName, required this.canGoOnline});

  final String defaultName;
  final bool canGoOnline;

  @override
  State<_HostSetupSheet> createState() => _HostSetupSheetState();
}

class _HostSetupSheetState extends State<_HostSetupSheet> {
  late final _name = TextEditingController(text: widget.defaultName);
  QuizSubject _subject = QuizSubject.math;
  PartyMode _mode = PartyMode.quizNight;
  late QuizLevel _level = _subject.levels.first;
  bool _online = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New party', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (widget.canGoOnline) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.wifi_rounded),
                    label: Text('This WiFi')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.public_rounded),
                    label: Text('Internet')),
              ],
              selected: {_online},
              onSelectionChanged: (s) => setState(() => _online = s.single),
            ),
            const SizedBox(height: 12),
          ],
          SegmentedButton<PartyMode>(
            segments: [
              for (final mode in PartyMode.values)
                ButtonSegment(value: mode, label: Text(mode.title)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.single),
          ),
          const SizedBox(height: 12),
          SegmentedButton<QuizSubject>(
            segments: [
              for (final subject in QuizSubject.values)
                ButtonSegment(value: subject, label: Text(subject.title)),
            ],
            selected: {_subject},
            onSelectionChanged: (s) => setState(() {
              _subject = s.single;
              _level = _subject.levels.first;
            }),
          ),
          const SizedBox(height: 12),
          PartyLevelPicker(
            levels: [
              for (final l in _subject.levels) PartyLevelOption(l.id, l.label)
            ],
            selected: _level.id,
            onChanged: (id) =>
                setState(() => _level = _subject.levelFromId(id)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('party-create'),
            onPressed: name.isEmpty
                ? null
                : () => Navigator.of(context).pop(_HostSetup(
                      name: name,
                      roomName: "$name's room",
                      subject: _subject,
                      mode: _mode,
                      level: _level,
                      online: _online,
                    )),
            child: const Text('Open the room'),
          ),
        ],
      ),
    );
  }
}

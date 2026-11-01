import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'party_protocol.dart';
import 'room_address.dart';

/// mDNS / Bonjour service type of a party (iOS: must also be listed under
/// NSBonjourServices in Info.plist, or discovery silently finds nothing).
const partyServiceType = '_expat8party._tcp';

/// A party found on the local network.
class PartyRoom {
  const PartyRoom({required this.name, required this.address, this.mode});

  final String name;
  final RoomAddress address;
  final PartyMode? mode;
}

/// Announces a hosted party and finds nearby ones. Behind an interface so the
/// screens can be tested without a network.
abstract interface class RoomDiscovery {
  Future<void> advertise({
    required String name,
    required int port,
    required PartyMode mode,
  });

  Future<void> stopAdvertising();

  /// The rooms currently visible; cancelling the subscription stops looking.
  Stream<List<PartyRoom>> browse();
}

class BonsoirRoomDiscovery implements RoomDiscovery {
  BonsoirBroadcast? _broadcast;

  @override
  Future<void> advertise({
    required String name,
    required int port,
    required PartyMode mode,
  }) async {
    await stopAdvertising();
    final broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: name,
        type: partyServiceType,
        port: port,
        attributes: {'mode': mode.name, 'v': '$partyProtocolVersion'},
      ),
    );
    _broadcast = broadcast;
    await broadcast.initialize();
    await broadcast.start();
  }

  @override
  Future<void> stopAdvertising() async {
    final broadcast = _broadcast;
    _broadcast = null;
    await broadcast?.stop();
  }

  @override
  Stream<List<PartyRoom>> browse() {
    final discovery = BonsoirDiscovery(type: partyServiceType);
    final rooms = <String, PartyRoom>{};
    StreamSubscription<BonsoirDiscoveryEvent>? events;
    late final StreamController<List<PartyRoom>> controller;
    controller = StreamController<List<PartyRoom>>(
      onListen: () async {
        await discovery.initialize();
        events = discovery.eventStream!.listen((event) {
          switch (event) {
            case BonsoirDiscoveryServiceFoundEvent():
              event.service.resolve(discovery.serviceResolver);
            case BonsoirDiscoveryServiceResolvedEvent():
              final room = _roomOf(event.service);
              if (room != null) rooms[event.service.name] = room;
            case BonsoirDiscoveryServiceLostEvent():
              rooms.remove(event.service.name);
            default:
              return;
          }
          controller.add(rooms.values.toList());
        });
        await discovery.start();
      },
      onCancel: () async {
        await events?.cancel();
        await discovery.stop();
      },
    );
    return controller.stream;
  }

  static PartyRoom? _roomOf(BonsoirService service) {
    // Prefer IPv4: the room code and most home routers speak it.
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    final host = service.hostAddresses.where(ipv4.hasMatch).firstOrNull;
    if (host == null || service.attributes['v'] != '$partyProtocolVersion') {
      return null;
    }
    return PartyRoom(
      name: service.name,
      address: RoomAddress(host, service.port),
      mode: PartyMode.values.asNameMap()[service.attributes['mode']],
    );
  }
}

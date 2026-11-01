import 'dart:io';

/// Where a party host listens on the local network.
class RoomAddress {
  const RoomAddress(this.host, this.port);

  final String host;
  final int port;

  // Crockford base32: no I, L, O or U, so a code read aloud is unambiguous.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// A 10-character code ("ABCDE-FGHJK") for typing the room in by hand when
  /// the network hides rooms from discovery. Encodes the IPv4 address and
  /// port (48 bits).
  String get code {
    final parts = host.split('.').map(int.parse).toList();
    var value = 0;
    for (final b in [...parts, port >> 8, port & 0xff]) {
      value = (value << 8) | b;
    }
    // 10 base32 digits = 50 bits; the top two are always zero.
    final raw = [
      for (var i = 0; i < 10; i++) _alphabet[(value >> (45 - 5 * i)) & 0x1f]
    ].join();
    return '${raw.substring(0, 5)}-${raw.substring(5)}';
  }

  /// Parses a typed [code]; tolerant of case, spaces, dashes and the
  /// letters people confuse with digits. Null when it is not a room code.
  static RoomAddress? fromCode(String code) {
    final cleaned = code
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll(RegExp('[IL]'), '1');
    if (cleaned.length != 10) return null;
    var value = 0;
    for (final ch in cleaned.split('')) {
      final digit = _alphabet.indexOf(ch);
      if (digit < 0) return null;
      value = (value << 5) | digit;
    }
    if (value >> 48 != 0) return null;
    final bytes = [for (var i = 5; i >= 0; i--) (value >> (8 * i)) & 0xff];
    final port = (bytes[4] << 8) | bytes[5];
    if (port == 0) return null;
    return RoomAddress(bytes.take(4).join('.'), port);
  }

  @override
  bool operator ==(Object other) =>
      other is RoomAddress && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '$host:$port';
}

/// The IPv4 address other phones on the same WiFi can reach, from
/// (interface name, address) pairs: WiFi and hotspot first, never VPN tunnels
/// or mobile data, which also hand out private addresses.
String? pickLanAddress(List<(String, String)> candidates) {
  bool isPrivate(String ip) =>
      ip.startsWith('192.168.') ||
      ip.startsWith('10.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
  const excluded = ['tun', 'utun', 'ppp', 'ipsec', 'pdp_ip', 'rmnet', 'ccmni'];
  const preferred = ['wlan', 'en0', 'ap', 'swlan', 'bridge', 'eth', 'en'];
  final usable = candidates
      .where((c) => isPrivate(c.$2))
      .where((c) => !excluded.any(c.$1.startsWith))
      .toList();
  for (final prefix in preferred) {
    for (final c in usable) {
      if (c.$1.startsWith(prefix)) return c.$2;
    }
  }
  return usable.isEmpty ? null : usable.first.$2;
}

/// This device's LAN address, or null when it is not on a local network.
Future<String?> localLanAddress() async {
  final interfaces =
      await NetworkInterface.list(type: InternetAddressType.IPv4);
  return pickLanAddress([
    for (final i in interfaces)
      for (final a in i.addresses) (i.name, a.address),
  ]);
}

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has a network connection and calls
/// [onReconnect] when it comes back, so queued offline data syncs promptly.
///
/// A connection does not guarantee the backend is reachable; sync code still
/// treats every request as fallible and keeps data queued on failure.
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor({
    Stream<List<ConnectivityResult>>? changes,
    Future<List<ConnectivityResult>> Function()? check,
  })  : _changes = changes,
        _check = check;

  final Stream<List<ConnectivityResult>>? _changes;
  final Future<List<ConnectivityResult>> Function()? _check;
  final List<VoidCallback> _reconnectListeners = [];
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void onReconnect(VoidCallback listener) => _reconnectListeners.add(listener);

  Future<void> start() async {
    final connectivity =
        (_changes == null || _check == null) ? Connectivity() : null;
    final check = _check ?? connectivity!.checkConnectivity;
    try {
      _update(await check(), notifyReconnect: false);
    } on Object {
      // Platform channel unavailable (tests, unsupported platform): assume
      // online and let requests decide.
    }
    _subscription = (_changes ?? connectivity!.onConnectivityChanged).listen(
      (results) => _update(results, notifyReconnect: true),
      onError: (Object _) {},
    );
  }

  void _update(List<ConnectivityResult> results, {required bool notifyReconnect}) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
    if (online && notifyReconnect) {
      for (final listener in List.of(_reconnectListeners)) {
        listener();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

import 'package:flutter/widgets.dart';

/// Tracks whether a game round is on screen. Periodic background work (sync,
/// log pruning, vocabulary top-ups) runs on the UI isolate and causes visible
/// hitches mid-game, so it checks [isActive] and waits for the next tick.
abstract final class GameActivity {
  static int _active = 0;

  static bool get isActive => _active > 0;

  static void enter() => _active++;

  static void exit() {
    if (_active > 0) _active--;
  }
}

/// Marks its State as an active game round for as long as it is mounted.
mixin GameActivityScope<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    GameActivity.enter();
  }

  @override
  void dispose() {
    GameActivity.exit();
    super.dispose();
  }
}

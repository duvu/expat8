import 'dart:async';

import 'package:flutter/material.dart';

class LearningCardGestureSurface extends StatefulWidget {
  const LearningCardGestureSurface({
    required this.onSwipeRightToLeft,
    required this.onSwipeLeftToRight,
    required this.onSwipeBottomToTop,
    required this.onSwipeTopToBottom,
    required this.child,
    this.isEnabled = true,
    super.key,
  });

  final bool isEnabled;
  final Future<void> Function() onSwipeRightToLeft;
  final Future<void> Function() onSwipeLeftToRight;
  final Future<void> Function() onSwipeBottomToTop;
  final Future<void> Function() onSwipeTopToBottom;
  final Widget child;

  @override
  State<LearningCardGestureSurface> createState() =>
      _LearningCardGestureSurfaceState();
}

class _LearningCardGestureSurfaceState
    extends State<LearningCardGestureSurface> {
  Offset _panDelta = Offset.zero;
  bool _gestureInFlight = false;

  void _dispatchGesture(Future<void> Function() callback) {
    if (_gestureInFlight) {
      return;
    }
    _gestureInFlight = true;
    unawaited(() async {
      try {
        await callback();
      } catch (_) {
        // Gesture failures must not leave the surface permanently disabled.
      } finally {
        _gestureInFlight = false;
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _panDelta = Offset.zero,
      onPanUpdate: (details) {
        _panDelta += details.delta;
      },
      onPanEnd: (details) {
        if (!widget.isEnabled || _gestureInFlight) {
          _panDelta = Offset.zero;
          return;
        }
        final dx = _panDelta.dx;
        final dy = _panDelta.dy;
        final vel = details.velocity.pixelsPerSecond;
        _panDelta = Offset.zero;
        // Determine primary axis from whichever had more movement.
        if (dx.abs() >= dy.abs()) {
          if (vel.dx < -200 || dx < -80) {
            _dispatchGesture(widget.onSwipeRightToLeft);
          } else if (vel.dx > 200 || dx > 80) {
            _dispatchGesture(widget.onSwipeLeftToRight);
          }
        } else {
          if (vel.dy < -200 || dy < -80) {
            _dispatchGesture(widget.onSwipeBottomToTop);
          } else if (vel.dy > 200 || dy > 80) {
            _dispatchGesture(widget.onSwipeTopToBottom);
          }
        }
      },
      child: widget.child,
    );
  }
}

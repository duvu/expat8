import 'dart:async';

import 'package:flutter/material.dart';

/// Direction of the last confirmed swipe, used to animate card transitions.
enum _SlideDirection { none, left, right, up, down }

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
  _SlideDirection _slideDirection = _SlideDirection.none;

  // Unique key per card shown so AnimatedSwitcher detects a change.
  int _cardKey = 0;

  void _dispatchGesture(
      Future<void> Function() callback, _SlideDirection direction) {
    if (_gestureInFlight) {
      return;
    }
    setState(() {
      _gestureInFlight = true;
      _slideDirection = direction;
      _cardKey++;
    });
    unawaited(() async {
      try {
        await callback();
      } catch (_) {
        // Gesture failures must not leave the surface permanently disabled.
      } finally {
        if (mounted) {
          setState(() {
            _gestureInFlight = false;
          });
        }
      }
    }());
  }

  Offset _beginOffset(_SlideDirection direction) {
    return switch (direction) {
      _SlideDirection.left => const Offset(1, 0),
      _SlideDirection.right => const Offset(-1, 0),
      _SlideDirection.up => const Offset(0, 1),
      _SlideDirection.down => const Offset(0, -1),
      _SlideDirection.none => const Offset(1, 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
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
                _dispatchGesture(
                    widget.onSwipeRightToLeft, _SlideDirection.left);
              } else if (vel.dx > 200 || dx > 80) {
                _dispatchGesture(
                    widget.onSwipeLeftToRight, _SlideDirection.right);
              }
            } else {
              if (vel.dy < -200 || dy < -80) {
                _dispatchGesture(
                    widget.onSwipeBottomToTop, _SlideDirection.up);
              } else if (vel.dy > 200 || dy > 80) {
                _dispatchGesture(
                    widget.onSwipeTopToBottom, _SlideDirection.down);
              }
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              final begin = _beginOffset(_slideDirection);
              return SlideTransition(
                position: Tween<Offset>(
                  begin: begin,
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_cardKey),
              child: widget.child,
            ),
          ),
        ),
        // Loading overlay: thin progress bar at top when a gesture is in flight.
        if (_gestureInFlight)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }
}

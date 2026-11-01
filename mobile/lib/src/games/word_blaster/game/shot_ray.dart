import 'dart:math';
import 'dart:ui';

/// Straight-line aiming for Word Blaster: a tap sets the direction of the
/// shot (from the cannon through the touched point), and the shot hits the
/// first meteor on that line.

/// The barrel's swing: upward only, never flat.
const minAim = -pi + 0.25;
const maxAim = -0.25;

/// Direction in radians from [cannon] through [tap], limited to the barrel's
/// swing. A tap below the cannon fires along the nearest shallow angle.
double aimAngle(Offset cannon, Offset tap) {
  final angle = atan2(tap.dy - cannon.dy, tap.dx - cannon.dx);
  if (angle >= 0) return angle > pi / 2 ? minAim : maxAim;
  return angle.clamp(minAim, maxAim);
}

/// Distance along a shot from [origin] at [angle] to where it first enters
/// [box] (0 when it starts inside), or null when it never does.
double? shotEntry(Offset origin, double angle, Rect box) {
  final direction = Offset(cos(angle), sin(angle));
  var near = 0.0;
  var far = double.infinity;
  for (final (start, step, low, high) in [
    (origin.dx, direction.dx, box.left, box.right),
    (origin.dy, direction.dy, box.top, box.bottom),
  ]) {
    if (step.abs() < 1e-9) {
      // Parallel to this pair of edges: inside the slab or never.
      if (start < low || start > high) return null;
      continue;
    }
    final a = (low - start) / step;
    final b = (high - start) / step;
    near = max(near, min(a, b));
    far = min(far, max(a, b));
    if (near > far) return null;
  }
  return near;
}

/// The first of [boxes] the shot crosses (the nearest one wins, so a meteor
/// in front shields the ones behind it), with the distance to it.
({T item, double distance})? firstHit<T>(
    Offset origin, double angle, Iterable<(T, Rect)> boxes) {
  ({T item, double distance})? best;
  for (final (item, box) in boxes) {
    final distance = shotEntry(origin, angle, box);
    if (distance != null && (best == null || distance < best.distance)) {
      best = (item: item, distance: distance);
    }
  }
  return best;
}

/// Where a shot from [origin] at [angle] leaves the rectangle (0,0)–[field].
Offset shotExit(Offset origin, double angle, Size field) {
  final direction = Offset(cos(angle), sin(angle));
  var t = double.infinity;
  if (direction.dx > 1e-9) t = min(t, (field.width - origin.dx) / direction.dx);
  if (direction.dx < -1e-9) t = min(t, -origin.dx / direction.dx);
  if (direction.dy > 1e-9) {
    t = min(t, (field.height - origin.dy) / direction.dy);
  }
  if (direction.dy < -1e-9) t = min(t, -origin.dy / direction.dy);
  return origin + direction * max(0, t);
}

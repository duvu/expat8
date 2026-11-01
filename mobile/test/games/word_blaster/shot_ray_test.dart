import 'dart:math';
import 'dart:ui';

import 'package:expat8_language_app/src/games/word_blaster/game/shot_ray.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cannon = Offset(200, 800);

  group('aimAngle', () {
    test('points from the cannon through the touch', () {
      expect(aimAngle(cannon, const Offset(200, 400)), closeTo(-pi / 2, 1e-9));
      expect(aimAngle(cannon, const Offset(300, 700)), closeTo(-pi / 4, 1e-9));
      expect(
          aimAngle(cannon, const Offset(100, 700)), closeTo(-3 * pi / 4, 1e-9));
    });

    test('never flatter than the barrel can swing, even below the cannon', () {
      expect(aimAngle(cannon, const Offset(400, 799)), maxAim);
      expect(aimAngle(cannon, const Offset(0, 799)), minAim);
      expect(aimAngle(cannon, const Offset(380, 900)), maxAim);
      expect(aimAngle(cannon, const Offset(20, 900)), minAim);
    });
  });

  group('shotEntry', () {
    final box =
        Rect.fromCenter(center: const Offset(200, 400), width: 80, height: 40);

    test('hits a box straight ahead where the line enters it', () {
      expect(shotEntry(cannon, -pi / 2, box), closeTo(380, 1e-9));
    });

    test('hits when the line only crosses a corner region, misses beside it',
        () {
      // Toward the box centre from the side.
      final toCentre = atan2(400 - 800, 200 - 100);
      expect(shotEntry(const Offset(100, 800), toCentre, box), isNotNull);
      // Parallel and well to the side of the box.
      expect(shotEntry(const Offset(100, 800), -pi / 2, box), isNull);
      // Pointing away from the box.
      expect(shotEntry(cannon, 0, box), isNull);
    });

    test('is 0 when the shot starts inside', () {
      expect(shotEntry(const Offset(200, 400), -pi / 2, box), 0);
    });
  });

  group('firstHit', () {
    test('the nearest box shields the ones behind it', () {
      final near = Rect.fromCenter(
          center: const Offset(200, 600), width: 60, height: 40);
      final far = Rect.fromCenter(
          center: const Offset(200, 300), width: 60, height: 40);
      final hit = firstHit(cannon, -pi / 2, [('far', far), ('near', near)]);
      expect(hit!.item, 'near');
      expect(hit.distance, closeTo(180, 1e-9));
    });

    test('a line through no box hits nothing', () {
      final box =
          Rect.fromCenter(center: const Offset(50, 300), width: 60, height: 40);
      expect(firstHit(cannon, -pi / 2, [('a', box)]), isNull);
      expect(firstHit<String>(cannon, -pi / 2, const []), isNull);
    });
  });

  test('a missed shot leaves the field through the top or a side', () {
    const field = Size(400, 900);
    final up = shotExit(cannon, -pi / 2, field);
    expect(up.dx, closeTo(200, 1e-9));
    expect(up.dy, closeTo(0, 1e-9));
    final shallow = shotExit(cannon, maxAim, field);
    expect(shallow.dx, closeTo(400, 1e-9));
    expect(shallow.dy, greaterThan(0));
  });
}

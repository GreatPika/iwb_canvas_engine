import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('rotatePoint rotates around center', () {
    const center = Offset.zero;
    const point = Offset(1, 0);
    final rotated = rotatePoint(point, center, 90);
    expect(rotated.dx, closeTo(0, 0.0001));
    expect(rotated.dy, closeTo(1, 0.0001));
  });

  test('reflectPointVertical mirrors around axis', () {
    const point = Offset(2, 3);
    final mirrored = reflectPointVertical(point, 0);
    expect(mirrored.dx, -2);
    expect(mirrored.dy, 3);
  });

  test('aabbFromPoints builds bounds', () {
    final rect = aabbFromPoints(
      const [Offset(1, 2), Offset(4, -1), Offset(-2, 3)],
    );
    expect(rect.left, -2);
    expect(rect.top, -1);
    expect(rect.right, 4);
    expect(rect.bottom, 3);
  });

  test('aabbForTransformedRect handles rotation', () {
    final local = Rect.fromCenter(center: Offset.zero, width: 2, height: 4);
    final aabb = aabbForTransformedRect(
      localRect: local,
      position: const Offset(10, 10),
      rotationDeg: 90,
      scaleX: 1,
      scaleY: 1,
    );
    expect(aabb.center.dx, closeTo(10, 0.0001));
    expect(aabb.center.dy, closeTo(10, 0.0001));
    expect(aabb.width, closeTo(4, 0.0001));
    expect(aabb.height, closeTo(2, 0.0001));
  });

  test('camera transforms invert each other', () {
    const camera = Offset(5, -3);
    const view = Offset(10, 20);
    final scene = toScene(view, camera);
    final back = toView(scene, camera);
    expect(back.dx, view.dx);
    expect(back.dy, view.dy);
  });

  test('hitTestLine respects thickness', () {
    const start = Offset(0, 0);
    const end = Offset(10, 0);
    final hit = hitTestLine(const Offset(5, 1), start, end, 4);
    final miss = hitTestLine(const Offset(5, 3), start, end, 4);
    expect(hit, isTrue);
    expect(miss, isFalse);
  });

  test('hitTestStroke finds points near polyline', () {
    final points = [
      const Offset(0, 0),
      const Offset(10, 0),
      const Offset(10, 10),
    ];
    final hit = hitTestStroke(const Offset(9, 1), points, 4);
    final miss = hitTestStroke(const Offset(20, 20), points, 4);
    expect(hit, isTrue);
    expect(miss, isFalse);
  });
}

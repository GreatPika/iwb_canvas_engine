import 'dart:ui';
import 'dart:math' as math;

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

  test('reflectPointHorizontal mirrors around axis', () {
    const point = Offset(2, 3);
    final mirrored = reflectPointHorizontal(point, 10);
    expect(mirrored.dx, 2);
    expect(mirrored.dy, 17);
  });

  test('reflectPointHorizontal is an involution (property)', () {
    final rnd = math.Random(1337);
    for (var i = 0; i < 100; i++) {
      final axisY = rnd.nextDouble() * 200 - 100;
      final point = Offset(
        rnd.nextDouble() * 200 - 100,
        rnd.nextDouble() * 200 - 100,
      );
      final reflected = reflectPointHorizontal(point, axisY);
      final back = reflectPointHorizontal(reflected, axisY);

      expect(back.dx, closeTo(point.dx, 1e-9));
      expect(back.dy, closeTo(point.dy, 1e-9));

      expect(reflected.dx, closeTo(point.dx, 1e-9));
      expect((point.dy + reflected.dy) / 2.0, closeTo(axisY, 1e-9));
    }
  });

  test('aabbFromPoints builds bounds', () {
    final rect = aabbFromPoints(const [
      Offset(1, 2),
      Offset(4, -1),
      Offset(-2, 3),
    ]);
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

  test('hitTestStroke supports single-point strokes', () {
    final points = [const Offset(0, 0)];
    expect(hitTestStroke(const Offset(6, 0), points, 4), isTrue);
    expect(hitTestStroke(const Offset(7, 0), points, 4), isFalse);
  });

  test('hitTestStroke applies hitPadding in addition to kHitSlop', () {
    final points = [const Offset(0, 0)];
    expect(hitTestStroke(const Offset(5, 0), points, 0), isFalse);
    expect(hitTestStroke(const Offset(5, 0), points, 0, hitPadding: 2), isTrue);
  });

  test('hitTestRect uses rect bounds', () {
    const rect = Rect.fromLTWH(0, 0, 10, 20);
    expect(hitTestRect(const Offset(5, 5), rect), isTrue);
    expect(hitTestRect(const Offset(-1, 5), rect), isFalse);
  });

  test('hitTestNode uses local bounds for rotated RectNode', () {
    final node = RectNode(id: 'rect-rot', size: const Size(100, 20))
      ..position = const Offset(100, 100)
      ..rotationDeg = 45;

    final aabbOnlyPoint = node.boundsWorld.topLeft + const Offset(1, 1);
    expect(hitTestNode(aabbOnlyPoint, node), isFalse);
    expect(hitTestNode(node.position, node), isTrue);

    final localOutside = Offset(node.size.width / 2 + kHitSlop + 0.5, 0);
    final worldOutside = node.transform.applyToPoint(localOutside);
    expect(hitTestNode(worldOutside, node), isFalse);
    node.hitPadding = 1;
    expect(hitTestNode(worldOutside, node), isTrue);
  });

  test('hitTestNode uses local bounds for rotated ImageNode', () {
    final node =
        ImageNode(id: 'image-rot', imageId: 'img-1', size: const Size(120, 60))
          ..position = const Offset(-20, 40)
          ..rotationDeg = 30;

    final aabbOnlyPoint = node.boundsWorld.topLeft + const Offset(1, 1);
    expect(hitTestNode(aabbOnlyPoint, node), isFalse);
    expect(hitTestNode(node.position, node), isTrue);

    final localOutside = Offset(node.size.width / 2 + kHitSlop + 0.5, 0);
    final worldOutside = node.transform.applyToPoint(localOutside);
    expect(hitTestNode(worldOutside, node), isFalse);
    node.hitPadding = 1;
    expect(hitTestNode(worldOutside, node), isTrue);
  });

  test('hitTestNode uses local bounds for rotated TextNode', () {
    final node =
        TextNode(
            id: 'text-rot',
            text: 'Hello',
            size: const Size(90, 40),
            color: const Color(0xFF000000),
          )
          ..position = const Offset(10, -50)
          ..rotationDeg = -60;

    final aabbOnlyPoint = node.boundsWorld.topLeft + const Offset(1, 1);
    expect(hitTestNode(aabbOnlyPoint, node), isFalse);
    expect(hitTestNode(node.position, node), isTrue);

    final localOutside = Offset(node.size.width / 2 + kHitSlop + 0.5, 0);
    final worldOutside = node.transform.applyToPoint(localOutside);
    expect(hitTestNode(worldOutside, node), isFalse);
    node.hitPadding = 1;
    expect(hitTestNode(worldOutside, node), isTrue);
  });

  test('hitTestNode uses kHitSlop in scene units for scaled RectNode', () {
    final node = RectNode(id: 'rect-scale', size: const Size(10, 10))
      ..position = Offset.zero
      ..scaleX = 0.1
      ..scaleY = 0.1;

    final rightEdge = node.transform.applyToPoint(
      Offset(node.size.width / 2, 0),
    );
    expect(hitTestNode(rightEdge + Offset(kHitSlop - 0.1, 0), node), isTrue);
    expect(hitTestNode(rightEdge + Offset(kHitSlop + 0.1, 0), node), isFalse);

    node
      ..scaleX = 3
      ..scaleY = 3;

    final scaledRightEdge = node.transform.applyToPoint(
      Offset(node.size.width / 2, 0),
    );
    expect(
      hitTestNode(scaledRightEdge + Offset(kHitSlop - 0.1, 0), node),
      isTrue,
    );
    expect(
      hitTestNode(scaledRightEdge + Offset(kHitSlop + 0.1, 0), node),
      isFalse,
    );
  });

  test('hitTestNode respects PathNode shape and transforms', () {
    final node =
        PathNode(
            id: 'path-1',
            svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
            fillColor: const Color(0xFF000000),
            fillRule: PathFillRule.evenOdd,
          )
          ..position = const Offset(100, 100)
          ..rotationDeg = 90
          ..scaleX = 2
          ..scaleY = 0.5;

    final holePoint = node.position;
    expect(hitTestNode(holePoint, node), isFalse);

    final localHit = const Offset(-15, 0);
    final scaled = Offset(localHit.dx * node.scaleX, localHit.dy * node.scaleY);
    final rotated = rotatePoint(scaled, Offset.zero, node.rotationDeg);
    final worldHit = rotated + node.position;
    expect(hitTestNode(worldHit, node), isTrue);
  });

  test('hitTestNode allows coarse hits for stroke-only PathNode (stage A)', () {
    final node = PathNode(
      id: 'path-stroke-only',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2,
    )..position = const Offset(100, 100);
    expect(hitTestNode(node.position, node), isTrue);
  });

  test('stroke-only PathNode hit-test accounts for node scale (stage A)', () {
    final node =
        PathNode(
            id: 'path-stroke-scale',
            svgPathData: 'M0 0 H40 V30 H0 Z',
            strokeColor: const Color(0xFF000000),
            strokeWidth: 10,
          )
          ..position = Offset.zero
          ..scaleX = 2
          ..scaleY = 2;

    expect(hitTestNode(const Offset(52, 0), node), isTrue);
  });

  test('distancePointToSegment handles degenerate segments', () {
    const point = Offset(3, 4);
    const a = Offset(1, 1);
    final distance = distancePointToSegment(point, a, a);
    expect(distance, closeTo((point - a).distance, 0.0001));
  });

  test('segmentsIntersect handles colinear overlaps', () {
    expect(
      segmentsIntersect(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(5, 0),
        const Offset(15, 0),
      ),
      isTrue,
    );
  });

  test(
    'distanceSegmentToSegment returns positive distance for parallel lines',
    () {
      final distance = distanceSegmentToSegment(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(0, 5),
        const Offset(10, 5),
      );
      expect(distance, closeTo(5, 0.0001));
    },
  );
}

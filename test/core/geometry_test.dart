import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

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

  test('hitTestLine clamps negative thickness to zero', () {
    // INV:INV-CORE-NONNEGATIVE-WIDTHS-CLAMP
    const start = Offset(0, 0);
    const end = Offset(10, 0);

    const onLine = Offset(5, 0);
    expect(
      hitTestLine(onLine, start, end, -5),
      hitTestLine(onLine, start, end, 0),
    );
    expect(hitTestLine(onLine, start, end, -5), isTrue);

    const offLine = Offset(5, 1);
    expect(
      hitTestLine(offLine, start, end, -5),
      hitTestLine(offLine, start, end, 0),
    );
    expect(hitTestLine(offLine, start, end, -5), isFalse);
  });

  test('hitTestLine/hitTestStroke sanitize non-finite numeric inputs', () {
    // INV:INV-CORE-RUNTIME-NUMERIC-SANITIZATION
    // INV:INV-CORE-NONNEGATIVE-WIDTHS-CLAMP
    const start = Offset(0, 0);
    const end = Offset(10, 0);
    const onLine = Offset(5, 0);
    const offLine = Offset(5, 1);

    expect(
      hitTestLine(onLine, start, end, double.nan),
      hitTestLine(onLine, start, end, 0),
    );
    expect(
      hitTestLine(offLine, start, end, double.infinity),
      hitTestLine(offLine, start, end, 0),
    );

    final points = [const Offset(0, 0)];
    expect(
      hitTestStroke(onLine, points, double.nan),
      hitTestStroke(onLine, points, 0),
    );
    expect(
      hitTestStroke(onLine, points, 0, hitPadding: double.infinity),
      hitTestStroke(onLine, points, 0, hitPadding: 0),
    );
    expect(
      hitTestStroke(onLine, points, 0, hitPadding: double.nan),
      hitTestStroke(onLine, points, 0, hitPadding: 0),
    );
    expect(
      hitTestStroke(onLine, points, 0, hitSlop: double.nan),
      hitTestStroke(onLine, points, 0, hitSlop: kHitSlop),
    );
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

  test('hitTestNode rejects nodes with non-finite transform', () {
    final node = RectNode(id: 'rect-non-finite', size: const Size(10, 10));
    node.transform = Transform2D(a: double.nan, b: 0, c: 0, d: 1, tx: 0, ty: 0);
    expect(node.boundsWorld, Rect.zero);
    expect(hitTestNode(Offset.zero, node), isFalse);
    expect(hitTestNode(const Offset(1, 1), node), isFalse);
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

  test('hitTestTopNode skips background layers', () {
    // INV:INV-CORE-HITTEST-TOP-SKIPS-BACKGROUND
    final foreground = RectNode(
      id: 'fg',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    );
    final background = RectNode(
      id: 'bg',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    );

    final scene = Scene(
      layers: [
        Layer(nodes: [foreground]),
        Layer(nodes: [background], isBackground: true),
      ],
    );

    final hit = hitTestTopNode(scene, Offset.zero);
    expect(hit?.id, 'fg');
    expect(hitTestNode(Offset.zero, background), isTrue);
  });

  test('hitTestTopNode returns null when only background layers are hit', () {
    // INV:INV-CORE-HITTEST-TOP-SKIPS-BACKGROUND
    final background = RectNode(
      id: 'bg-only',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [background], isBackground: true),
      ],
    );

    expect(hitTestTopNode(scene, Offset.zero), isNull);
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

  test(
    'hitTestNode falls back to world AABB for non-invertible transforms',
    () {
      // INV:INV-CORE-HITTEST-FALLBACK-INFLATED-AABB
      final node = RectNode(id: 'rect-singular', size: const Size(100, 40))
        ..transform = const Transform2D(
          a: 1,
          b: 2,
          c: 1,
          d: 2,
          tx: 100,
          ty: -50,
        );

      expect(node.transform.invert(), isNull);

      final point = node.boundsWorld.center;
      expect(hitTestNode(point, node), isTrue);

      final paddingInside = Offset(
        node.boundsWorld.right + kHitSlop - 0.1,
        node.boundsWorld.center.dy,
      );
      expect(hitTestNode(paddingInside, node), isTrue);
      final paddingOutside = Offset(
        node.boundsWorld.right + kHitSlop + 0.1,
        node.boundsWorld.center.dy,
      );
      expect(hitTestNode(paddingOutside, node), isFalse);

      final line = LineNode(
        id: 'line-singular',
        start: const Offset(0, 0),
        end: const Offset(10, 0),
        thickness: 0,
        color: const Color(0xFF000000),
      )..transform = node.transform;
      expect(line.transform.invert(), isNull);
      final lineInside = Offset(
        line.boundsWorld.right + kHitSlop - 0.1,
        line.boundsWorld.center.dy,
      );
      expect(hitTestNode(lineInside, line), isTrue);
      final lineOutside = Offset(
        line.boundsWorld.right + kHitSlop + 0.1,
        line.boundsWorld.center.dy,
      );
      expect(hitTestNode(lineOutside, line), isFalse);

      final lineNeg = LineNode(
        id: 'line-singular-neg',
        start: const Offset(0, 0),
        end: const Offset(10, 0),
        thickness: -1,
        color: const Color(0xFF000000),
      )..transform = node.transform;
      expect(lineNeg.transform.invert(), isNull);
      final lineNegInside = Offset(
        lineNeg.boundsWorld.right + kHitSlop - 0.1,
        lineNeg.boundsWorld.center.dy,
      );
      expect(hitTestNode(lineNegInside, lineNeg), isTrue);
      final lineNegOutside = Offset(
        lineNeg.boundsWorld.right + kHitSlop + 0.1,
        lineNeg.boundsWorld.center.dy,
      );
      expect(hitTestNode(lineNegOutside, lineNeg), isFalse);

      final stroke = StrokeNode(
        id: 'stroke-singular',
        points: const <Offset>[Offset(0, 0), Offset(10, 0)],
        thickness: 0,
        color: const Color(0xFF000000),
      )..transform = node.transform;
      expect(stroke.transform.invert(), isNull);
      final strokeInside = Offset(
        stroke.boundsWorld.right + kHitSlop - 0.1,
        stroke.boundsWorld.center.dy,
      );
      expect(hitTestNode(strokeInside, stroke), isTrue);
      final strokeOutside = Offset(
        stroke.boundsWorld.right + kHitSlop + 0.1,
        stroke.boundsWorld.center.dy,
      );
      expect(hitTestNode(strokeOutside, stroke), isFalse);

      final strokeNeg = StrokeNode(
        id: 'stroke-singular-neg',
        points: const <Offset>[Offset(0, 0), Offset(10, 0)],
        thickness: -1,
        color: const Color(0xFF000000),
      )..transform = node.transform;
      expect(strokeNeg.transform.invert(), isNull);
      final strokeNegInside = Offset(
        strokeNeg.boundsWorld.right + kHitSlop - 0.1,
        strokeNeg.boundsWorld.center.dy,
      );
      expect(hitTestNode(strokeNegInside, strokeNeg), isTrue);
      final strokeNegOutside = Offset(
        strokeNeg.boundsWorld.right + kHitSlop + 0.1,
        strokeNeg.boundsWorld.center.dy,
      );
      expect(hitTestNode(strokeNegOutside, strokeNeg), isFalse);

    },
  );

  test('PathNode fill hit-test requires invertible transform', () {
    // INV:INV-CORE-PATH-HITTEST-FILL-REQUIRES-INVERSE
    const singular = Transform2D(
      a: 1,
      b: 2,
      c: 1,
      d: 2,
      tx: 100,
      ty: -50,
    );

    final fillOnly = PathNode(
      id: 'path-singular-fill-only',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      fillColor: const Color(0xFF000000),
    )..transform = singular;
    expect(fillOnly.transform.invert(), isNull);
    final fillOnlyInsideAabb = Offset(
      fillOnly.boundsWorld.right + kHitSlop - 0.1,
      fillOnly.boundsWorld.center.dy,
    );
    expect(hitTestNode(fillOnlyInsideAabb, fillOnly), isFalse);

    final strokeOnly = PathNode(
      id: 'path-singular-stroke-only',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 4,
    )..transform = singular;
    expect(strokeOnly.transform.invert(), isNull);
    final strokeOnlyInsideAabb = Offset(
      strokeOnly.boundsWorld.right + kHitSlop - 0.1,
      strokeOnly.boundsWorld.center.dy,
    );
    expect(hitTestNode(strokeOnlyInsideAabb, strokeOnly), isTrue);

    final fillAndStroke = PathNode(
      id: 'path-singular-fill-and-stroke',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      fillColor: const Color(0xFF000000),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 4,
    )..transform = singular;
    expect(fillAndStroke.transform.invert(), isNull);
    final fillAndStrokeInsideAabb = Offset(
      fillAndStroke.boundsWorld.right + kHitSlop - 0.1,
      fillAndStroke.boundsWorld.center.dy,
    );
    expect(hitTestNode(fillAndStrokeInsideAabb, fillAndStroke), isTrue);

    final fillAndZeroStroke = PathNode(
      id: 'path-singular-fill-and-zero-stroke',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      fillColor: const Color(0xFF000000),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0,
    )..transform = singular;
    expect(fillAndZeroStroke.transform.invert(), isNull);
    final fillAndZeroStrokeInsideAabb = Offset(
      fillAndZeroStroke.boundsWorld.right + kHitSlop - 0.1,
      fillAndZeroStroke.boundsWorld.center.dy,
    );
    expect(hitTestNode(fillAndZeroStrokeInsideAabb, fillAndZeroStroke), isFalse);
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

  test('PathNode hit-test selects union of fill and stroke (stage A)', () {
    // INV:INV-CORE-PATH-HITTEST-FILL-OR-STROKE
    final node = PathNode(
      id: 'path-fill-stroke',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      fillColor: const Color(0xFF000000),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 10,
    );

    expect(hitTestNode(Offset.zero, node), isTrue);

    // Outside fill (x > 20), but within the stroke band.
    expect(hitTestNode(const Offset(21, 0), node), isTrue);

    final outside = Offset(
      node.boundsWorld.right + kHitSlop + 0.1,
      node.boundsWorld.center.dy,
    );
    expect(hitTestNode(outside, node), isFalse);
  });

  test(
    'PathNode stroke-only hit-test does not double-count strokeWidth in AABB padding',
    () {
      // INV:INV-CORE-PATH-HITTEST-STROKE-NO-DOUBLECOUNT
      final node = PathNode(
        id: 'path-stroke-only',
        svgPathData: 'M0 0 H40 V30 H0 Z',
        strokeColor: const Color(0xFF000000),
        strokeWidth: 10,
      );

      final inside = Offset(
        node.boundsWorld.right + kHitSlop - 0.1,
        node.boundsWorld.center.dy,
      );
      expect(hitTestNode(inside, node), isTrue);

      final outside = Offset(
        node.boundsWorld.right + kHitSlop + 0.1,
        node.boundsWorld.center.dy,
      );
      expect(hitTestNode(outside, node), isFalse);

      final padded = PathNode(
        id: 'path-stroke-only-padded',
        svgPathData: 'M0 0 H40 V30 H0 Z',
        strokeColor: const Color(0xFF000000),
        strokeWidth: 10,
        hitPadding: 7,
      );

      final insidePadded = Offset(
        padded.boundsWorld.right + padded.hitPadding + kHitSlop - 0.1,
        padded.boundsWorld.center.dy,
      );
      expect(hitTestNode(insidePadded, padded), isTrue);

      final outsidePadded = Offset(
        padded.boundsWorld.right + padded.hitPadding + kHitSlop + 0.1,
        padded.boundsWorld.center.dy,
      );
      expect(hitTestNode(outsidePadded, padded), isFalse);
    },
  );

  test('PathNode hit-test clamps negative strokeWidth to zero', () {
    // INV:INV-CORE-NONNEGATIVE-WIDTHS-CLAMP
    final nodeNeg = PathNode(
      id: 'path-stroke-neg',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      strokeColor: const Color(0xFF000000),
      strokeWidth: -10,
    );
    final nodeZero = PathNode(
      id: 'path-stroke-zero',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0,
    );

    final pointInside = Offset(
      nodeNeg.boundsWorld.right + kHitSlop - 0.1,
      nodeNeg.boundsWorld.center.dy,
    );
    final pointOutside = Offset(
      nodeNeg.boundsWorld.right + kHitSlop + 0.1,
      nodeNeg.boundsWorld.center.dy,
    );
    expect(
      hitTestNode(pointInside, nodeNeg),
      hitTestNode(pointInside, nodeZero),
    );
    expect(
      hitTestNode(pointOutside, nodeNeg),
      hitTestNode(pointOutside, nodeZero),
    );
  });

  test(
    'hitTestNode applies kHitSlop/hitPadding for LineNode (scene units)',
    () {
      // INV:INV-CORE-LINE-HITPADDING-SLOP-SCENE
      final line = LineNode(
        id: 'line-hit',
        start: const Offset(0, 0),
        end: const Offset(10, 0),
        thickness: 0,
        color: const Color(0xFF000000),
      );

      final mid = line.transform.applyToPoint(const Offset(5, 0));
      expect(hitTestNode(mid + Offset(0, kHitSlop - 0.1), line), isTrue);
      expect(hitTestNode(mid + Offset(0, kHitSlop + 0.1), line), isFalse);

      line.hitPadding = 3;
      expect(hitTestNode(mid + Offset(0, 3 + kHitSlop - 0.1), line), isTrue);
      expect(hitTestNode(mid + Offset(0, 3 + kHitSlop + 0.1), line), isFalse);
    },
  );

  test('hitTestNode LineNode slop is stable under scale', () {
    final line = LineNode(
      id: 'line-scale',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 0,
      color: const Color(0xFF000000),
    );

    line
      ..scaleX = 0.5
      ..scaleY = 0.5;
    final mid05 = line.transform.applyToPoint(const Offset(5, 0));
    expect(hitTestNode(mid05 + Offset(0, kHitSlop - 0.1), line), isTrue);
    expect(hitTestNode(mid05 + Offset(0, kHitSlop + 0.1), line), isFalse);

    line
      ..scaleX = 2.0
      ..scaleY = 2.0;
    final mid2 = line.transform.applyToPoint(const Offset(5, 0));
    expect(hitTestNode(mid2 + Offset(0, kHitSlop - 0.1), line), isTrue);
    expect(hitTestNode(mid2 + Offset(0, kHitSlop + 0.1), line), isFalse);
  });

  test('hitTestNode StrokeNode slop is stable under scale', () {
    // INV:INV-CORE-STROKE-HITPADDING-SLOP-SCENE
    final stroke = StrokeNode(
      id: 'stroke-scale',
      points: const <Offset>[Offset(0, 0), Offset(10, 0)],
      thickness: 0,
      color: const Color(0xFF000000),
    );

    stroke
      ..scaleX = 0.5
      ..scaleY = 0.5;
    final mid05 = stroke.transform.applyToPoint(const Offset(5, 0));
    expect(hitTestNode(mid05 + Offset(0, kHitSlop - 0.1), stroke), isTrue);
    expect(hitTestNode(mid05 + Offset(0, kHitSlop + 0.1), stroke), isFalse);

    stroke
      ..scaleX = 2.0
      ..scaleY = 2.0;
    final mid2 = stroke.transform.applyToPoint(const Offset(5, 0));
    expect(hitTestNode(mid2 + Offset(0, kHitSlop - 0.1), stroke), isTrue);
    expect(hitTestNode(mid2 + Offset(0, kHitSlop + 0.1), stroke), isFalse);

    stroke
      ..scaleX = 2.0
      ..scaleY = 0.5;
    final midNonUniform = stroke.transform.applyToPoint(const Offset(5, 0));
    expect(
      hitTestNode(midNonUniform + Offset(0, kHitSlop - 0.1), stroke),
      isTrue,
    );
    expect(
      hitTestNode(midNonUniform + Offset(0, kHitSlop + 0.1), stroke),
      isFalse,
    );
  });

  test(
    'hitTestNode applies hitPadding + kHitSlop for StrokeNode (scene units)',
    () {
      final stroke = StrokeNode(
        id: 'stroke-padding',
        points: const <Offset>[Offset(0, 0), Offset(10, 0)],
        thickness: 0,
        color: const Color(0xFF000000),
      )..hitPadding = 3;

      stroke
        ..scaleX = 2
        ..scaleY = 0.5;
      final mid = stroke.transform.applyToPoint(const Offset(5, 0));
      final total = 3 + kHitSlop;
      expect(hitTestNode(mid + Offset(0, total - 0.1), stroke), isTrue);
      expect(hitTestNode(mid + Offset(0, total + 0.1), stroke), isFalse);
    },
  );

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

  test(
    'invalid PathNode is non-interactive for stroke-only, fill-only, and fill+stroke',
    () {
      // INV:INV-CORE-PATH-HITTEST-INVALID-NONINTERACTIVE
      final strokeOnly = PathNode(
        id: 'path-invalid-stroke',
        svgPathData: 'not-a-path',
        strokeColor: const Color(0xFF000000),
        strokeWidth: 8,
      );
      final fillOnly = PathNode(
        id: 'path-invalid-fill',
        svgPathData: 'not-a-path',
        fillColor: const Color(0xFF000000),
      );
      final fillAndStroke = PathNode(
        id: 'path-invalid-fill-stroke',
        svgPathData: 'not-a-path',
        fillColor: const Color(0xFF000000),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 8,
      );

      final probeStrokeOnly =
          strokeOnly.boundsWorld.topLeft + const Offset(1, 1);
      final probeFillOnly = fillOnly.boundsWorld.topLeft + const Offset(1, 1);
      final probeFillAndStroke =
          fillAndStroke.boundsWorld.topLeft + const Offset(1, 1);
      expect(hitTestNode(probeStrokeOnly, strokeOnly), isFalse);
      expect(hitTestNode(probeFillOnly, fillOnly), isFalse);
      expect(hitTestNode(probeFillAndStroke, fillAndStroke), isFalse);
    },
  );

  test('distancePointToSegment handles degenerate segments', () {
    const point = Offset(3, 4);
    const a = Offset(1, 1);
    final distance = distancePointToSegment(point, a, a);
    expect(distance, closeTo((point - a).distance, 0.0001));
  });

  test('distancePointToSegment handles almost-degenerate segments', () {
    const point = Offset(0, 1);
    const a = Offset(0, 0);
    const b = Offset(1e-12, 0);
    final distance = distancePointToSegment(point, a, b);
    expect(distance.isFinite, isTrue);
    expect(distance, closeTo(1.0, 1e-6));

    const nearA = Offset(1e-13, 0);
    final distanceNearA = distancePointToSegment(nearA, a, b);
    expect(distanceNearA.isFinite, isTrue);
    expect(distanceNearA, closeTo(0.0, 1e-9));
  });

  test('aabbForTransformedRect treats tiny rotation as zero', () {
    const rect = Rect.fromLTWH(-5, -5, 10, 10);
    final base = aabbForTransformedRect(
      localRect: rect,
      position: const Offset(10, 20),
      rotationDeg: 0,
      scaleX: 2,
      scaleY: 3,
    );
    final tiny = aabbForTransformedRect(
      localRect: rect,
      position: const Offset(10, 20),
      rotationDeg: 1e-13,
      scaleX: 2,
      scaleY: 3,
    );
    expect(tiny.left, closeTo(base.left, 1e-9));
    expect(tiny.top, closeTo(base.top, 1e-9));
    expect(tiny.right, closeTo(base.right, 1e-9));
    expect(tiny.bottom, closeTo(base.bottom, 1e-9));
  });

  test('segmentsIntersect handles colinear overlaps', () {
    // INV:INV-CORE-NUMERIC-ROBUSTNESS
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

  test('segmentsIntersect handles near-collinear overlap robustly', () {
    expect(
      segmentsIntersect(
        const Offset(0, 0),
        const Offset(10, 10),
        const Offset(5, 5 + 1e-13),
        const Offset(15, 15 + 1e-13),
      ),
      isTrue,
    );
  });

  test(
    'segmentsIntersect handles large-scale near-collinear overlap robustly',
    () {
      // INV:INV-CORE-NUMERIC-ROBUSTNESS
      expect(
        segmentsIntersect(
          const Offset(1e9, 1e9),
          const Offset(1e9 + 1000, 1e9 + 1000),
          const Offset(1e9 + 500, 1e9 + 500 + 5e-4),
          const Offset(1e9 + 1500, 1e9 + 1500 + 5e-4),
        ),
        isTrue,
      );
    },
  );

  test(
    'segmentsIntersect rejects near-collinear non-overlap with tiny gap',
    () {
      expect(
        segmentsIntersect(
          const Offset(0, 0),
          const Offset(10, 10),
          const Offset(10 + 1e-6, 10 + 1e-6),
          const Offset(20, 20),
        ),
        isFalse,
      );
    },
  );

  test(
    'segmentsIntersect rejects large-scale near-collinear non-overlap beyond epsilon',
    () {
      // INV:INV-CORE-NUMERIC-ROBUSTNESS
      expect(
        segmentsIntersect(
          const Offset(1e9, 1e9),
          const Offset(1e9 + 1000, 1e9 + 1000),
          const Offset(1e9 + 1000.02, 1e9 + 1000.0205),
          const Offset(1e9 + 2000, 1e9 + 2000.0005),
        ),
        isFalse,
      );
    },
  );

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

  test(
    'distanceSegmentToSegment stays finite for eraser-adjacent segments',
    () {
      final distance = distanceSegmentToSegment(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100 + 1e-9, 1e-9),
        const Offset(200, 1e-9),
      );

      expect(distance.isFinite, isTrue);
      expect(distance, greaterThan(0));
      expect(distance, lessThan(1e-6));
    },
  );
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/core/node_geometry.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';

void _expectRectClose(Rect actual, Rect expected, {double epsilon = 1e-9}) {
  expect((actual.left - expected.left).abs(), lessThanOrEqualTo(epsilon));
  expect((actual.top - expected.top).abs(), lessThanOrEqualTo(epsilon));
  expect((actual.right - expected.right).abs(), lessThanOrEqualTo(epsilon));
  expect((actual.bottom - expected.bottom).abs(), lessThanOrEqualTo(epsilon));
}

void main() {
  test('node geometry candidate bounds inflate runtime world bounds once', () {
    final line = LineNode(
      id: 'line-candidate',
      start: const Offset(-10, 0),
      end: const Offset(10, 0),
      thickness: 6,
      color: const Color(0xFF000000),
      hitPadding: 3,
      transform: const Transform2D(a: 1, b: 0.2, c: 0, d: 1, tx: 20, ty: 30),
    );

    final candidateBounds = nodeGeometryCandidateBoundsWorld(line);

    expect(
      () => _expectRectClose(
        candidateBounds,
        line.boundsWorld.inflate(line.hitPadding + kNodeGeometryHitSlop),
      ),
      returnsNormally,
    );
  });

  test('node geometry hit test covers box, stroke, and path families', () {
    final rect = RectNode(id: 'rect', size: const Size(20, 10))
      ..position = const Offset(10, 10);
    expect(nodeGeometryHitTest(const Offset(10, 10), rect), isTrue);
    expect(nodeGeometryHitTest(const Offset(40, 40), rect), isFalse);

    final stroke = StrokeNode(
      id: 'stroke',
      points: const <Offset>[Offset(-5, 0), Offset(5, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    )..position = const Offset(30, 10);
    expect(nodeGeometryHitTest(const Offset(30, 10), stroke), isTrue);

    final path = PathNode(
      id: 'path',
      svgPathData: 'M0 0 H12 V12 H0 Z',
      fillColor: const Color(0xFF00FF00),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2,
      transform: Transform2D.translation(const Offset(60, 10)),
    );
    expect(nodeGeometryHitTest(const Offset(60, 10), path), isTrue);
    expect(nodeGeometryHitTest(const Offset(75, 10), path), isFalse);
  });

  test(
    'node snapshot geometry candidate bounds and hit test match shared rules',
    () {
      final rect = RectNodeSnapshot(
        id: 'rect-snapshot',
        size: const Size(20, 10),
        hitPadding: 2,
        transform: Transform2D.translation(const Offset(10, 10)),
      );
      expect(
        nodeSnapshotBoundsWorld(rect),
        Rect.fromCenter(center: const Offset(10, 10), width: 20, height: 10),
      );
      expect(
        nodeSnapshotGeometryCandidateBoundsWorld(rect),
        Rect.fromCenter(
          center: const Offset(10, 10),
          width: 20,
          height: 10,
        ).inflate(2 + kNodeGeometryHitSlop),
      );
      expect(nodeSnapshotGeometryHitTest(const Offset(10, 10), rect), isTrue);
      expect(nodeSnapshotGeometryHitTest(const Offset(40, 40), rect), isFalse);

      final stroke = StrokeNodeSnapshot(
        id: 'stroke-snapshot',
        points: const <Offset>[Offset(-5, 0), Offset(5, 0)],
        thickness: 2,
        color: const Color(0xFF000000),
        transform: Transform2D.translation(const Offset(30, 10)),
      );
      expect(nodeSnapshotGeometryHitTest(const Offset(30, 10), stroke), isTrue);

      final path = PathNodeSnapshot(
        id: 'path-snapshot',
        svgPathData: 'M0 0 H12 V12 H0 Z',
        fillColor: const Color(0xFF00FF00),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 2,
        transform: Transform2D.translation(const Offset(60, 10)),
      );
      expect(nodeSnapshotGeometryHitTest(const Offset(60, 10), path), isTrue);
      expect(nodeSnapshotGeometryHitTest(const Offset(75, 10), path), isFalse);
    },
  );
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/core/hit_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';

// INV:INV-ENG-RENDER-HIT-BOUNDS-PARITY

void _expectRectClose(Rect actual, Rect expected, {double epsilon = 1e-9}) {
  expect((actual.left - expected.left).abs(), lessThanOrEqualTo(epsilon));
  expect((actual.top - expected.top).abs(), lessThanOrEqualTo(epsilon));
  expect((actual.right - expected.right).abs(), lessThanOrEqualTo(epsilon));
  expect((actual.bottom - expected.bottom).abs(), lessThanOrEqualTo(epsilon));
}

void main() {
  test(
    'rect hit candidate bounds are derived from the same render worldBounds',
    () {
      final cache = RenderGeometryCache();
      final snapshot = RectNodeSnapshot(
        id: 'rect-parity',
        size: Size(30, 10),
        strokeColor: Color(0xFF000000),
        strokeWidth: 6,
        hitPadding: 3,
        transform: Transform2D(a: 1.2, b: 0, c: 0.1, d: 0.8, tx: 40, ty: 25),
      );
      final renderBounds = cache.get(snapshot).worldBounds;

      final coreNode = RectNode(
        id: snapshot.id,
        size: snapshot.size,
        strokeColor: snapshot.strokeColor,
        strokeWidth: snapshot.strokeWidth,
        hitPadding: snapshot.hitPadding,
        transform: snapshot.transform,
      );

      expect(
        () => _expectRectClose(coreNode.boundsWorld, renderBounds),
        returnsNormally,
      );
      expect(
        () => _expectRectClose(
          nodeHitTestCandidateBoundsWorld(coreNode),
          renderBounds.inflate(snapshot.hitPadding + kHitSlop),
        ),
        returnsNormally,
      );
    },
  );

  test(
    'path hit candidate bounds are derived from the same render worldBounds',
    () {
      final cache = RenderGeometryCache();
      final snapshot = PathNodeSnapshot(
        id: 'path-parity',
        svgPathData: 'M0 0 H20 V12 H0 Z',
        fillRule: PathFillRule.evenOdd,
        strokeColor: Color(0xFF000000),
        strokeWidth: 4,
        hitPadding: 2.5,
        transform: Transform2D(a: 1, b: 0.2, c: 0, d: 1.3, tx: -10, ty: 35),
      );
      final renderBounds = cache.get(snapshot).worldBounds;

      final coreNode = PathNode(
        id: snapshot.id,
        svgPathData: snapshot.svgPathData,
        fillRule: PathFillRule.evenOdd,
        strokeColor: snapshot.strokeColor,
        strokeWidth: snapshot.strokeWidth,
        hitPadding: snapshot.hitPadding,
        transform: snapshot.transform,
      );

      expect(
        () => _expectRectClose(coreNode.boundsWorld, renderBounds),
        returnsNormally,
      );
      expect(
        () => _expectRectClose(
          nodeHitTestCandidateBoundsWorld(coreNode),
          renderBounds.inflate(snapshot.hitPadding + kHitSlop),
        ),
        returnsNormally,
      );
    },
  );

  test(
    'line hit candidate bounds are derived from the same render worldBounds',
    () {
      final cache = RenderGeometryCache();
      final snapshot = LineNodeSnapshot(
        id: 'line-parity',
        start: const Offset(-12, 0),
        end: const Offset(12, 0),
        thickness: 4,
        color: const Color(0xFF000000),
        hitPadding: 2,
        transform: const Transform2D(
          a: 1,
          b: 0.1,
          c: 0,
          d: 1.2,
          tx: 16,
          ty: -8,
        ),
      );
      final renderBounds = cache.get(snapshot).worldBounds;

      final coreNode = LineNode(
        id: snapshot.id,
        start: snapshot.start,
        end: snapshot.end,
        thickness: snapshot.thickness,
        color: snapshot.color,
        hitPadding: snapshot.hitPadding,
        transform: snapshot.transform,
      );

      expect(
        () => _expectRectClose(coreNode.boundsWorld, renderBounds),
        returnsNormally,
      );
      expect(
        () => _expectRectClose(
          nodeHitTestCandidateBoundsWorld(coreNode),
          renderBounds.inflate(snapshot.hitPadding + kHitSlop),
        ),
        returnsNormally,
      );
    },
  );

  test(
    'stroke hit candidate bounds are derived from the same render worldBounds',
    () {
      final cache = RenderGeometryCache();
      final snapshot = StrokeNodeSnapshot(
        id: 'stroke-parity',
        points: const <Offset>[Offset(-10, 0), Offset(10, 0), Offset(14, 6)],
        thickness: 5,
        color: const Color(0xFF000000),
        hitPadding: 1.5,
        transform: const Transform2D(a: 1, b: 0, c: 0.3, d: 1, tx: 24, ty: 12),
      );
      final renderBounds = cache.get(snapshot).worldBounds;

      final coreNode = StrokeNode(
        id: snapshot.id,
        points: snapshot.points,
        thickness: snapshot.thickness,
        color: snapshot.color,
        hitPadding: snapshot.hitPadding,
        transform: snapshot.transform,
      );

      expect(
        () => _expectRectClose(coreNode.boundsWorld, renderBounds),
        returnsNormally,
      );
      expect(
        () => _expectRectClose(
          nodeHitTestCandidateBoundsWorld(coreNode),
          renderBounds.inflate(snapshot.hitPadding + kHitSlop),
        ),
        returnsNormally,
      );
    },
  );
}

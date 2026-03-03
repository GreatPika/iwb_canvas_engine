import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/hit_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';

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
      const snapshot = RectNodeSnapshot(
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

      _expectRectClose(coreNode.boundsWorld, renderBounds);
      _expectRectClose(
        nodeHitTestCandidateBoundsWorld(coreNode),
        renderBounds.inflate(snapshot.hitPadding + kHitSlop),
      );
    },
  );

  test(
    'path hit candidate bounds are derived from the same render worldBounds',
    () {
      final cache = RenderGeometryCache();
      const snapshot = PathNodeSnapshot(
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

      _expectRectClose(coreNode.boundsWorld, renderBounds);
      _expectRectClose(
        nodeHitTestCandidateBoundsWorld(coreNode),
        renderBounds.inflate(snapshot.hitPadding + kHitSlop),
      );
    },
  );
}

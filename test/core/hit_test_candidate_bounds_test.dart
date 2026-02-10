import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/hit_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';

void main() {
  test(
    'candidate bounds use strict scene padding and do not inflate by anisotropy',
    () {
      final node = RectNode(
        id: 'rect',
        size: const Size(20, 10),
        hitPadding: 3,
        transform: const Transform2D(a: 10, b: 0, c: 0, d: 0.1, tx: 50, ty: 20),
      );

      final expectedPadding = node.hitPadding + kHitSlop;
      final expected = node.boundsWorld.inflate(expectedPadding);
      final actual = nodeHitTestCandidateBoundsWorld(node);

      expect(actual, expected);
    },
  );

  test('additionalScenePadding is added in strict scene units', () {
    final node = RectNode(
      id: 'rect',
      size: const Size(20, 10),
      hitPadding: 2,
      transform: const Transform2D(a: 3, b: 0, c: 0, d: 0.25, tx: 0, ty: 0),
    );

    const additionalPadding = 5.0;
    final expected = node.boundsWorld.inflate(
      node.hitPadding + kHitSlop + additionalPadding,
    );
    final actual = nodeHitTestCandidateBoundsWorld(
      node,
      additionalScenePadding: additionalPadding,
    );

    expect(actual, expected);
  });
}

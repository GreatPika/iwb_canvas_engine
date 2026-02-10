import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/geometry.dart';

void main() {
  test('toScene/toView are inverse operations', () {
    const view = Offset(10, 20);
    const camera = Offset(-3, 5);
    final scene = toScene(view, camera);

    expect(scene, const Offset(7, 25));
    expect(toView(scene, camera), view);
  });

  test('rotate and reflect helpers compute expected coordinates', () {
    final rotated = rotatePoint(const Offset(2, 1), const Offset(1, 1), 90);
    expect(rotated.dx, closeTo(1, 1e-9));
    expect(rotated.dy, closeTo(2, 1e-9));

    expect(reflectPointVertical(const Offset(3, 4), 1), const Offset(-1, 4));
    expect(reflectPointHorizontal(const Offset(3, 4), 10), const Offset(3, 16));
  });

  test('aabb helpers handle empty and transformed geometry', () {
    expect(aabbFromPoints(const <Offset>[]), Rect.zero);
    expect(
      aabbFromPoints(const <Offset>[
        Offset(1, 2),
        Offset(3, -1),
        Offset(-2, 5),
      ]),
      const Rect.fromLTRB(-2, -1, 3, 5),
    );

    final rect = aabbForTransformedRect(
      localRect: const Rect.fromLTWH(0, 0, 2, 4),
      position: const Offset(10, 20),
      rotationDeg: 0,
      scaleX: 2,
      scaleY: 1,
    );
    expect(rect, const Rect.fromLTRB(10, 20, 14, 24));

    final rotatedRect = aabbForTransformedRect(
      localRect: const Rect.fromLTWH(-1, -1, 2, 2),
      position: Offset.zero,
      rotationDeg: 45,
      scaleX: 1,
      scaleY: 1,
    );
    final expectedHalfExtent = math.sqrt2;
    expect(rotatedRect.left, closeTo(-expectedHalfExtent, 1e-9));
    expect(rotatedRect.right, closeTo(expectedHalfExtent, 1e-9));
  });

  test('distance helpers cover point/segment and segment/segment', () {
    expect(
      distanceSquaredPointToSegment(
        const Offset(1, 1),
        const Offset(0, 0),
        const Offset(2, 0),
      ),
      closeTo(1, 1e-12),
    );

    // Degenerate segment branch.
    expect(
      distanceSquaredPointToSegment(
        const Offset(4, 5),
        const Offset(1, 1),
        const Offset(1, 1),
      ),
      closeTo(25, 1e-12),
    );

    expect(
      distancePointToSegment(
        const Offset(1, 1),
        const Offset(0, 0),
        const Offset(2, 0),
      ),
      closeTo(1, 1e-12),
    );

    expect(
      distanceSquaredSegmentToSegment(
        const Offset(0, 0),
        const Offset(2, 0),
        const Offset(1, -1),
        const Offset(1, 1),
      ),
      0,
    );

    expect(
      distanceSegmentToSegment(
        const Offset(0, 0),
        const Offset(0, 1),
        const Offset(2, 0),
        const Offset(2, 1),
      ),
      closeTo(2, 1e-12),
    );
  });

  test('segmentsIntersect handles general, collinear and invalid cases', () {
    expect(
      segmentsIntersect(
        const Offset(0, 0),
        const Offset(4, 4),
        const Offset(0, 4),
        const Offset(4, 0),
      ),
      isTrue,
    );

    expect(
      segmentsIntersect(
        const Offset(0, 0),
        const Offset(2, 0),
        const Offset(3, 0),
        const Offset(5, 0),
      ),
      isFalse,
    );

    expect(
      segmentsIntersect(
        const Offset(0, 0),
        const Offset(2, 0),
        const Offset(2, 0),
        const Offset(3, 0),
      ),
      isTrue,
    );

    expect(
      segmentsIntersect(
        const Offset(double.infinity, 0),
        const Offset(1, 1),
        const Offset(0, 0),
        const Offset(2, 2),
      ),
      isFalse,
    );
  });
}

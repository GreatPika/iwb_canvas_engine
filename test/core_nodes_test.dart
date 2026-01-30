import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('ImageNode aabb centers on position', () {
    final node = ImageNode(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(10, 20),
    )..position = const Offset(5, 5);

    final rect = node.aabb;
    expect(rect.center, const Offset(5, 5));
    expect(rect.width, 10);
    expect(rect.height, 20);
  });

  test('LineNode aabb inflates by thickness', () {
    final node = LineNode(
      id: 'line-1',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 4,
      color: const Color(0xFF000000),
    );

    final rect = node.aabb;
    expect(rect.left, -2);
    expect(rect.right, 12);
    expect(rect.top, -2);
    expect(rect.bottom, 2);
  });

  test('StrokeNode aabb inflates by thickness', () {
    final node = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(0, 0), Offset(10, 10)],
      thickness: 6,
      color: const Color(0xFF000000),
    );

    final rect = node.aabb;
    expect(rect.left, -3);
    expect(rect.top, -3);
    expect(rect.right, 13);
    expect(rect.bottom, 13);
  });

  test('StrokeNode.position translates points', () {
    final node = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(0, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(node.position, const Offset(5, 0));
    node.position = const Offset(7, 3);

    expect(node.points, const [Offset(2, 3), Offset(12, 3)]);
    expect(node.position, const Offset(7, 3));
  });

  test('LineNode.position translates endpoints', () {
    final node = LineNode(
      id: 'line-1',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(node.position, const Offset(5, 0));
    node.position = const Offset(5, 5);

    expect(node.start, const Offset(0, 5));
    expect(node.end, const Offset(10, 5));
  });

  test('PathNode.buildLocalPath returns null for empty and invalid data', () {
    expect(PathNode(id: 'p1', svgPathData: '   ').buildLocalPath(), isNull);
    expect(
      PathNode(id: 'p2', svgPathData: 'not-a-path').buildLocalPath(),
      isNull,
    );
  });

  test(
    'PathNode.buildLocalPath applies fill rule and aabb uses transforms',
    () {
      final node =
          PathNode(
              id: 'path-1',
              svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
              fillRule: PathFillRule.evenOdd,
            )
            ..position = const Offset(100, 100)
            ..rotationDeg = 90
            ..scaleX = 2
            ..scaleY = 0.5;

      final path = node.buildLocalPath();
      expect(path, isNotNull);
      expect(path!.fillType, PathFillType.evenOdd);
      expect(node.aabb, isNot(Rect.zero));
    },
  );
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  test('ImageNode.fromTopLeftWorld positions bounds by world top-left', () {
    final node = ImageNode.fromTopLeftWorld(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
    );

    expect(node.topLeftWorld, const Offset(10, 20));
    expect(node.boundsWorld.size, const Size(100, 50));
  });

  test('ImageNode.topLeftWorld setter is a no-op for same value', () {
    final node = ImageNode.fromTopLeftWorld(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
    );

    final beforePosition = node.position;
    node.topLeftWorld = node.topLeftWorld;
    expect(node.position, beforePosition);
  });

  test('ImageNode.topLeftWorld setter moves bounds top-left', () {
    final node = ImageNode.fromTopLeftWorld(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
    );

    node.topLeftWorld = const Offset(30, 40);

    expect(node.boundsWorld.topLeft.dx, closeTo(30, 1e-9));
    expect(node.boundsWorld.topLeft.dy, closeTo(40, 1e-9));
  });

  test('TextNode.fromTopLeftWorld positions bounds by world top-left', () {
    final node = TextNode.fromTopLeftWorld(
      id: 'txt-1',
      text: 'Hello',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      color: const Color(0xFF000000),
    );

    expect(node.topLeftWorld, const Offset(10, 20));
    expect(node.boundsWorld.size, const Size(100, 50));
  });

  test('TextNode.topLeftWorld setter moves bounds top-left', () {
    final node = TextNode.fromTopLeftWorld(
      id: 'txt-1',
      text: 'Hello',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      color: const Color(0xFF000000),
    );

    node.topLeftWorld = const Offset(30, 40);

    expect(node.boundsWorld.topLeft.dx, closeTo(30, 1e-9));
    expect(node.boundsWorld.topLeft.dy, closeTo(40, 1e-9));
  });

  test('ImageNode boundsWorld centers on position', () {
    final node = ImageNode(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(10, 20),
    )..position = const Offset(5, 5);

    final rect = node.boundsWorld;
    expect(rect.center, const Offset(5, 5));
    expect(rect.width, 10);
    expect(rect.height, 20);
  });

  test('RectNode.fromTopLeftWorld positions bounds by world top-left', () {
    final node = RectNode.fromTopLeftWorld(
      id: 'rect-1',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      fillColor: const Color(0xFF000000),
    );

    expect(node.topLeftWorld, const Offset(10, 20));
    expect(node.boundsWorld.size, const Size(100, 50));
  });

  test('RectNode.topLeftWorld setter moves bounds top-left', () {
    final node =
        RectNode(
            id: 'rect-1',
            size: const Size(100, 50),
            fillColor: const Color(0xFF000000),
          )
          ..position = const Offset(0, 0)
          ..rotationDeg = 45;

    node.topLeftWorld = const Offset(30, 40);

    expect(node.boundsWorld.topLeft.dx, closeTo(30, 1e-9));
    expect(node.boundsWorld.topLeft.dy, closeTo(40, 1e-9));
  });

  test('TextNode.topLeftWorld setter is a no-op for same value', () {
    final node = TextNode.fromTopLeftWorld(
      id: 'txt-1',
      text: 'Hello',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      color: const Color(0xFF000000),
    );

    final beforePosition = node.position;
    node.topLeftWorld = node.topLeftWorld;
    expect(node.position, beforePosition);
  });

  test('LineNode boundsWorld inflates by thickness', () {
    final node = LineNode(
      id: 'line-1',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 4,
      color: const Color(0xFF000000),
    );

    final rect = node.boundsWorld;
    expect(rect.left, -2);
    expect(rect.right, 12);
    expect(rect.top, -2);
    expect(rect.bottom, 2);
  });

  test('StrokeNode boundsWorld inflates by thickness', () {
    final node = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(0, 0), Offset(10, 10)],
      thickness: 6,
      color: const Color(0xFF000000),
    );

    final rect = node.boundsWorld;
    expect(rect.left, -3);
    expect(rect.top, -3);
    expect(rect.right, 13);
    expect(rect.bottom, 13);
  });

  test('StrokeNode.position translates points', () {
    final node = StrokeNode.fromWorldPoints(
      id: 'stroke-1',
      points: const [Offset(0, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(node.position, const Offset(5, 0));
    node.position = const Offset(7, 3);

    expect(node.points, const [Offset(-5, 0), Offset(5, 0)]);
    expect(node.transform.applyToPoint(node.points[0]), const Offset(2, 3));
    expect(node.transform.applyToPoint(node.points[1]), const Offset(12, 3));
    expect(node.position, const Offset(7, 3));
  });

  test('LineNode.position translates endpoints', () {
    final node = LineNode.fromWorldSegment(
      id: 'line-1',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(node.position, const Offset(5, 0));
    node.position = const Offset(5, 5);

    expect(node.start, const Offset(-5, 0));
    expect(node.end, const Offset(5, 0));
    expect(node.transform.applyToPoint(node.start), const Offset(0, 5));
    expect(node.transform.applyToPoint(node.end), const Offset(10, 5));
  });

  test('PathNode.buildLocalPath returns null for empty and invalid data', () {
    expect(PathNode(id: 'p1', svgPathData: '   ').buildLocalPath(), isNull);
    expect(
      PathNode(id: 'p2', svgPathData: 'not-a-path').buildLocalPath(),
      isNull,
    );
    expect(PathNode(id: 'p3', svgPathData: 'M0 0').buildLocalPath(), isNull);
  });

  test(
    'PathNode.buildLocalPath applies fill rule and boundsWorld uses transforms',
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
      expect(node.boundsWorld, isNot(Rect.zero));
    },
  );

  test('PathNode invalidates cached path on data changes', () {
    final node = PathNode(id: 'path-cache', svgPathData: 'M0 0 H10 V10 H0 Z');

    final first = node.buildLocalPath();
    expect(first, isNotNull);
    final firstBounds = first!.getBounds();

    node.svgPathData = 'M0 0 H20 V6 H0 Z';
    final second = node.buildLocalPath();
    expect(second, isNotNull);
    final secondBounds = second!.getBounds();

    expect(secondBounds.width, isNot(firstBounds.width));

    node.fillRule = PathFillRule.evenOdd;
    final third = node.buildLocalPath();
    expect(third, isNotNull);
    expect(third!.fillType, PathFillType.evenOdd);
  });
}

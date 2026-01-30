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
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/hit_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';

void main() {
  test('primitive hit helpers work for rect/line/stroke', () {
    expect(
      hitTestRect(const Offset(1, 1), const Rect.fromLTWH(0, 0, 2, 2)),
      isTrue,
    );
    expect(
      hitTestRect(const Offset(3, 3), const Rect.fromLTWH(0, 0, 2, 2)),
      isFalse,
    );

    expect(
      hitTestLine(
        const Offset(1, 0.5),
        const Offset(0, 0),
        const Offset(2, 0),
        1,
      ),
      isTrue,
    );
    expect(
      hitTestLine(
        const Offset(1, 2),
        const Offset(0, 0),
        const Offset(2, 0),
        1,
      ),
      isFalse,
    );

    expect(hitTestStroke(const Offset(0, 0), const <Offset>[], 1), isFalse);
    expect(
      hitTestStroke(
        const Offset(0, 0),
        const <Offset>[Offset(0, 0)],
        2,
        hitPadding: 1,
      ),
      isTrue,
    );
    expect(
      hitTestStroke(const Offset(1, 0), const <Offset>[
        Offset(0, 0),
        Offset(2, 0),
      ], 1),
      isTrue,
    );
  });

  test('candidate bounds inflate sanitized world bounds', () {
    final node = RectNode(
      id: 'r',
      size: const Size(10, 10),
      transform: const Transform2D(
        a: 1,
        b: 0,
        c: 0,
        d: 1,
        tx: double.nan,
        ty: 0,
      ),
    );
    expect(nodeHitTestCandidateBoundsWorld(node), Rect.zero.inflate(kHitSlop));
  });

  test('hitTestNode handles basic node types and guards', () {
    final rect = RectNode(id: 'rect', size: const Size(20, 20))
      ..position = const Offset(10, 10)
      ..hitPadding = 0;
    expect(hitTestNode(const Offset(10, 10), rect), isTrue);

    final singularRect = RectNode(
      id: 'rect2',
      size: const Size(10, 10),
      transform: const Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 5, ty: 5),
    );
    expect(hitTestNode(const Offset(5, 5), singularRect), isTrue);

    final line = LineNode(
      id: 'line',
      start: const Offset(-5, 0),
      end: const Offset(5, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    )..position = const Offset(20, 20);
    expect(hitTestNode(const Offset(20, 20), line), isTrue);

    final singularLine = LineNode(
      id: 'line2',
      start: const Offset(0, 0),
      end: const Offset(1, 0),
      thickness: 1,
      color: const Color(0xFF000000),
      transform: const Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 30, ty: 30),
    );
    expect(hitTestNode(const Offset(30, 30), singularLine), isTrue);

    final stroke = StrokeNode(
      id: 'stroke',
      points: const <Offset>[Offset(-3, 0), Offset(3, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    )..position = const Offset(40, 40);
    expect(hitTestNode(const Offset(40, 40), stroke), isTrue);

    final singlePointStroke = StrokeNode(
      id: 'stroke2',
      points: const <Offset>[Offset.zero],
      thickness: 2,
      color: const Color(0xFF000000),
    )..position = const Offset(50, 50);
    expect(hitTestNode(const Offset(50, 50), singlePointStroke), isTrue);

    final singularStroke = StrokeNode(
      id: 'stroke-singular',
      points: const <Offset>[Offset(0, 0), Offset(2, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
      transform: const Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 60, ty: 60),
    );
    expect(hitTestNode(const Offset(60, 60), singularStroke), isTrue);

    final emptyStroke = StrokeNode(
      id: 'stroke3',
      points: const <Offset>[],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    expect(hitTestNode(Offset.zero, emptyStroke), isFalse);

    final text = TextNode(
      id: 'text',
      text: 'x',
      size: const Size(20, 10),
      color: const Color(0xFF000000),
    )..position = const Offset(70, 70);
    expect(hitTestNode(const Offset(70, 70), text), isTrue);

    text.isVisible = false;
    expect(hitTestNode(const Offset(70, 70), text), isFalse);
  });

  test('hitTestNode path branch supports fill and stroke checks', () {
    final filledPath = PathNode(
      id: 'p1',
      svgPathData: 'M0 0 H10 V10 H0 Z',
      fillColor: const Color(0xFF00FF00),
      transform: Transform2D.translation(const Offset(10, 10)),
    );
    expect(hitTestNode(const Offset(10, 10), filledPath), isTrue);

    final strokedPath = PathNode(
      id: 'p2',
      svgPathData: 'M0 0 H10',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2,
      transform: Transform2D.translation(const Offset(30, 30)),
    );
    expect(hitTestNode(const Offset(30, 30), strokedPath), isTrue);
    expect(hitTestNode(const Offset(35, 30), strokedPath), isTrue);
    expect(hitTestNode(const Offset(34.8, 30), strokedPath), isTrue);

    final noStroke = PathNode(
      id: 'p3',
      svgPathData: 'M0 0 H10',
      strokeColor: null,
      fillColor: null,
    );
    expect(hitTestNode(Offset.zero, noStroke), isFalse);

    final singular = PathNode(
      id: 'p4',
      svgPathData: 'M0 0 H10',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2,
      transform: const Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0),
    );
    expect(hitTestNode(Offset.zero, singular), isFalse);

    final shortPath = PathNode(
      id: 'p5',
      svgPathData: 'M0 0 H0.1',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0.1,
    );
    expect(hitTestNode(const Offset(0.1, 0), shortPath), isTrue);

    final endTangentPath = PathNode(
      id: 'p6',
      svgPathData: 'M0 0 H2',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0.2,
    );
    expect(hitTestNode(const Offset(1, 0), endTangentPath), isTrue);

    final shortEndOnlyPath = PathNode(
      id: 'p7',
      svgPathData: 'M0 0 H0.4',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0.1,
    );
    expect(hitTestNode(const Offset(0.2, 0), shortEndOnlyPath), isTrue);

    final scaledPath = PathNode(
      id: 'p8',
      svgPathData: 'M0 0 H2',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0.1,
      transform: const Transform2D(a: 1000, b: 0, c: 0, d: 1000, tx: 0, ty: 0),
    );
    expect(hitTestNode(const Offset(1000, 0), scaledPath), isTrue);

    final longMetricPath = PathNode(
      id: 'p9',
      svgPathData: 'M0 0 H10000',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0.2,
    );
    expect(hitTestNode(const Offset(4990, 0), longMetricPath), isTrue);
    expect(hitTestNode(const Offset(4990, 30), longMetricPath), isFalse);
  });

  test(
    'hitTestTopNode resolves top-most selectable node and skips background',
    () {
      final bottom = RectNode(id: 'bottom', size: const Size(30, 30))
        ..position = const Offset(10, 10);
      final top = RectNode(id: 'top', size: const Size(10, 10))
        ..position = const Offset(10, 10);

      final scene = Scene(
        layers: <Layer>[
          Layer(
            isBackground: true,
            nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(200, 200))],
          ),
          Layer(nodes: <SceneNode>[bottom, top]),
        ],
      );

      expect(hitTestTopNode(scene, const Offset(10, 10))?.id, 'top');
      expect(hitTestTopNode(scene, const Offset(500, 500)), isNull);
    },
  );
}

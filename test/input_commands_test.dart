import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  void marqueeSelect(SceneController controller, Rect rect) {
    controller.handlePointer(
      PointerSample(
        pointerId: 99,
        position: rect.topLeft,
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 99,
        position: rect.bottomRight,
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 99,
        position: rect.bottomRight,
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );
  }

  RectNode rectNode(String id, Offset position, {bool transformable = true}) {
    return RectNode(
      id: id,
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isTransformable: transformable,
    )..position = position;
  }

  test('rotateSelection rotates around selection center', () {
    final left = rectNode('left', const Offset(0, 0));
    final right = rectNode('right', const Offset(10, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [left, right]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));

    controller.rotateSelection(clockwise: true, timestampMs: 40);

    expect(left.position.dx, closeTo(5, 0.001));
    expect(left.position.dy, closeTo(-5, 0.001));
    expect(right.position.dx, closeTo(5, 0.001));
    expect(right.position.dy, closeTo(5, 0.001));
    expect(left.rotationDeg, 90);
    expect(right.rotationDeg, 90);
  });

  test('flipSelectionVertical mirrors around center x', () {
    final left = rectNode('left', const Offset(0, 0));
    final right = rectNode('right', const Offset(10, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [left, right]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));

    controller.flipSelectionVertical(timestampMs: 40);

    expect(left.position.dx, closeTo(10, 0.001));
    expect(right.position.dx, closeTo(0, 0.001));
    expect(left.scaleX, -1);
    expect(right.scaleX, -1);
  });

  test('rotateSelection rotates line geometry', () {
    final line = LineNode(
      id: 'line',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [line]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));

    controller.rotateSelection(clockwise: true, timestampMs: 40);

    expect(line.start.dx, closeTo(5, 0.001));
    expect(line.start.dy, closeTo(-5, 0.001));
    expect(line.end.dx, closeTo(5, 0.001));
    expect(line.end.dy, closeTo(5, 0.001));
  });

  test('flipSelectionVertical mirrors stroke geometry', () {
    final stroke = StrokeNode(
      id: 'stroke',
      points: [const Offset(0, 0), const Offset(10, 0), const Offset(20, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [stroke]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 40, 20));

    controller.flipSelectionVertical(timestampMs: 40);

    expect(stroke.points[0].dx, closeTo(20, 0.001));
    expect(stroke.points[1].dx, closeTo(10, 0.001));
    expect(stroke.points[2].dx, closeTo(0, 0.001));
  });

  test('deleteSelection removes deletable nodes only', () {
    final deletable = rectNode('del', const Offset(0, 0));
    final locked = RectNode(
      id: 'keep',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isDeletable: false,
    )..position = const Offset(20, 0);
    final scene = Scene(
      layers: [
        Layer(nodes: [deletable, locked]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 30, 20));

    controller.deleteSelection(timestampMs: 40);

    expect(scene.layers.first.nodes, [locked]);
  });

  test('clearScene removes nodes from non-background layers', () {
    final background = Layer(
      isBackground: true,
      nodes: [rectNode('bg', const Offset(0, 0))],
    );
    final foreground = Layer(
      nodes: [
        rectNode('a', const Offset(0, 0)),
        rectNode('b', const Offset(10, 0)),
      ],
    );
    final scene = Scene(layers: [background, foreground]);
    final controller = SceneController(scene: scene);

    controller.clearScene(timestampMs: 10);

    expect(scene.layers.first.nodes, hasLength(1));
    expect(scene.layers.last.nodes, isEmpty);
  });
}

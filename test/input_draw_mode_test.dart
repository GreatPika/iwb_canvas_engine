import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  SceneController drawController(Scene scene) {
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    controller.setMode(CanvasMode.draw);
    return controller;
  }

  test('pen creates stroke and emits action', () {
    final scene = Scene(layers: [Layer()]);
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.pen);
    controller.drawColor = const Color(0xFF123456);
    controller.penThickness = 5;

    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: const Offset(10, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: const Offset(20, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    final node = scene.layers.first.nodes.single as StrokeNode;
    expect(node.thickness, 5);
    expect(node.color, const Color(0xFF123456));
    expect(node.opacity, 1);
    expect(node.points.length, greaterThanOrEqualTo(2));

    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.drawStroke);
    expect(actions.single.nodeIds, [node.id]);
  });

  test('highlighter creates stroke with opacity and emits action', () {
    final scene = Scene(layers: [Layer()]);
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.highlighter);
    controller.drawColor = const Color(0xFF00FF00);
    controller.highlighterThickness = 12;
    controller.highlighterOpacity = 0.4;

    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    controller.handlePointer(
      PointerSample(
        pointerId: 2,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 2,
        position: const Offset(5, 5),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    final node = scene.layers.first.nodes.single as StrokeNode;
    expect(node.thickness, 12);
    expect(node.opacity, 0.4);
    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.drawHighlighter);
    expect(actions.single.nodeIds, [node.id]);
  });

  test('line drag creates line and emits action', () {
    final scene = Scene(layers: [Layer()]);
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.line);
    controller.lineThickness = 4;

    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    controller.handlePointer(
      PointerSample(
        pointerId: 3,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 3,
        position: const Offset(10, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 3,
        position: const Offset(10, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    final node = scene.layers.first.nodes.single as LineNode;
    expect(node.start, const Offset(0, 0));
    expect(node.end, const Offset(10, 0));
    expect(node.thickness, 4);
    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.drawLine);
  });

  test('line two-tap creates line and emits action', () {
    final scene = Scene(layers: [Layer()]);
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.line);

    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    controller.handlePointer(
      PointerSample(
        pointerId: 4,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 4,
        position: const Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    controller.handlePointer(
      PointerSample(
        pointerId: 4,
        position: const Offset(20, 0),
        timestampMs: 1000,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 4,
        position: const Offset(20, 0),
        timestampMs: 1010,
        phase: PointerPhase.up,
      ),
    );

    final node = scene.layers.first.nodes.single as LineNode;
    expect(node.start, const Offset(0, 0));
    expect(node.end, const Offset(20, 0));
    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.drawLine);
  });

  test('eraser removes only stroke and line and emits action', () {
    final stroke = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(-10, 0), Offset(10, 0)],
      thickness: 4,
      color: const Color(0xFF000000),
    );
    final line = LineNode(
      id: 'line-1',
      start: const Offset(0, -10),
      end: const Offset(0, 10),
      thickness: 4,
      color: const Color(0xFF000000),
    );
    final rect = RectNode(
      id: 'rect-1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(100, 100);

    final scene = Scene(
      layers: [
        Layer(nodes: [stroke, line, rect]),
      ],
    );
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    controller.handlePointer(
      PointerSample(
        pointerId: 5,
        position: const Offset(-5, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 5,
        position: const Offset(5, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 5,
        position: const Offset(5, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(scene.layers.first.nodes, hasLength(1));
    expect(scene.layers.first.nodes.single, rect);
    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.erase);
    expect(actions.single.nodeIds.toSet(), {'stroke-1', 'line-1'});
  });
}

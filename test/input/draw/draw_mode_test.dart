import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SceneController drawController(Scene scene) {
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    controller.setMode(CanvasMode.draw);
    return controller;
  }

  Layer annotationLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  test('pen creates stroke and emits action', () {
    final scene = Scene(layers: [Layer()]);
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.pen);
    controller.setDrawColor(const Color(0xFF123456));
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

    final node = annotationLayer(scene).nodes.single as StrokeNode;
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
    controller.setDrawColor(const Color(0xFF00FF00));
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

    final node = annotationLayer(scene).nodes.single as StrokeNode;
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
        position: const Offset(12, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    final node = annotationLayer(scene).nodes.single as LineNode;
    expect(node.transform.applyToPoint(node.start), const Offset(0, 0));
    expect(node.transform.applyToPoint(node.end), const Offset(12, 0));
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

    final node = annotationLayer(scene).nodes.single as LineNode;
    expect(node.transform.applyToPoint(node.start), const Offset(0, 0));
    expect(node.transform.applyToPoint(node.end), const Offset(20, 0));
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

    expect(annotationLayer(scene).nodes, hasLength(1));
    expect(annotationLayer(scene).nodes.single, rect);
    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.erase);
    expect(actions.single.nodeIds.toSet(), {'stroke-1', 'line-1'});
  });

  test('eraser removes deleted ids from selection before emit', () {
    // INV:INV-INPUT-ERASER-SELECTION-NORMALIZED
    final stroke = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(-10, 0), Offset(10, 0)],
      thickness: 4,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [stroke]),
      ],
    );
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;
    controller.setSelection(const <NodeId>{'stroke-1'});

    controller.handlePointer(
      const PointerSample(
        pointerId: 7,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 7,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(annotationLayer(scene).nodes, isEmpty);
    expect(controller.selectedNodeIds, isEmpty);
  });

  test('eraser preserves selection for nodes that were not deleted', () {
    final erased = StrokeNode(
      id: 'erased',
      points: const [Offset(-10, 0), Offset(10, 0)],
      thickness: 4,
      color: const Color(0xFF000000),
    );
    final kept = RectNode(
      id: 'kept',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(100, 100);
    final scene = Scene(
      layers: [
        Layer(nodes: [erased, kept]),
      ],
    );
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;
    controller.setSelection(const <NodeId>{'erased', 'kept'});

    controller.handlePointer(
      const PointerSample(
        pointerId: 8,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 8,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(annotationLayer(scene).nodes, hasLength(1));
    expect(annotationLayer(scene).nodes.single.id, 'kept');
    expect(controller.selectedNodeIds, const <NodeId>{'kept'});
  });

  test('default nodeIdGenerator skips existing ids in the scene', () {
    final existing = RectNode(
      id: 'node-0',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(50, 50);
    final scene = Scene(
      layers: [
        Layer(nodes: [existing]),
      ],
    );
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.pen);

    controller.handlePointer(
      PointerSample(
        pointerId: 6,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 6,
        position: const Offset(10, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 6,
        position: const Offset(20, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    final ids = annotationLayer(scene).nodes.map((node) => node.id).toList();
    expect(ids, hasLength(2));
    expect(ids, contains('node-0'));
    expect(ids, contains('node-1'));
  });

  test('default nodeIdGenerator starts after the max existing node-n', () {
    final existingLow = RectNode(
      id: 'node-1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(50, 50);
    final existingHigh = RectNode(
      id: 'node-41',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(150, 50);
    final scene = Scene(
      layers: [
        Layer(nodes: [existingLow, existingHigh]),
      ],
    );
    final controller = drawController(scene);
    controller.setDrawTool(DrawTool.pen);

    controller.handlePointer(
      PointerSample(
        pointerId: 7,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 7,
        position: const Offset(10, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 7,
        position: const Offset(20, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(annotationLayer(scene).nodes, hasLength(3));
    expect(annotationLayer(scene).nodes.last.id, 'node-42');
  });

  test(
    'stroke commit safely aborts when normalize preconditions are violated',
    () {
      // INV:INV-INPUT-DRAW-COMMIT-FAILSAFE
      final scene = Scene(layers: [Layer()]);
      final controller = drawController(scene);
      addTearDown(controller.dispose);
      controller.setDrawTool(DrawTool.pen);

      final actions = <ActionCommitted>[];
      controller.actions.listen(actions.add);

      controller.handlePointer(
        const PointerSample(
          pointerId: 100,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      final brokenStroke = annotationLayer(scene).nodes.single as StrokeNode;
      brokenStroke.transform = Transform2D.rotationDeg(15);

      expect(
        () => controller.handlePointer(
          const PointerSample(
            pointerId: 100,
            position: Offset(10, 0),
            timestampMs: 10,
            phase: PointerPhase.up,
          ),
        ),
        returnsNormally,
      );
      expect(annotationLayer(scene).nodes, isEmpty);
      expect(actions, isEmpty);

      controller.handlePointer(
        const PointerSample(
          pointerId: 101,
          position: Offset(0, 0),
          timestampMs: 20,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 101,
          position: Offset(10, 0),
          timestampMs: 30,
          phase: PointerPhase.up,
        ),
      );
      expect(annotationLayer(scene).nodes, hasLength(1));
      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.drawStroke);
    },
  );

  test(
    'line drag commit safely aborts when normalize preconditions are violated',
    () {
      final scene = Scene(layers: [Layer()]);
      final controller = drawController(scene);
      addTearDown(controller.dispose);
      controller.setDrawTool(DrawTool.line);

      final actions = <ActionCommitted>[];
      controller.actions.listen(actions.add);

      controller.handlePointer(
        const PointerSample(
          pointerId: 200,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 200,
          position: Offset(10, 0),
          timestampMs: 10,
          phase: PointerPhase.move,
        ),
      );
      final brokenLine = annotationLayer(scene).nodes.single as LineNode;
      brokenLine.transform = Transform2D.rotationDeg(15);

      expect(
        () => controller.handlePointer(
          const PointerSample(
            pointerId: 200,
            position: Offset(12, 0),
            timestampMs: 20,
            phase: PointerPhase.up,
          ),
        ),
        returnsNormally,
      );
      expect(annotationLayer(scene).nodes, isEmpty);
      expect(actions, isEmpty);

      controller.handlePointer(
        const PointerSample(
          pointerId: 201,
          position: Offset(0, 0),
          timestampMs: 30,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 201,
          position: Offset(8, 0),
          timestampMs: 40,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 201,
          position: Offset(10, 0),
          timestampMs: 50,
          phase: PointerPhase.up,
        ),
      );
      expect(annotationLayer(scene).nodes, hasLength(1));
      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.drawLine);
    },
  );
}

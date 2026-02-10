import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic_v2.dart';
import 'package:iwb_canvas_engine/src/core/pointer_input.dart';
import 'package:iwb_canvas_engine/src/v2/controller/scene_controller_v2.dart';

class _UnknownSceneNode extends SceneNode {
  _UnknownSceneNode({required super.id}) : super(type: NodeType.rect);

  @override
  Rect get localBounds => const Rect.fromLTWH(0, 0, 1, 1);
}

NodeSnapshot _nodeById(SceneSnapshot snapshot, NodeId id) {
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (node.id == id) return node;
    }
  }
  throw StateError('Node not found: $id');
}

PointerSample _sample({
  required int pointerId,
  required Offset position,
  required int timestampMs,
  required PointerPhase phase,
}) {
  return PointerSample(
    pointerId: pointerId,
    position: position,
    timestampMs: timestampMs,
    phase: phase,
  );
}

void main() {
  group('SceneControllerInteractiveV2 unit', () {
    test('read API + setters + validation', () {
      final controller = SceneControllerInteractiveV2(
        scene: Scene(
          layers: <Layer>[
            Layer(isBackground: true),
            Layer(
              nodes: <SceneNode>[RectNode(id: 'n', size: const Size(10, 8))],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.core, isA<SceneControllerV2>());
      expect(controller.snapshot.layers.length, 2);
      expect(controller.scene.layers.length, 2);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.mode, CanvasMode.move);
      expect(controller.drawTool, DrawTool.pen);
      expect(controller.drawColor, isA<Color>());
      expect(controller.penThickness, greaterThan(0));
      expect(controller.highlighterThickness, greaterThan(0));
      expect(controller.lineThickness, greaterThan(0));
      expect(controller.eraserThickness, greaterThan(0));
      expect(controller.highlighterOpacity, inInclusiveRange(0, 1));
      expect(controller.selectionRect, isNull);
      expect(controller.pendingLineStart, isNull);
      expect(controller.pendingLineTimestampMs, isNull);
      expect(controller.hasPendingLineStart, isFalse);
      expect(controller.pointerSettings.tapSlop, greaterThan(0));
      expect(controller.controllerEpoch, 0);
      expect(controller.structuralRevision, 0);
      expect(controller.boundsRevision, 0);
      expect(controller.visualRevision, 0);
      expect(controller.write<int>((_) => 42), 42);

      controller.penThickness = 2;
      controller.highlighterThickness = 6;
      controller.lineThickness = 3;
      controller.eraserThickness = 9;
      controller.highlighterOpacity = 0.4;
      controller.setDrawColor(const Color(0xFF336699));
      controller.setDrawColor(const Color(0xFF336699));
      controller.setPointerSettings(
        const PointerInputSettings(
          tapSlop: 12,
          doubleTapSlop: 30,
          doubleTapMaxDelayMs: 500,
        ),
      );

      expect(controller.penThickness, 2);
      expect(controller.highlighterThickness, 6);
      expect(controller.lineThickness, 3);
      expect(controller.eraserThickness, 9);
      expect(controller.highlighterOpacity, 0.4);
      expect(controller.drawColor, const Color(0xFF336699));
      expect(controller.pointerSettings.tapSlop, 12);

      expect(() => controller.penThickness = 0, throwsArgumentError);
      expect(
        () => controller.highlighterThickness = double.nan,
        throwsArgumentError,
      );
      expect(
        () => controller.lineThickness = double.infinity,
        throwsArgumentError,
      );
      expect(() => controller.eraserThickness = -1, throwsArgumentError);
      expect(() => controller.highlighterOpacity = -0.1, throwsArgumentError);
      expect(() => controller.highlighterOpacity = 1.1, throwsArgumentError);
      expect(
        () => controller.setCameraOffset(const Offset(double.nan, 0)),
        throwsArgumentError,
      );

      controller.setGridEnabled(false);
      controller.setGridCellSize(-12);
      expect(controller.snapshot.background.grid.cellSize, -12);
      controller.setGridEnabled(true);
      controller.setGridCellSize(-12);
      expect(controller.snapshot.background.grid.cellSize, 1);

      final actionSub = controller.actions.listen((_) {});
      final editSub = controller.editTextRequests.listen((_) {});
      addTearDown(actionSub.cancel);
      addTearDown(editSub.cancel);
    });

    test(
      'marquee emits select action when selection set changes with same length',
      () {
        final nodeA = RectNode(id: 'a', size: const Size(40, 40))
          ..position = const Offset(20, 20);
        final nodeB = RectNode(id: 'b', size: const Size(40, 40))
          ..position = const Offset(120, 20);
        final controller = SceneControllerInteractiveV2(
          scene: Scene(
            layers: <Layer>[
              Layer(isBackground: true),
              Layer(nodes: <SceneNode>[nodeA, nodeB]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.setSelection(const <NodeId>{'a'});
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(80, 0),
            timestampMs: 1,
            phase: PointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(180, 80),
            timestampMs: 2,
            phase: PointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(180, 80),
            timestampMs: 3,
            phase: PointerPhase.up,
          ),
        );

        expect(controller.selectedNodeIds, const <NodeId>{'b'});
        expect(actions.any((a) => a.type == ActionType.selectMarquee), isTrue);
      },
    );

    test('addNode accepts NodeSpec and legacy SceneNode variants', () {
      final controller = SceneControllerInteractiveV2(
        initialSnapshot: SceneSnapshot(
          layers: <LayerSnapshot>[
            LayerSnapshot(isBackground: true),
            LayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(
        controller.addNode(
          RectNodeSpec(id: 'spec-rect', size: const Size(10, 8)),
        ),
        'spec-rect',
      );
      expect(
        controller.addNode(
          RectNode(id: 'legacy-rect', size: const Size(10, 10)),
        ),
        'legacy-rect',
      );
      expect(
        controller.addNode(
          TextNode(
            id: 'legacy-text',
            text: 'hello',
            size: const Size(80, 20),
            color: const Color(0xFF222222),
            align: TextAlign.center,
          ),
        ),
        'legacy-text',
      );
      expect(
        controller.addNode(
          StrokeNode(
            id: 'legacy-stroke',
            points: const <Offset>[Offset(0, 0), Offset(8, 0)],
            thickness: 2,
            color: const Color(0xFF111111),
          ),
        ),
        'legacy-stroke',
      );
      expect(
        controller.addNode(
          LineNode(
            id: 'legacy-line',
            start: const Offset(0, 0),
            end: const Offset(0, 10),
            thickness: 2,
            color: const Color(0xFF111111),
          ),
        ),
        'legacy-line',
      );
      expect(
        controller.addNode(
          ImageNode(
            id: 'legacy-image',
            imageId: 'img',
            size: const Size(20, 20),
          ),
        ),
        'legacy-image',
      );
      expect(
        controller.addNode(
          PathNode(
            id: 'legacy-path',
            svgPathData: 'M0 0 L10 0 L10 10 Z',
            fillColor: const Color(0xFF00AA00),
          ),
        ),
        'legacy-path',
      );

      expect(() => controller.addNode('bad-node'), throwsArgumentError);
      expect(
        () => controller.addNode(_UnknownSceneNode(id: 'unknown')),
        throwsArgumentError,
      );
    });

    test('removeNode emits delete actions with monotonic timestamps', () async {
      final controller = SceneControllerInteractiveV2(
        initialSnapshot: SceneSnapshot(
          layers: <LayerSnapshot>[
            LayerSnapshot(isBackground: true),
            LayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      expect(controller.removeNode('missing', timestampMs: 1), isFalse);
      controller.addNode(RectNodeSpec(id: 'n1', size: const Size(10, 10)));
      expect(controller.removeNode('n1', timestampMs: 5), isTrue);

      controller.addNode(RectNodeSpec(id: 'n2', size: const Size(10, 10)));
      expect(controller.removeNode('n2', timestampMs: 3), isTrue);

      expect(actions.length, 2);
      expect(actions[0].type, ActionType.delete);
      expect(actions[0].timestampMs, 5);
      expect(actions[1].timestampMs, greaterThan(actions[0].timestampMs));
    });

    test(
      'double-tap edit request only in move mode on text top node',
      () async {
        final text = TextNode(
          id: 'text',
          text: 'note',
          size: const Size(80, 30),
          color: const Color(0xFF000000),
        )..position = const Offset(100, 100);
        final rect = RectNode(id: 'rect', size: const Size(80, 30))
          ..position = const Offset(200, 100);
        final controller = SceneControllerInteractiveV2(
          scene: Scene(
            layers: <Layer>[
              Layer(isBackground: true),
              Layer(nodes: <SceneNode>[rect, text]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        controller.setMode(CanvasMode.draw);
        controller.handlePointerSignal(
          const PointerSignal(
            type: PointerSignalType.doubleTap,
            pointerId: 1,
            position: Offset(100, 100),
            timestampMs: 10,
            kind: PointerDeviceKind.touch,
          ),
        );

        controller.setMode(CanvasMode.move);
        controller.handlePointerSignal(
          const PointerSignal(
            type: PointerSignalType.tap,
            pointerId: 1,
            position: Offset(100, 100),
            timestampMs: 11,
            kind: PointerDeviceKind.touch,
          ),
        );
        controller.handlePointerSignal(
          const PointerSignal(
            type: PointerSignalType.doubleTap,
            pointerId: 1,
            position: Offset(200, 100),
            timestampMs: 12,
            kind: PointerDeviceKind.touch,
          ),
        );
        controller.handlePointerSignal(
          const PointerSignal(
            type: PointerSignalType.doubleTap,
            pointerId: 1,
            position: Offset(100, 100),
            timestampMs: 13,
            kind: PointerDeviceKind.touch,
          ),
        );

        expect(requests.length, 1);
        expect(requests.single.nodeId, 'text');
        expect(requests.single.position, const Offset(100, 100));
      },
    );

    test('move cancel rolls back drag transform', () {
      final rect = RectNode(id: 'node', size: const Size(40, 20))
        ..position = const Offset(80, 80);
      final controller = SceneControllerInteractiveV2(
        scene: Scene(
          layers: <Layer>[
            Layer(isBackground: true),
            Layer(nodes: <SceneNode>[rect]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setSelection(const <NodeId>{'node'});

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(80, 80),
          timestampMs: 10,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(130, 80),
          timestampMs: 20,
          phase: PointerPhase.move,
        ),
      );
      final moved = _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(moved.transform.tx, greaterThan(80));

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(130, 80),
          timestampMs: 21,
          phase: PointerPhase.cancel,
        ),
      );

      final rolledBack =
          _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(rolledBack.transform.tx, closeTo(80, 1e-6));
      expect(controller.selectionRect, isNull);
    });

    test('line tool supports drag flow and two-tap pending flow', () async {
      final controller = SceneControllerInteractiveV2(
        initialSnapshot: SceneSnapshot(
          layers: <LayerSnapshot>[
            LayerSnapshot(isBackground: true),
            LayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(20, 20),
          timestampMs: 10,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(50, 20),
          timestampMs: 11,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(60, 20),
          timestampMs: 12,
          phase: PointerPhase.up,
        ),
      );
      expect(controller.hasPendingLineStart, isFalse);

      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 30,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 31,
          phase: PointerPhase.up,
        ),
      );
      expect(controller.hasPendingLineStart, isTrue);
      expect(controller.pendingLineTimestampMs, 31);

      controller.handlePointer(
        _sample(
          pointerId: 20,
          position: const Offset(220, 220),
          timestampMs: 32,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 33,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 34,
          phase: PointerPhase.up,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 40,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 41,
          phase: PointerPhase.up,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 50,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 51,
          phase: PointerPhase.up,
        ),
      );
      controller.setDrawTool(DrawTool.pen);
      expect(controller.hasPendingLineStart, isFalse);

      expect(
        actions.where((a) => a.type == ActionType.drawLine).length,
        greaterThanOrEqualTo(2),
      );

      controller.setMode(CanvasMode.move);
      controller.toggleSelection('missing');
      controller.clearSelection();
      controller.selectAll(onlySelectable: false);
      expect(controller.selectedNodeIds, isNotEmpty);
    });

    test(
      'pen commit adds up-point and eraser single point hits stroke segment',
      () {
        final controller = SceneControllerInteractiveV2(
          initialSnapshot: SceneSnapshot(
            layers: <LayerSnapshot>[
              LayerSnapshot(isBackground: true),
              LayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);
        controller.penThickness = 2;
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: PointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(13, 10),
            timestampMs: 2,
            phase: PointerPhase.up,
          ),
        );

        final strokeSnap =
            controller.snapshot.layers[1].nodes.single as StrokeNodeSnapshot;
        expect(strokeSnap.points.length, 2);

        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 20;
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 3,
            phase: PointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 4,
            phase: PointerPhase.up,
          ),
        );

        expect(controller.snapshot.layers[1].nodes, isEmpty);
      },
    );

    test('eraser removes line and stroke nodes on pointer up', () {
      final line = LineNode(
        id: 'line',
        start: const Offset(-20, 0),
        end: const Offset(20, 0),
        thickness: 2,
        color: const Color(0xFF000000),
      )..position = const Offset(120, 120);
      final stroke = StrokeNode(
        id: 'stroke',
        points: const <Offset>[Offset.zero],
        thickness: 2,
        color: const Color(0xFF000000),
      )..position = const Offset(170, 120);
      final controller = SceneControllerInteractiveV2(
        scene: Scene(
          layers: <Layer>[
            Layer(isBackground: true),
            Layer(nodes: <SceneNode>[line, stroke]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.eraser);
      controller.eraserThickness = 30;

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(120, 120),
          timestampMs: 10,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(120, 120),
          timestampMs: 11,
          phase: PointerPhase.up,
        ),
      );

      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(170, 120),
          timestampMs: 20,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(176, 120),
          timestampMs: 21,
          phase: PointerPhase.up,
        ),
      );

      final ids = <NodeId>{
        for (final layer in controller.snapshot.layers)
          for (final node in layer.nodes) node.id,
      };
      expect(ids.contains('line'), isFalse);
      expect(ids.contains('stroke'), isFalse);

      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(10, 10),
          timestampMs: 30,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(10, 10),
          timestampMs: 31,
          phase: PointerPhase.cancel,
        ),
      );
    });

    test('transform/delete/clear/notify scene APIs emit expected effects', () {
      final rect = RectNode(id: 'r', size: const Size(20, 10))
        ..position = const Offset(50, 50);
      final locked = RectNode(
        id: 'locked',
        size: const Size(20, 10),
        isLocked: true,
        isDeletable: false,
      )..position = const Offset(90, 50);
      final controller = SceneControllerInteractiveV2(
        scene: Scene(
          layers: <Layer>[
            Layer(isBackground: true),
            Layer(nodes: <SceneNode>[rect, locked]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      final visualBefore = controller.visualRevision;
      controller.notifySceneChanged();
      expect(controller.visualRevision, greaterThan(visualBefore));

      controller.setSelection(const <NodeId>{'r', 'locked'});
      controller.rotateSelection(clockwise: true, timestampMs: 100);
      controller.flipSelectionHorizontal(timestampMs: 101);
      controller.flipSelectionVertical(timestampMs: 102);
      controller.deleteSelection(timestampMs: 103);
      expect(_nodeById(controller.snapshot, 'locked').id, 'locked');

      controller.clearScene(timestampMs: 104);
      final remaining = <NodeId>{
        for (final layer in controller.snapshot.layers)
          for (final node in layer.nodes) node.id,
      };
      expect(remaining.contains('locked'), isFalse);

      expect(actions.any((a) => a.type == ActionType.transform), isTrue);
      expect(actions.any((a) => a.type == ActionType.delete), isTrue);
      expect(actions.any((a) => a.type == ActionType.clear), isTrue);
    });

    test('move drag up emits transform action with delta payload', () async {
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = SceneControllerInteractiveV2(
        scene: Scene(
          layers: <Layer>[
            Layer(isBackground: true),
            Layer(nodes: <SceneNode>[rect]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.setSelection(const <NodeId>{'node'});
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(60, 60),
          timestampMs: 1,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(90, 60),
          timestampMs: 2,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(100, 60),
          timestampMs: 3,
          phase: PointerPhase.up,
        ),
      );

      final transformActions = actions.where(
        (a) => a.type == ActionType.transform,
      );
      expect(transformActions, isNotEmpty);
      expect(transformActions.last.payload?['delta'], isNotNull);
    });

    test(
      'dispose clears pending line timer and supports replaceScene',
      () async {
        final controller = SceneControllerInteractiveV2(
          initialSnapshot: SceneSnapshot(
            layers: <LayerSnapshot>[
              LayerSnapshot(isBackground: true),
              LayerSnapshot(),
            ],
          ),
        );

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.line);
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: PointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: PointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.replaceScene(
          SceneSnapshot(
            layers: <LayerSnapshot>[
              LayerSnapshot(isBackground: true),
              LayerSnapshot(
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(id: 'new', size: Size(5, 5)),
                ],
              ),
            ],
          ),
        );
        expect(controller.hasPendingLineStart, isFalse);
        expect(_nodeById(controller.snapshot, 'new').id, 'new');

        controller.dispose();
      },
    );
  });
}

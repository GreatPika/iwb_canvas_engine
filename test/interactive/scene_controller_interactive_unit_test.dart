import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/grid_safety_limits.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller_interactive.dart'
    show
        sceneControllerInteractiveInternalActiveEraserPointsLength,
        sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount,
        sceneControllerInteractiveInternalEraserSpatialQueryCount,
        sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest,
        sceneControllerInteractiveInternalSetBeforePointerDispatchHook;
import 'package:iwb_canvas_engine/src/model/document.dart';

NodeSnapshot _nodeById(SceneSnapshot snapshot, NodeId id) {
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (node.id == id) return node;
    }
  }
  throw StateError('Node not found: $id');
}

CanvasPointerInput _sample({
  required int pointerId,
  required Offset position,
  required int timestampMs,
  required CanvasPointerPhase phase,
}) {
  return CanvasPointerInput(
    pointerId: pointerId,
    position: position,
    timestampMs: timestampMs,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}

SceneControllerInteractive _controllerFromScene(
  Scene scene, {
  PointerInputSettings? pointerSettings,
  double? dragStartSlop,
  bool clearSelectionOnDrawModeEnter = false,
}) {
  return SceneControllerInteractive(
    initialSnapshot: txnSceneToSnapshot(scene),
    pointerSettings: pointerSettings,
    dragStartSlop: dragStartSlop,
    clearSelectionOnDrawModeEnter: clearSelectionOnDrawModeEnter,
  );
}

StrokeNode _horizontalStroke({
  required String id,
  required double y,
  required double length,
  required double step,
  required double thickness,
}) {
  final points = <Offset>[];
  for (var x = 0.0; x <= length; x += step) {
    points.add(Offset(x, y));
  }
  if (points.last.dx != length) {
    points.add(Offset(length, y));
  }
  return StrokeNode(
    id: id,
    points: points,
    thickness: thickness,
    color: const Color(0xFF000000),
  );
}

typedef _InteractiveMutatingCall =
    void Function(SceneControllerInteractive controller);

class _InteractiveControllerStableState {
  const _InteractiveControllerStableState({
    required this.snapshot,
    required this.selection,
    required this.mode,
    required this.drawTool,
    required this.drawColor,
    required this.penThickness,
    required this.highlighterThickness,
    required this.lineThickness,
    required this.eraserThickness,
    required this.highlighterOpacity,
    required this.dragStartSlop,
    required this.pointerSettings,
    required this.selectionRect,
    required this.pendingLineStart,
    required this.pendingLineTimestampMs,
    required this.hasPendingLineStart,
  });

  final SceneSnapshot snapshot;
  final Set<NodeId> selection;
  final CanvasMode mode;
  final DrawTool drawTool;
  final Color drawColor;
  final double penThickness;
  final double highlighterThickness;
  final double lineThickness;
  final double eraserThickness;
  final double highlighterOpacity;
  final double dragStartSlop;
  final PointerInputSettings pointerSettings;
  final Rect? selectionRect;
  final Offset? pendingLineStart;
  final int? pendingLineTimestampMs;
  final bool hasPendingLineStart;
}

class _DisposeMatrixCase {
  const _DisposeMatrixCase({required this.name, required this.call});

  final String name;
  final _InteractiveMutatingCall call;
}

_InteractiveControllerStableState _captureStableState(
  SceneControllerInteractive controller,
) {
  return _InteractiveControllerStableState(
    snapshot: controller.snapshot,
    selection: controller.selectedNodeIds,
    mode: controller.mode,
    drawTool: controller.drawTool,
    drawColor: controller.drawColor,
    penThickness: controller.penThickness,
    highlighterThickness: controller.highlighterThickness,
    lineThickness: controller.lineThickness,
    eraserThickness: controller.eraserThickness,
    highlighterOpacity: controller.highlighterOpacity,
    dragStartSlop: controller.dragStartSlop,
    pointerSettings: controller.pointerSettings,
    selectionRect: controller.selectionRect,
    pendingLineStart: controller.pendingLineStart,
    pendingLineTimestampMs: controller.pendingLineTimestampMs,
    hasPendingLineStart: controller.hasPendingLineStart,
  );
}

void _expectStableStateUnchanged(
  SceneControllerInteractive controller,
  _InteractiveControllerStableState before,
) {
  expect(controller.snapshot, same(before.snapshot));
  expect(controller.selectedNodeIds, before.selection);
  expect(controller.mode, before.mode);
  expect(controller.drawTool, before.drawTool);
  expect(controller.drawColor, before.drawColor);
  expect(controller.penThickness, before.penThickness);
  expect(controller.highlighterThickness, before.highlighterThickness);
  expect(controller.lineThickness, before.lineThickness);
  expect(controller.eraserThickness, before.eraserThickness);
  expect(controller.highlighterOpacity, before.highlighterOpacity);
  expect(controller.dragStartSlop, before.dragStartSlop);
  expect(controller.pointerSettings, before.pointerSettings);
  expect(controller.selectionRect, before.selectionRect);
  expect(controller.pendingLineStart, before.pendingLineStart);
  expect(controller.pendingLineTimestampMs, before.pendingLineTimestampMs);
  expect(controller.hasPendingLineStart, before.hasPendingLineStart);
}

void main() {
  group('SceneControllerInteractive unit', () {
    test('read API + setters + validation', () {
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(
              nodes: <SceneNode>[RectNode(id: 'n', size: const Size(10, 8))],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.snapshot.layers.length, 2);
      expect(controller.snapshot.layers.length, 2);
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
      expect(controller.hasActiveLinePreview, isFalse);
      expect(controller.pointerSettings.tapSlop, greaterThan(0));
      expect(controller.dragStartSlop, controller.pointerSettings.tapSlop);
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
      expect(controller.dragStartSlop, 12);

      controller.setDragStartSlop(9);
      expect(controller.dragStartSlop, 9);
      controller.setDragStartSlop(null);
      expect(controller.dragStartSlop, 12);

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
      expect(() => controller.setDragStartSlop(-1), throwsArgumentError);
      expect(() => controller.highlighterOpacity = -0.1, throwsArgumentError);
      expect(() => controller.highlighterOpacity = 1.1, throwsArgumentError);
      expect(
        () => controller.setCameraOffset(const Offset(double.nan, 0)),
        throwsArgumentError,
      );

      controller.setGridEnabled(false);
      expect(() => controller.setGridCellSize(-12), throwsArgumentError);
      controller.setGridEnabled(true);
      controller.setGridCellSize(0.5);
      expect(controller.snapshot.background.grid.cellSize, kMinGridCellSize);

      final actionSub = controller.actions.listen((_) {});
      final editSub = controller.editTextRequests.listen((_) {});
      addTearDown(actionSub.cancel);
      addTearDown(editSub.cancel);
    });

    test('handlePointer notifications are deferred', () async {
      // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
      final controller = _controllerFromScene(
        Scene(layers: <ContentLayer>[ContentLayer(), ContentLayer()]),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );

      expect(notifications, 0);
      await pumpEventQueue();
      expect(notifications, 1);
    });

    test('interactive notify coalesces within same tick', () async {
      // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
      final controller = _controllerFromScene(
        Scene(layers: <ContentLayer>[ContentLayer(), ContentLayer()]),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);
      controller.setDrawColor(const Color(0xFF123456));
      controller.setDragStartSlop(9);

      expect(notifications, 0);
      await pumpEventQueue();
      expect(notifications, 1);
    });

    test('core-change forwarding is deferred', () async {
      final node = RectNode(id: 'n', size: const Size(10, 10))
        ..position = const Offset(10, 10);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[node]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.setSelection(const <NodeId>{'n'});

      expect(notifications, 0);
      await pumpEventQueue(times: 2);
      expect(notifications, 1);
    });

    test('reentrant handlePointer throws StateError', () {
      final controller = _controllerFromScene(
        Scene(layers: <ContentLayer>[ContentLayer(), ContentLayer()]),
      );
      addTearDown(controller.dispose);

      final sample = _sample(
        pointerId: 1,
        position: const Offset(100, 100),
        timestampMs: 1,
        phase: CanvasPointerPhase.down,
      );

      Object? nestedError;
      sceneControllerInteractiveInternalSetBeforePointerDispatchHook(
        controller,
        () {
          sceneControllerInteractiveInternalSetBeforePointerDispatchHook(
            controller,
            null,
          );
          try {
            controller.handlePointer(sample);
          } catch (error) {
            nestedError = error;
          }
        },
      );

      controller.handlePointer(sample);
      expect(nestedError, isA<StateError>());
    });

    test(
      'marquee emits select action when selection set changes with same length',
      () async {
        final nodeA = RectNode(id: 'a', size: const Size(40, 40))
          ..position = const Offset(20, 20);
        final nodeB = RectNode(id: 'b', size: const Size(40, 40))
          ..position = const Offset(120, 20);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[nodeA, nodeB]),
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
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(180, 80),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(180, 80),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.selectedNodeIds, const <NodeId>{'b'});
        await pumpEventQueue();
        expect(actions.any((a) => a.type == ActionType.selectMarquee), isTrue);
      },
    );

    test('addNode accepts NodeSpec variants', () {
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
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
          TextNodeSpec(
            id: 'spec-text',
            text: 'hello',
            color: const Color(0xFF222222),
            align: TextAlign.center,
          ),
        ),
        'spec-text',
      );
      expect(
        controller.addNode(
          StrokeNodeSpec(
            id: 'spec-stroke',
            points: const <Offset>[Offset(0, 0), Offset(8, 0)],
            thickness: 2,
            color: const Color(0xFF222222),
          ),
        ),
        'spec-stroke',
      );
      expect(
        controller.addNode(
          LineNodeSpec(
            id: 'spec-line',
            start: const Offset(0, 0),
            end: const Offset(0, 10),
            thickness: 2,
            color: const Color(0xFF111111),
          ),
        ),
        'spec-line',
      );
      expect(
        controller.addNode(
          ImageNodeSpec(
            id: 'spec-image',
            imageId: 'img',
            size: const Size(20, 20),
          ),
        ),
        'spec-image',
      );
      expect(
        controller.addNode(
          PathNodeSpec(
            id: 'spec-path',
            svgPathData: 'M0 0 L10 0 L10 10 Z',
            fillColor: const Color(0xFF00AA00),
          ),
        ),
        'spec-path',
      );
    });

    test(
      'handlePointer accepts null timestamp hint and keeps monotonic time',
      () async {
        final controller = _controllerFromScene(
          Scene(layers: <ContentLayer>[ContentLayer(), ContentLayer()]),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(12, 12),
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
        );
        controller.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(20, 20),
            phase: CanvasPointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
        );

        controller.handlePointer(
          const CanvasPointerInput(
            pointerId: 2,
            position: Offset(30, 30),
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
        );
        controller.handlePointer(
          const CanvasPointerInput(
            pointerId: 2,
            position: Offset(40, 40),
            phase: CanvasPointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
        );

        await pumpEventQueue();

        expect(actions, hasLength(2));
        expect(actions.first.type, ActionType.drawStroke);
        expect(actions.last.type, ActionType.drawStroke);
        expect(
          actions.last.timestampMs,
          greaterThan(actions.first.timestampMs),
        );
      },
    );

    test('removeNode emits delete actions with monotonic timestamps', () async {
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
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

      await pumpEventQueue();
      expect(actions.length, 2);
      expect(actions[0].type, ActionType.delete);
      expect(actions[0].timestampMs, 5);
      expect(actions[1].timestampMs, greaterThan(actions[0].timestampMs));
    });

    test('actions stream delivery is asynchronous', () async {
      // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.addNode(RectNodeSpec(id: 'n1', size: const Size(10, 10)));

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      expect(controller.removeNode('n1', timestampMs: 5), isTrue);
      expect(actions, isEmpty);

      await pumpEventQueue();

      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.delete);
    });

    test(
      'interactive action stream and notify are async without strict ordering contract',
      () async {
        // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(id: 'n1', size: Size(10, 10)),
                ],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final trace = <String>[];
        controller.addListener(() {
          trace.add('notify');
        });
        final sub = controller.actions.listen((_) {
          trace.add('action');
        });
        addTearDown(sub.cancel);

        expect(controller.removeNode('n1', timestampMs: 5), isTrue);
        expect(trace, isEmpty);

        await pumpEventQueue(times: 2);

        expect(trace.where((entry) => entry == 'action'), hasLength(1));
        expect(trace.where((entry) => entry == 'notify'), hasLength(1));
      },
    );

    // Gap matrix (P2 hardening):
    // - invalid pointer data: existing non-finite down/move + new up/cancel recovery
    // - long gesture guardrails: existing pen/eraser + new highlighter commit/preview
    // - line pending cancel semantics: existing cancel clear + new invalid second-tap no-op
    // - single-active-pointer semantics: existing move/draw policy group
    group('interactive hardening: invalid pointer data', () {
      test(
        'invalid pointer coordinates are ignored without side effects',
        () async {
          // INV:INV-ENG-INTERACTIVE-POINTER-FINITE
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
              ],
            ),
          );
          addTearDown(controller.dispose);
          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.pen);

          final actions = <ActionCommitted>[];
          final edits = <EditTextRequested>[];
          final actionSub = controller.actions.listen(actions.add);
          final editSub = controller.editTextRequests.listen(edits.add);
          addTearDown(actionSub.cancel);
          addTearDown(editSub.cancel);

          final beforeSnapshot = controller.snapshot;

          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(double.nan, 0),
                phase: CanvasPointerPhase.down,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );
          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(double.infinity, 1),
                phase: CanvasPointerPhase.move,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );
          expect(controller.snapshot, same(beforeSnapshot));
          expect(controller.selectedNodeIds, isEmpty);
          expect(controller.hasActiveStrokePreview, isFalse);
          expect(controller.hasActiveLinePreview, isFalse);
          expect(controller.hasPendingLineStart, isFalse);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(10, 10),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
          );
          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(20, 20),
              phase: CanvasPointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
          );

          await pumpEventQueue();
          expect(actions, hasLength(1));
          expect(actions.single.type, ActionType.drawStroke);
          expect(actions.single.timestampMs, 1);
          expect(edits, isEmpty);
        },
      );

      test(
        'invalid up/cancel coordinates are ignored and gesture can recover',
        () async {
          // INV:INV-ENG-INTERACTIVE-POINTER-FINITE
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
              ],
            ),
          );
          addTearDown(controller.dispose);
          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.pen);

          final actions = <ActionCommitted>[];
          final actionSub = controller.actions.listen(actions.add);
          addTearDown(actionSub.cancel);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(10, 10),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
          );
          expect(controller.hasActiveStrokePreview, isTrue);

          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(double.nan, 20),
                phase: CanvasPointerPhase.up,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );
          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(20, double.infinity),
                phase: CanvasPointerPhase.cancel,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );

          await pumpEventQueue();
          expect(actions, isEmpty);
          expect(controller.hasActiveStrokePreview, isTrue);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(10, 10),
              phase: CanvasPointerPhase.cancel,
              kind: PointerDeviceKind.touch,
            ),
          );
          expect(controller.hasActiveStrokePreview, isFalse);
          expect(controller.activeStrokePreviewPoints, isEmpty);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(30, 30),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
          );
          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(40, 30),
              phase: CanvasPointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
          );

          await pumpEventQueue();
          expect(actions, hasLength(1));
          expect(actions.single.type, ActionType.drawStroke);
        },
      );

      test('invalid double-tap coordinates are ignored', () async {
        // INV:INV-ENG-INTERACTIVE-POINTER-FINITE
        final text = TextNode(
          id: 'text',
          text: 'note',
          size: const Size(80, 30),
          color: const Color(0xFF000000),
        )..position = const Offset(100, 100);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[text]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        expect(
          () => controller.handleDoubleTap(
            position: const Offset(double.nan, 100),
            timestampMs: 10,
          ),
          returnsNormally,
        );
        expect(
          () => controller.handleDoubleTap(
            position: const Offset(100, double.infinity),
            timestampMs: 11,
          ),
          returnsNormally,
        );

        controller.handleDoubleTap(
          position: const Offset(100, 100),
          timestampMs: 12,
        );

        await pumpEventQueue();
        expect(requests, hasLength(1));
        expect(requests.single.nodeId, 'text');
        expect(requests.single.timestampMs, 12);
      });
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
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect, text]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        controller.setMode(CanvasMode.draw);
        controller.handleDoubleTap(
          position: const Offset(100, 100),
          timestampMs: 10,
        );

        controller.setMode(CanvasMode.move);
        controller.handleDoubleTap(
          position: const Offset(200, 100),
          timestampMs: 12,
        );
        controller.handleDoubleTap(
          position: const Offset(100, 100),
          timestampMs: 13,
        );

        await pumpEventQueue();
        expect(requests.length, 1);
        expect(requests.single.nodeId, 'text');
        expect(requests.single.position, const Offset(100, 100));
      },
    );

    test('editTextRequests stream delivery is asynchronous', () async {
      // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
      final text = TextNode(
        id: 'text',
        text: 'note',
        size: const Size(80, 30),
        color: const Color(0xFF000000),
      )..position = const Offset(100, 100);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[text]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final requests = <EditTextRequested>[];
      final sub = controller.editTextRequests.listen(requests.add);
      addTearDown(sub.cancel);

      controller.handleDoubleTap(
        position: const Offset(100, 100),
        timestampMs: 10,
      );
      expect(requests, isEmpty);

      await pumpEventQueue();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, 'text');
    });

    test('hit-test uses preview-shifted geometry during move drag', () async {
      final text = TextNode(
        id: 'text',
        text: 'note',
        size: const Size(40, 20),
        color: const Color(0xFF000000),
      )..position = const Offset(100, 100);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[text]),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.setSelection(const <NodeId>{'text'});
      final textSnapshotBeforeMove =
          _nodeById(controller.snapshot, 'text') as TextNodeSnapshot;
      final originalCenter = Offset(
        textSnapshotBeforeMove.transform.tx,
        textSnapshotBeforeMove.transform.ty,
      );
      final originalOnlyPoint = Offset(
        originalCenter.dx - textSnapshotBeforeMove.size.width / 2 + 2,
        originalCenter.dy,
      );
      final movedPoint = originalCenter.translate(40, 0);

      final requests = <EditTextRequested>[];
      final sub = controller.editTextRequests.listen(requests.add);
      addTearDown(sub.cancel);

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: originalCenter,
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: movedPoint,
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );

      controller.handleDoubleTap(position: movedPoint, timestampMs: 3);
      controller.handleDoubleTap(position: originalOnlyPoint, timestampMs: 4);

      await pumpEventQueue();
      expect(requests.length, 1);
      expect(requests.single.nodeId, 'text');
      expect(requests.single.position, movedPoint);
    });

    test('move cancel keeps document unchanged and clears preview', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final rect = RectNode(id: 'node', size: const Size(40, 20))
        ..position = const Offset(80, 80);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[rect]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setSelection(const <NodeId>{'node'});
      final beforeNode =
          _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(80, 80),
          timestampMs: 10,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(130, 80),
          timestampMs: 20,
          phase: CanvasPointerPhase.move,
        ),
      );
      final duringMove =
          _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(duringMove.transform.tx, closeTo(beforeNode.transform.tx, 1e-6));

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(130, 80),
          timestampMs: 21,
          phase: CanvasPointerPhase.cancel,
        ),
      );

      final afterCancel =
          _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(afterCancel.transform.tx, closeTo(beforeNode.transform.tx, 1e-6));
      expect(afterCancel.transform.ty, closeTo(beforeNode.transform.ty, 1e-6));
      expect(controller.selectionRect, isNull);
    });

    test('move drag commits once on up and applies total delta exactly', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[rect]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setSelection(const <NodeId>{'node'});

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(60, 60),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );

      var position = const Offset(60, 60);
      for (var i = 0; i < 50; i++) {
        position = Offset(position.dx + 1, position.dy + 2);
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: position,
            timestampMs: 2 + i,
            phase: CanvasPointerPhase.move,
          ),
        );
      }

      final beforeUp =
          _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(beforeUp.transform.tx, closeTo(60, 1e-6));
      expect(beforeUp.transform.ty, closeTo(60, 1e-6));

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: position,
          timestampMs: 100,
          phase: CanvasPointerPhase.up,
        ),
      );

      final afterUp =
          _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(afterUp.transform.tx, closeTo(110, 1e-6));
      expect(afterUp.transform.ty, closeTo(160, 1e-6));
    });

    test(
      'move drag start threshold uses dragStartSlop and null fallback uses tapSlop',
      () {
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect]),
            ],
          ),
          pointerSettings: const PointerInputSettings(tapSlop: 4),
          dragStartSlop: 12,
        );
        addTearDown(controller.dispose);

        controller.setSelection(const <NodeId>{'node'});

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(66, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(66, 60),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        final afterCustomSlop =
            _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterCustomSlop.transform.tx, closeTo(60, 1e-6));
        expect(afterCustomSlop.transform.ty, closeTo(60, 1e-6));

        controller.setDragStartSlop(null);
        expect(controller.dragStartSlop, 4);

        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(60, 60),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(66, 60),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(66, 60),
            timestampMs: 6,
            phase: CanvasPointerPhase.up,
          ),
        );

        final afterFallbackSlop =
            _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterFallbackSlop.transform.tx, closeTo(66, 1e-6));
        expect(afterFallbackSlop.transform.ty, closeTo(60, 1e-6));
      },
    );

    // Gap matrix axis: single-active-pointer semantics.
    group('single-active-pointer policy', () {
      test(
        'move mode ignores parallel pointer ids until active pointer ends',
        () {
          // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
          final rect = RectNode(id: 'node', size: const Size(30, 20))
            ..position = const Offset(60, 60);
          final controller = _controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(),
                ContentLayer(nodes: <SceneNode>[rect]),
              ],
            ),
          );
          addTearDown(controller.dispose);
          controller.setSelection(const <NodeId>{'node'});

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(60, 60),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );

          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(60, 60),
              timestampMs: 2,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(120, 60),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(120, 60),
              timestampMs: 4,
              phase: CanvasPointerPhase.up,
            ),
          );

          final afterParallelPointer =
              _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
          expect(afterParallelPointer.transform.tx, closeTo(60, 1e-6));
          expect(afterParallelPointer.transform.ty, closeTo(60, 1e-6));

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(90, 60),
              timestampMs: 5,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(90, 60),
              timestampMs: 6,
              phase: CanvasPointerPhase.up,
            ),
          );

          final afterPrimaryPointer =
              _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
          expect(afterPrimaryPointer.transform.tx, closeTo(90, 1e-6));
          expect(afterPrimaryPointer.transform.ty, closeTo(60, 1e-6));
        },
      );

      test('move mode releases active-pointer lock after cancel', () {
        // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect]),
            ],
          ),
        );
        addTearDown(controller.dispose);
        controller.setSelection(const <NodeId>{'node'});

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(100, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(120, 60),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(150, 60),
            timestampMs: 4,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(150, 60),
            timestampMs: 5,
            phase: CanvasPointerPhase.up,
          ),
        );

        final beforeCancel =
            _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(beforeCancel.transform.tx, closeTo(60, 1e-6));
        expect(beforeCancel.transform.ty, closeTo(60, 1e-6));

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(100, 60),
            timestampMs: 6,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(60, 60),
            timestampMs: 7,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(90, 60),
            timestampMs: 8,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(90, 60),
            timestampMs: 9,
            phase: CanvasPointerPhase.up,
          ),
        );

        final afterCancelRecovery =
            _nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterCancelRecovery.transform.tx, closeTo(90, 1e-6));
        expect(afterCancelRecovery.transform.ty, closeTo(60, 1e-6));
      });

      test(
        'draw line ignores parallel pointer ids and accepts new pointer after up',
        () async {
          // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
              ],
            ),
            dragStartSlop: 0.001,
          );
          addTearDown(controller.dispose);
          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.line);

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(10, 10),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(50, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(80, 10),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(80, 10),
              timestampMs: 4,
              phase: CanvasPointerPhase.up,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(30, 10),
              timestampMs: 5,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(30, 10),
              timestampMs: 6,
              phase: CanvasPointerPhase.up,
            ),
          );

          await pumpEventQueue();
          expect(
            actions.where((a) => a.type == ActionType.drawLine),
            hasLength(1),
          );

          final lineNodes = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<LineNodeSnapshot>()
              .toList(growable: false);
          expect(lineNodes, hasLength(1));
          final committed = lineNodes.single;
          expect(
            committed.transform.applyToPoint(committed.start),
            const Offset(10, 10),
          );
          expect(
            committed.transform.applyToPoint(committed.end),
            const Offset(30, 10),
          );

          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(100, 100),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(100, 100),
              timestampMs: 8,
              phase: CanvasPointerPhase.up,
            ),
          );
          expect(controller.hasPendingLineStart, isTrue);
        },
      );

      test(
        'draw pen ignores parallel pointer ids and recovers after cancel',
        () async {
          // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
              ],
            ),
          );
          addTearDown(controller.dispose);
          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.pen);

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(10, 10),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(20, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );

          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(100, 100),
              timestampMs: 3,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(120, 100),
              timestampMs: 4,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(120, 100),
              timestampMs: 5,
              phase: CanvasPointerPhase.up,
            ),
          );

          expect(controller.hasActiveStrokePreview, isTrue);
          expect(
            controller.activeStrokePreviewPoints.first,
            const Offset(10, 10),
          );
          expect(
            controller.activeStrokePreviewPoints.last,
            const Offset(20, 10),
          );

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(20, 10),
              timestampMs: 6,
              phase: CanvasPointerPhase.cancel,
            ),
          );
          expect(controller.hasActiveStrokePreview, isFalse);

          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(30, 10),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(40, 10),
              timestampMs: 8,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(40, 10),
              timestampMs: 9,
              phase: CanvasPointerPhase.up,
            ),
          );

          await pumpEventQueue();
          expect(
            actions.where((event) => event.type == ActionType.drawStroke),
            hasLength(1),
          );

          final strokeNodes = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>()
              .toList(growable: false);
          expect(strokeNodes, hasLength(1));
          final stroke = strokeNodes.single;
          expect(
            stroke.transform.applyToPoint(stroke.points.first),
            const Offset(30, 10),
          );
          expect(
            stroke.transform.applyToPoint(stroke.points.last),
            const Offset(40, 10),
          );
        },
      );
    });

    test('line tool supports drag flow and two-tap pending flow', () async {
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);
      controller.setDragStartSlop(0.001);

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(20, 20),
          timestampMs: 10,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.hasActiveLinePreview, isFalse);
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(50, 20),
          timestampMs: 11,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.activeLinePreviewStart, const Offset(20, 20));
      expect(controller.activeLinePreviewEnd, const Offset(50, 20));
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(60, 20),
          timestampMs: 12,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.hasActiveLinePreview, isFalse);
      expect(controller.hasPendingLineStart, isFalse);

      final dragLine = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .whereType<LineNodeSnapshot>()
          .first;
      expect(dragLine.transform.tx, 40);
      expect(dragLine.transform.ty, 20);
      expect(dragLine.start, const Offset(-20, 0));
      expect(dragLine.end, const Offset(20, 0));
      expect(
        dragLine.transform.applyToPoint(dragLine.start),
        const Offset(20, 20),
      );
      expect(
        dragLine.transform.applyToPoint(dragLine.end),
        const Offset(60, 20),
      );

      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 30,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 31,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.hasPendingLineStart, isTrue);
      expect(controller.pendingLineTimestampMs, 31);

      controller.handlePointer(
        _sample(
          pointerId: 20,
          position: const Offset(220, 220),
          timestampMs: 32,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 33,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.activeLinePreviewStart, const Offset(220, 220));
      expect(controller.activeLinePreviewEnd, const Offset(280, 220));
      controller.handlePointer(
        _sample(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 34,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 40,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 41,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 50,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 51,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.setDrawTool(DrawTool.pen);
      expect(controller.hasPendingLineStart, isFalse);

      await pumpEventQueue();
      expect(
        actions.where((a) => a.type == ActionType.drawLine).length,
        greaterThanOrEqualTo(2),
      );
      final lines = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .whereType<LineNodeSnapshot>();
      expect(
        lines.any((line) {
          final worldStart = line.transform.applyToPoint(line.start);
          final worldEnd = line.transform.applyToPoint(line.end);
          return worldStart == const Offset(130, 130) &&
              worldEnd == const Offset(150, 150);
        }),
        isTrue,
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
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
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
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(13, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );

        final strokeSnap = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<StrokeNodeSnapshot>()
            .single;
        expect(strokeSnap.points.length, 2);

        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 20;
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 4,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(
          controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>(),
          isEmpty,
        );
      },
    );

    group('interactive hardening: long gesture guardrails', () {
      test('pen commit caps very long stroke and preserves endpoints', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);
        controller.penThickness = 2;

        const totalRawPoints = 20050;
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i < totalRawPoints - 1; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: Offset((totalRawPoints - 1).toDouble(), 0),
            timestampMs: totalRawPoints + 1,
            phase: CanvasPointerPhase.up,
          ),
        );

        final strokeSnap = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<StrokeNodeSnapshot>()
            .single;
        expect(strokeSnap.points.length, 20000);
        expect(strokeSnap.points.first, const Offset(0, 0));
        expect(
          strokeSnap.points.last,
          Offset((totalRawPoints - 1).toDouble(), 0),
        );
      });

      test('pen preview buffer is soft-capped during long move', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        for (var i = 1; i <= 26000; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.hasActiveStrokePreview, isTrue);
        expect(
          controller.activeStrokePreviewPoints.length,
          lessThanOrEqualTo(kInteractiveStrokePointsSoftLimit),
        );
      });

      test('soft-capped stroke preview keeps endpoints after pruning', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        const latestPoint = Offset(26000, 0);
        for (var i = 1; i <= latestPoint.dx; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.activeStrokePreviewPoints, isNotEmpty);
        expect(controller.activeStrokePreviewPoints.first, const Offset(0, 0));
        expect(controller.activeStrokePreviewPoints.last, latestPoint);
      });

      test(
        'highlighter long preview and commit keep soft-limit and endpoints',
        () async {
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.highlighter);
          controller.highlighterThickness = 7;
          controller.highlighterOpacity = 0.35;

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          const latestPoint = Offset(26000, 0);
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= latestPoint.dx; i++) {
            controller.handlePointer(
              _sample(
                pointerId: 1,
                position: Offset(i.toDouble(), 0),
                timestampMs: i + 1,
                phase: CanvasPointerPhase.move,
              ),
            );
          }
          expect(
            controller.activeStrokePreviewPoints.length,
            lessThanOrEqualTo(kInteractiveStrokePointsSoftLimit),
          );
          expect(
            controller.activeStrokePreviewPoints.first,
            const Offset(0, 0),
          );
          expect(controller.activeStrokePreviewPoints.last, latestPoint);

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: latestPoint,
              timestampMs: 26002,
              phase: CanvasPointerPhase.up,
            ),
          );
          await pumpEventQueue();

          expect(
            actions.where((a) => a.type == ActionType.drawHighlighter),
            hasLength(1),
          );
          final strokeSnap = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>()
              .single;
          expect(strokeSnap.points.first, const Offset(0, 0));
          expect(strokeSnap.points.last, latestPoint);
          expect(strokeSnap.points.length, lessThanOrEqualTo(20000));
          expect(strokeSnap.opacity, closeTo(0.35, 1e-6));
        },
      );

      test('eraser long gesture remains bounded and erases near both ends', () {
        final startLine = LineNode(
          id: 'line-start',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(20, 50);
        final endLine = LineNode(
          id: 'line-end',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(9000, 50);

        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[startLine, endLine]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 24;

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(20, 50),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 21; i <= 9000; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 50),
              timestampMs: i,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(9000, 50),
            timestampMs: 9001,
            phase: CanvasPointerPhase.up,
          ),
        );

        final ids = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(ids.contains('line-start'), isFalse);
        expect(ids.contains('line-end'), isFalse);
      });

      test('long eraser stress keeps correctness on dense scene', () {
        const gestureLength = 4096;
        final nodes = <SceneNode>[];
        for (var i = 0; i < 40; i++) {
          final y = i.isEven ? 0.0 : 12.0;
          nodes.add(
            _horizontalStroke(
              id: 'stroke-$i',
              y: y,
              length: gestureLength.toDouble(),
              step: 8,
              thickness: 2,
            ),
          );
        }
        for (var i = 0; i < 20; i++) {
          nodes.add(
            _horizontalStroke(
              id: 'far-$i',
              y: 220 + i.toDouble(),
              length: gestureLength.toDouble(),
              step: 8,
              thickness: 2,
            ),
          );
        }

        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: nodes),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 20;

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= gestureLength; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: Offset(gestureLength.toDouble(), 0),
            timestampMs: gestureLength + 2,
            phase: CanvasPointerPhase.up,
          ),
        );

        final ids = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        for (var i = 0; i < 40; i++) {
          expect(
            ids.contains('stroke-$i'),
            i.isEven ? isFalse : isTrue,
            reason: 'stroke-$i',
          );
        }
        for (var i = 0; i < 20; i++) {
          expect(ids.contains('far-$i'), isTrue, reason: 'far-$i');
        }
      });

      test('long eraser commit keeps bounded query/check complexity', () {
        const gestureLength = 4096;
        final nodes = <SceneNode>[];
        for (var i = 0; i < 32; i++) {
          final y = i.isEven ? 0.0 : 12.0;
          nodes.add(
            _horizontalStroke(
              id: 'stress-$i',
              y: y,
              length: gestureLength.toDouble(),
              step: 8,
              thickness: 2,
            ),
          );
        }

        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: nodes),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 20;

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= gestureLength; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        final stopwatch = Stopwatch()..start();
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: Offset(gestureLength.toDouble(), 0),
            timestampMs: gestureLength + 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        stopwatch.stop();

        final spatialQueryCount =
            sceneControllerInteractiveInternalEraserSpatialQueryCount(
              controller,
            );
        final preciseChecks =
            sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
              controller,
            );
        final expectedBatchQueryUpperBound = (gestureLength / 64).ceil() + 2;

        // Deterministic perf guards are primary acceptance criteria.
        expect(
          spatialQueryCount,
          lessThanOrEqualTo(expectedBatchQueryUpperBound),
        );
        expect(preciseChecks, lessThan(500000));
        // Wall-clock bound is a secondary smoke guard only; if CI is noisy,
        // deterministic counters above remain source-of-truth for regressions.
        expect(stopwatch.elapsedMilliseconds, lessThan(2500));
      });

      test(
        'eraser zigzag path keeps coarse prefilter correctness and bounded checks',
        () {
          const zigzagLength = 2000.0;
          const int zigzagPoints = 200;
          final zigzag = List<Offset>.generate(zigzagPoints, (index) {
            final x = zigzagLength * index / (zigzagPoints - 1);
            final y = index.isEven ? -8.0 : 8.0;
            return Offset(x, y);
          }, growable: false);

          final targetNear = StrokeNode(
            id: 'zigzag-target-near',
            points: const <Offset>[Offset(100, 0), Offset(1900, 0)],
            thickness: 2,
            color: const Color(0xFF000000),
          );
          final targetCross = StrokeNode(
            id: 'zigzag-target-cross',
            points: const <Offset>[Offset(1000, -30), Offset(1000, 30)],
            thickness: 2,
            color: const Color(0xFF000000),
          );
          final safeFar = StrokeNode(
            id: 'zigzag-safe-far',
            points: const <Offset>[Offset(100, 80), Offset(1900, 80)],
            thickness: 2,
            color: const Color(0xFF000000),
          );
          final safeLow = StrokeNode(
            id: 'zigzag-safe-low',
            points: const <Offset>[Offset(100, -80), Offset(1900, -80)],
            thickness: 2,
            color: const Color(0xFF000000),
          );

          final controller = _controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(),
                ContentLayer(
                  nodes: <SceneNode>[targetNear, targetCross, safeFar, safeLow],
                ),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.eraser);
          controller.eraserThickness = 14;

          controller.handlePointer(
            _sample(
              pointerId: 11,
              position: zigzag.first,
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i < zigzag.length; i++) {
            final phase = i == zigzag.length - 1
                ? CanvasPointerPhase.up
                : CanvasPointerPhase.move;
            controller.handlePointer(
              _sample(
                pointerId: 11,
                position: zigzag[i],
                timestampMs: i + 1,
                phase: phase,
              ),
            );
          }

          final ids = <NodeId>{
            for (final layer in controller.snapshot.layers)
              for (final node in layer.nodes) node.id,
          };
          expect(ids.contains('zigzag-target-near'), isFalse);
          expect(ids.contains('zigzag-target-cross'), isFalse);
          expect(ids.contains('zigzag-safe-far'), isTrue);
          expect(ids.contains('zigzag-safe-low'), isTrue);

          final preciseChecks =
              sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
                controller,
              );
          final spatialQueries =
              sceneControllerInteractiveInternalEraserSpatialQueryCount(
                controller,
              );
          expect(preciseChecks, lessThan(15000));
          expect(
            spatialQueries,
            lessThanOrEqualTo((zigzagPoints / 64).ceil() + 2),
          );
        },
      );

      test(
        'eraser stroke coarse prefilter runs batched checks for non-hit geometry',
        () {
          final nonHitStroke = StrokeNode(
            id: 'non-hit',
            points: const <Offset>[
              Offset(0, 100),
              Offset(0, 200),
              Offset(100, 200),
            ],
            thickness: 1,
            color: const Color(0xFF000000),
          );
          final aboveStroke = StrokeNode(
            id: 'above',
            points: const <Offset>[Offset(0, -3), Offset(100, -3)],
            thickness: 1,
            color: const Color(0xFF000000),
          );
          final controller = _controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(),
                ContentLayer(nodes: <SceneNode>[nonHitStroke, aboveStroke]),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.eraser);
          controller.eraserThickness = 1;

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(100, 0),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(100, 100),
              timestampMs: 3,
              phase: CanvasPointerPhase.up,
            ),
          );

          final ids = <NodeId>{
            for (final layer in controller.snapshot.layers)
              for (final node in layer.nodes) node.id,
          };
          expect(ids.contains('non-hit'), isTrue);
          expect(ids.contains('above'), isTrue);
          expect(
            sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
              controller,
            ),
            greaterThan(0),
          );
        },
      );

      test('long eraser gesture does not throw', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);

        expect(() {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= 20000; i++) {
            controller.handlePointer(
              _sample(
                pointerId: 1,
                position: Offset(i.toDouble(), 0),
                timestampMs: i + 1,
                phase: CanvasPointerPhase.move,
              ),
            );
          }
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(20000, 0),
              timestampMs: 20002,
              phase: CanvasPointerPhase.up,
            ),
          );
        }, returnsNormally);
      });

      test('long eraser gesture cancel does not mutate scene', () async {
        final startLine = LineNode(
          id: 'cancel-line-start',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(20, 50);
        final endLine = LineNode(
          id: 'cancel-line-end',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(9000, 50);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[startLine, endLine]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 24;

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(20, 50),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 21; i <= 9000; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 50),
              timestampMs: i,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(9000, 50),
            timestampMs: 9001,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        await pumpEventQueue();
        final ids = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(ids.contains('cancel-line-start'), isTrue);
        expect(ids.contains('cancel-line-end'), isTrue);
        expect(
          actions.where((event) => event.type == ActionType.erase),
          isEmpty,
        );
      });

      test('invalid soft-limit config throws ArgumentError', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final points = <Offset>[const Offset(0, 0), const Offset(1, 0)];

        expect(
          () =>
              sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest(
                controller,
                points: points,
                softLimit: 10,
                trimTo: 1,
              ),
          throwsArgumentError,
        );
        expect(
          () =>
              sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest(
                controller,
                points: points,
                softLimit: 5,
                trimTo: 5,
              ),
          throwsArgumentError,
        );
        expect(
          () =>
              sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest(
                controller,
                points: points,
                softLimit: 1,
                trimTo: 1,
              ),
          throwsArgumentError,
        );
      });

      test('eraser active buffer is capped during long move', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= 20000; i++) {
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(
          sceneControllerInteractiveInternalActiveEraserPointsLength(
            controller,
          ),
          lessThanOrEqualTo(kInteractiveEraserPointsSoftLimit),
        );
      });
    });

    test('stroke preview is available during drag and clears on up', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.highlighter);
      controller.highlighterThickness = 8;
      controller.highlighterOpacity = 0.3;

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.hasActiveStrokePreview, isTrue);
      expect(controller.activeStrokePreviewPoints, const <Offset>[
        Offset(10, 10),
      ]);
      expect(controller.activeStrokePreviewThickness, 8);
      expect(controller.activeStrokePreviewOpacity, 0.3);

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.activeStrokePreviewPoints.length, 2);

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.hasActiveStrokePreview, isFalse);
      expect(controller.activeStrokePreviewPoints, isEmpty);
    });

    test('line preview does not mutate scene until pointer up commit', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
        dragStartSlop: 10,
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);

      final beforeNodeCount = controller.snapshot.layers[1].nodes.length;
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount);

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.hasActiveLinePreview, isFalse);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount + 1);
    });

    group('interactive hardening: line pending cancel semantics', () {
      test(
        'line preview starts after dragStartSlop and clears on cancel/tool/mode switch',
        () {
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
              ],
            ),
            dragStartSlop: 10,
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.line);

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(10, 10),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(18, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);

          controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 4,
              phase: CanvasPointerPhase.cancel,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(30, 30),
              timestampMs: 5,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 2,
              position: const Offset(50, 30),
              timestampMs: 6,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);
          controller.setDrawTool(DrawTool.pen);
          expect(controller.hasActiveLinePreview, isFalse);

          controller.setDrawTool(DrawTool.line);
          controller.handlePointer(
            _sample(
              pointerId: 3,
              position: const Offset(30, 30),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            _sample(
              pointerId: 3,
              position: const Offset(50, 30),
              timestampMs: 8,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);
          controller.setMode(CanvasMode.move);
          expect(controller.hasActiveLinePreview, isFalse);
        },
      );

      test('line pending start is cleared on pointer cancel', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.line);

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(20, 20),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 2,
            position: const Offset(20, 20),
            timestampMs: 4,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        expect(controller.hasPendingLineStart, isFalse);
        expect(controller.pendingLineStart, isNull);
        expect(controller.pendingLineTimestampMs, isNull);

        controller.handlePointer(
          _sample(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 5,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 6,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.handlePointer(
          _sample(
            pointerId: 4,
            position: const Offset(50, 30),
            timestampMs: 7,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 4,
            position: const Offset(50, 30),
            timestampMs: 8,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.hasPendingLineStart, isFalse);
        final lineCount = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<LineNodeSnapshot>()
            .length;
        expect(lineCount, 1);
      });

      test('line pending start survives invalid second tap input as no-op', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.line);

        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        expect(
          () => controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(double.nan, 20),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
              timestampMs: 3,
            ),
          ),
          returnsNormally,
        );
        expect(controller.hasPendingLineStart, isTrue);
        expect(controller.pendingLineStart, const Offset(10, 10));
        expect(controller.pendingLineTimestampMs, 2);

        controller.handlePointer(
          _sample(
            pointerId: 3,
            position: const Offset(40, 30),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 3,
            position: const Offset(40, 30),
            timestampMs: 5,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.hasPendingLineStart, isFalse);
        final lineCount = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<LineNodeSnapshot>()
            .length;
        expect(lineCount, 1);
      });
    });

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
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[line, stroke]),
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
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(120, 120),
          timestampMs: 11,
          phase: CanvasPointerPhase.up,
        ),
      );

      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(170, 120),
          timestampMs: 20,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(176, 120),
          timestampMs: 21,
          phase: CanvasPointerPhase.up,
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
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(10, 10),
          timestampMs: 31,
          phase: CanvasPointerPhase.cancel,
        ),
      );
    });

    test('hit-test marquee and eraser keep foreground behavior', () {
      final backgroundRect = RectNode(
        id: 'bg',
        size: const Size(200, 200),
        isSelectable: true,
      )..position = const Offset(100, 100);
      final foregroundRect = RectNode(id: 'fg', size: const Size(40, 40))
        ..position = const Offset(100, 100);
      final foregroundLine = LineNode(
        id: 'line',
        start: const Offset(-15, 0),
        end: const Offset(15, 0),
        thickness: 2,
        color: const Color(0xFF000000),
      )..position = const Offset(160, 100);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(nodes: <SceneNode>[backgroundRect]),
            ContentLayer(nodes: <SceneNode>[foregroundRect, foregroundLine]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 2,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.selectedNodeIds, const <NodeId>{'fg'});

      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(80, 80),
          timestampMs: 3,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(120, 120),
          timestampMs: 4,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 2,
          position: const Offset(120, 120),
          timestampMs: 5,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.selectedNodeIds, const <NodeId>{'fg'});

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.eraser);
      controller.eraserThickness = 20;
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(160, 100),
          timestampMs: 6,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 3,
          position: const Offset(160, 100),
          timestampMs: 7,
          phase: CanvasPointerPhase.up,
        ),
      );

      final ids = <NodeId>{
        for (final layer in controller.snapshot.layers)
          for (final node in layer.nodes) node.id,
      };
      expect(ids.contains('line'), isFalse);
      expect(ids.contains('bg'), isTrue);
      expect(ids.contains('fg'), isTrue);
    });

    test(
      'transform/delete/clear/notify scene APIs emit expected effects',
      () async {
        final rect = RectNode(id: 'r', size: const Size(20, 10))
          ..position = const Offset(50, 50);
        final locked = RectNode(
          id: 'locked',
          size: const Size(20, 10),
          isLocked: true,
          isDeletable: false,
        )..position = const Offset(90, 50);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect, locked]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });
        controller.notifySceneChanged();
        await pumpEventQueue();
        expect(notifications, 1);

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

        await pumpEventQueue();
        expect(actions.any((a) => a.type == ActionType.transform), isTrue);
        expect(actions.any((a) => a.type == ActionType.delete), isTrue);
        expect(actions.any((a) => a.type == ActionType.clear), isTrue);
      },
    );

    test('move drag up emits transform action with delta payload', () async {
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[rect]),
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
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(90, 60),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(100, 60),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );

      await pumpEventQueue();
      final transformActions = actions.where(
        (a) => a.type == ActionType.transform,
      );
      expect(transformActions, isNotEmpty);
      expect(transformActions.last.payload?['delta'], isNotNull);
    });

    test('rotateSelection emits transform for multi-node selection', () async {
      final first = RectNode(id: 'a', size: const Size(30, 20))
        ..position = const Offset(40, 40);
      final second = RectNode(id: 'b', size: const Size(30, 20))
        ..position = const Offset(140, 40);
      final controller = _controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[first, second]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.setSelection(const <NodeId>{'a', 'b'});
      controller.rotateSelection(clockwise: true, timestampMs: 200);

      await pumpEventQueue();
      final transformActions = actions
          .where((event) => event.type == ActionType.transform)
          .toList(growable: false);
      expect(transformActions, isNotEmpty);
      expect(transformActions.last.nodeIds.toSet(), const <NodeId>{'a', 'b'});
    });

    test(
      'dispose clears pending line timer and supports replaceScene',
      () async {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
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
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.replaceScene(
          SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(
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

    test(
      'after dispose handlePointer fails fast and keeps state/effects unchanged',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final rect = RectNode(id: 'node', size: const Size(10, 10))
          ..position = const Offset(40, 40);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect]),
            ],
          ),
        );

        final beforeSnapshot = controller.snapshot;
        final beforeSelection = controller.selectedNodeIds;
        final beforeMode = controller.mode;
        final beforeTool = controller.drawTool;

        final actions = <ActionCommitted>[];
        final edits = <EditTextRequested>[];
        final actionSub = controller.actions.listen(actions.add);
        final editSub = controller.editTextRequests.listen(edits.add);
        addTearDown(actionSub.cancel);
        addTearDown(editSub.cancel);

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });

        controller.dispose();

        expect(
          () => controller.handlePointer(
            _sample(
              pointerId: 1,
              position: const Offset(50, 50),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          ),
          throwsStateError,
        );
        await pumpEventQueue(times: 2);

        expect(controller.snapshot, same(beforeSnapshot));
        expect(controller.selectedNodeIds, beforeSelection);
        expect(controller.mode, beforeMode);
        expect(controller.drawTool, beforeTool);
        expect(actions, isEmpty);
        expect(edits, isEmpty);
        expect(notifications, 0);
      },
    );

    test(
      'after dispose handleDoubleTap fails fast and does not emit edit request',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final textNode = TextNode(
          id: 'text',
          text: 'hello',
          size: const Size(40, 20),
          color: const Color(0xFF000000),
        )..position = const Offset(40, 40);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[textNode]),
            ],
          ),
        );

        final beforeSnapshot = controller.snapshot;
        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });

        controller.dispose();

        expect(
          () => controller.handleDoubleTap(
            position: const Offset(40, 40),
            timestampMs: 1,
          ),
          throwsStateError,
        );
        await pumpEventQueue(times: 2);

        expect(controller.snapshot, same(beforeSnapshot));
        expect(requests, isEmpty);
        expect(notifications, 0);
      },
    );

    test(
      'after dispose representative mutating APIs fail fast and keep state',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final rect = RectNode(id: 'node', size: const Size(10, 10))
          ..position = const Offset(20, 20);
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect]),
            ],
          ),
        );

        final beforeSnapshot = controller.snapshot;
        final beforeSelection = controller.selectedNodeIds;
        final beforeMode = controller.mode;
        final beforeColor = controller.drawColor;
        final beforePenThickness = controller.penThickness;

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });

        controller.dispose();

        expect(
          () => controller.setDrawColor(const Color(0xFF123456)),
          throwsStateError,
        );
        expect(() => controller.penThickness = 2, throwsStateError);
        expect(() => controller.clearSelection(), throwsStateError);
        expect(
          () => controller.write<void>((writer) {
            writer.writeSelectionClear();
          }),
          throwsStateError,
        );
        expect(() => controller.notifySceneChanged(), throwsStateError);

        await pumpEventQueue(times: 2);
        expect(controller.snapshot, same(beforeSnapshot));
        expect(controller.selectedNodeIds, beforeSelection);
        expect(controller.mode, beforeMode);
        expect(controller.drawColor, beforeColor);
        expect(controller.penThickness, beforePenThickness);
        expect(notifications, 0);
      },
    );

    group('after dispose fail-fast matrix', () {
      // INV:INV-ENG-DISPOSE-FAIL-FAST
      final cases = <_DisposeMatrixCase>[
        _DisposeMatrixCase(
          name: 'setMode',
          call: (controller) => controller.setMode(CanvasMode.draw),
        ),
        _DisposeMatrixCase(
          name: 'setDrawTool',
          call: (controller) => controller.setDrawTool(DrawTool.line),
        ),
        _DisposeMatrixCase(
          name: 'setDrawColor',
          call: (controller) =>
              controller.setDrawColor(const Color(0xFF123456)),
        ),
        _DisposeMatrixCase(
          name: 'setPointerSettings',
          call: (controller) => controller.setPointerSettings(
            const PointerInputSettings(
              tapSlop: 9,
              doubleTapSlop: 18,
              doubleTapMaxDelayMs: 250,
            ),
          ),
        ),
        _DisposeMatrixCase(
          name: 'setDragStartSlop',
          call: (controller) => controller.setDragStartSlop(9),
        ),
        _DisposeMatrixCase(
          name: 'set penThickness',
          call: (controller) => controller.penThickness = 2,
        ),
        _DisposeMatrixCase(
          name: 'set highlighterThickness',
          call: (controller) => controller.highlighterThickness = 3,
        ),
        _DisposeMatrixCase(
          name: 'set lineThickness',
          call: (controller) => controller.lineThickness = 4,
        ),
        _DisposeMatrixCase(
          name: 'set eraserThickness',
          call: (controller) => controller.eraserThickness = 5,
        ),
        _DisposeMatrixCase(
          name: 'set highlighterOpacity',
          call: (controller) => controller.highlighterOpacity = 0.5,
        ),
        _DisposeMatrixCase(
          name: 'setBackgroundColor',
          call: (controller) =>
              controller.setBackgroundColor(const Color(0xFF010203)),
        ),
        _DisposeMatrixCase(
          name: 'setGridEnabled',
          call: (controller) => controller.setGridEnabled(true),
        ),
        _DisposeMatrixCase(
          name: 'setGridCellSize',
          call: (controller) => controller.setGridCellSize(16),
        ),
        _DisposeMatrixCase(
          name: 'setCameraOffset',
          call: (controller) => controller.setCameraOffset(const Offset(4, 5)),
        ),
        _DisposeMatrixCase(
          name: 'addNode',
          call: (controller) => controller.addNode(
            RectNodeSpec(id: 'added', size: const Size(10, 10)),
          ),
        ),
        _DisposeMatrixCase(
          name: 'patchNode',
          call: (controller) => controller.patchNode(
            const RectNodePatch(
              id: 'a',
              size: PatchField<Size>.value(Size(30, 20)),
            ),
          ),
        ),
        _DisposeMatrixCase(
          name: 'removeNode',
          call: (controller) => controller.removeNode('a'),
        ),
        _DisposeMatrixCase(
          name: 'setSelection',
          call: (controller) => controller.setSelection(const <NodeId>{'a'}),
        ),
        _DisposeMatrixCase(
          name: 'toggleSelection',
          call: (controller) => controller.toggleSelection('a'),
        ),
        _DisposeMatrixCase(
          name: 'clearSelection',
          call: (controller) => controller.clearSelection(),
        ),
        _DisposeMatrixCase(
          name: 'selectAll',
          call: (controller) => controller.selectAll(onlySelectable: true),
        ),
        _DisposeMatrixCase(
          name: 'rotateSelection',
          call: (controller) =>
              controller.rotateSelection(clockwise: true, timestampMs: 10),
        ),
        _DisposeMatrixCase(
          name: 'flipSelectionVertical',
          call: (controller) =>
              controller.flipSelectionVertical(timestampMs: 11),
        ),
        _DisposeMatrixCase(
          name: 'flipSelectionHorizontal',
          call: (controller) =>
              controller.flipSelectionHorizontal(timestampMs: 12),
        ),
        _DisposeMatrixCase(
          name: 'deleteSelection',
          call: (controller) => controller.deleteSelection(timestampMs: 13),
        ),
        _DisposeMatrixCase(
          name: 'clearScene',
          call: (controller) => controller.clearScene(timestampMs: 14),
        ),
        _DisposeMatrixCase(
          name: 'replaceScene',
          call: (controller) => controller.replaceScene(
            SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(
                  nodes: <NodeSnapshot>[
                    RectNodeSnapshot(id: 'new', size: Size(5, 5)),
                  ],
                ),
              ],
            ),
          ),
        ),
        _DisposeMatrixCase(
          name: 'notifySceneChanged',
          call: (controller) => controller.notifySceneChanged(),
        ),
        _DisposeMatrixCase(
          name: 'write',
          call: (controller) => controller.write<void>((writer) {
            writer.writeSelectionClear();
          }),
        ),
        _DisposeMatrixCase(
          name: 'handlePointer',
          call: (controller) => controller.handlePointer(
            _sample(
              pointerId: 42,
              position: const Offset(60, 60),
              timestampMs: 100,
              phase: CanvasPointerPhase.down,
            ),
          ),
        ),
        _DisposeMatrixCase(
          name: 'handleDoubleTap',
          call: (controller) =>
              controller.handleDoubleTap(position: const Offset(60, 60)),
        ),
      ];

      for (final testCase in cases) {
        test(
          'after dispose: ${testCase.name} throws StateError and has no side effects',
          () async {
            final rectA = RectNode(id: 'a', size: const Size(20, 10))
              ..position = const Offset(40, 40);
            final rectB = RectNode(id: 'b', size: const Size(20, 10))
              ..position = const Offset(80, 40);
            final textNode = TextNode(
              id: 'text',
              text: 'hello',
              size: const Size(30, 20),
              color: const Color(0xFF000000),
            )..position = const Offset(60, 60);
            final controller = _controllerFromScene(
              Scene(
                layers: <ContentLayer>[
                  ContentLayer(),
                  ContentLayer(nodes: <SceneNode>[rectA, rectB, textNode]),
                ],
              ),
            );

            controller.setSelection(const <NodeId>{'a', 'b'});
            final before = _captureStableState(controller);

            final actions = <ActionCommitted>[];
            final edits = <EditTextRequested>[];
            final actionSub = controller.actions.listen(actions.add);
            final editSub = controller.editTextRequests.listen(edits.add);
            addTearDown(actionSub.cancel);
            addTearDown(editSub.cancel);

            var notifications = 0;
            controller.addListener(() {
              notifications = notifications + 1;
            });

            controller.dispose();

            expect(() => testCase.call(controller), throwsStateError);
            await pumpEventQueue(times: 2);

            _expectStableStateUnchanged(controller, before);
            expect(actions, isEmpty);
            expect(edits, isEmpty);
            expect(notifications, 0);
          },
        );
      }
    });

    testWidgets('pending two-tap line expires after timeout', (tester) async {
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        _sample(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.hasPendingLineStart, isTrue);
      await tester.pump(const Duration(seconds: 11));
      expect(controller.hasPendingLineStart, isFalse);
    });

    test(
      'configured draw-mode entry clears selection and delegates commands',
      () {
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(
                nodes: <SceneNode>[RectNode(id: 'n', size: const Size(10, 10))],
              ),
            ],
          ),
          clearSelectionOnDrawModeEnter: true,
        );
        addTearDown(controller.dispose);

        controller.setSelection(const <String>{'n'});
        expect(controller.selectedNodeIds, isNotEmpty);
        controller.setMode(CanvasMode.draw);
        expect(controller.selectedNodeIds, isEmpty);

        controller.setDrawTool(DrawTool.pen);
        controller.handlePointer(
          _sample(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        expect(controller.activeStrokePreviewColor, controller.drawColor);

        controller.setBackgroundColor(const Color(0xFF010203));
        expect(controller.snapshot.background.color, const Color(0xFF010203));

        controller.setCameraOffset(const Offset(3, 4));
        expect(controller.snapshot.camera.offset, const Offset(3, 4));

        expect(
          controller.patchNode(
            const RectNodePatch(
              id: 'n',
              size: PatchField<Size>.value(Size(20, 10)),
            ),
          ),
          isTrue,
        );
        expect(
          (controller.snapshot.layers[1].nodes.first as RectNodeSnapshot).size,
          const Size(20, 10),
        );
      },
    );

    test(
      'eraser path and move hit-tests cover multi-candidate sorting',
      () async {
        final controller = _controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(
                nodes: <SceneNode>[
                  LineNode(
                    id: 'line-a',
                    start: const Offset(-10, 0),
                    end: const Offset(10, 0),
                    thickness: 2,
                    color: const Color(0xFF000000),
                  )..position = const Offset(20, 20),
                  StrokeNode(
                    id: 'stroke-a',
                    points: const <Offset>[Offset(-5, 0), Offset(5, 0)],
                    thickness: 2,
                    color: const Color(0xFF000000),
                  )..position = const Offset(20, 20),
                ],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);

        controller.handlePointer(
          _sample(
            pointerId: 10,
            position: const Offset(10, 20),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 10,
            position: const Offset(30, 20),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 10,
            position: const Offset(30, 20),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        await pumpEventQueue();
        expect(actions.any((a) => a.type == ActionType.erase), isTrue);

        controller.replaceScene(
          SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(
                    id: 'bottom',
                    size: const Size(30, 30),
                    transform: Transform2D.translation(const Offset(50, 50)),
                  ),
                  RectNodeSnapshot(
                    id: 'top',
                    size: const Size(20, 20),
                    transform: Transform2D.translation(const Offset(50, 50)),
                  ),
                ],
              ),
            ],
          ),
        );
        controller.setMode(CanvasMode.move);

        controller.handlePointer(
          _sample(
            pointerId: 20,
            position: const Offset(0, 0),
            timestampMs: 10,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 20,
            position: const Offset(80, 80),
            timestampMs: 11,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 20,
            position: const Offset(80, 80),
            timestampMs: 12,
            phase: CanvasPointerPhase.up,
          ),
        );

        controller.handlePointer(
          _sample(
            pointerId: 21,
            position: const Offset(50, 50),
            timestampMs: 13,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          _sample(
            pointerId: 21,
            position: const Offset(50, 50),
            timestampMs: 14,
            phase: CanvasPointerPhase.up,
          ),
        );
      },
    );
  });
}

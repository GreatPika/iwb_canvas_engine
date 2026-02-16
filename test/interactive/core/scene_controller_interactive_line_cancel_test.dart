import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    group('interactive hardening: line pending cancel semantics', () {
      test(
        'line preview starts after dragStartSlop and clears on cancel/tool/mode switch',
        () {
          // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
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
            sampleInput(
              pointerId: 1,
              position: const Offset(10, 10),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(18, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 4,
              phase: CanvasPointerPhase.cancel,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(30, 30),
              timestampMs: 5,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
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
            sampleInput(
              pointerId: 3,
              position: const Offset(30, 30),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
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
        // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
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
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(20, 20),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
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
          sampleInput(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 5,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 6,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.handlePointer(
          sampleInput(
            pointerId: 4,
            position: const Offset(50, 30),
            timestampMs: 7,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
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
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
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
          sampleInput(
            pointerId: 3,
            position: const Offset(40, 30),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
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
      final controller = controllerFromScene(
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
        sampleInput(
          pointerId: 1,
          position: const Offset(120, 120),
          timestampMs: 10,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(120, 120),
          timestampMs: 11,
          phase: CanvasPointerPhase.up,
        ),
      );

      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(170, 120),
          timestampMs: 20,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
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
        sampleInput(
          pointerId: 3,
          position: const Offset(10, 10),
          timestampMs: 30,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
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
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(nodes: <SceneNode>[backgroundRect]),
            ContentLayer(nodes: <SceneNode>[foregroundRect, foregroundLine]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 2,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.selectedNodeIds, const <NodeId>{'fg'});

      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(80, 80),
          timestampMs: 3,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(120, 120),
          timestampMs: 4,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.handlePointer(
        sampleInput(
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
        sampleInput(
          pointerId: 3,
          position: const Offset(160, 100),
          timestampMs: 6,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
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
        final controller = controllerFromScene(
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
        expect(nodeById(controller.snapshot, 'locked').id, 'locked');

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
      final controller = controllerFromScene(
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
        sampleInput(
          pointerId: 1,
          position: const Offset(60, 60),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(90, 60),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.handlePointer(
        sampleInput(
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
      final controller = controllerFromScene(
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
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
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
        expect(nodeById(controller.snapshot, 'new').id, 'new');

        controller.dispose();
      },
    );

    test(
      'after dispose handlePointer fails fast and keeps state/effects unchanged',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final rect = RectNode(id: 'node', size: const Size(10, 10))
          ..position = const Offset(40, 40);
        final controller = controllerFromScene(
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
            sampleInput(
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
        final controller = controllerFromScene(
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
        final controller = controllerFromScene(
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
  });
}

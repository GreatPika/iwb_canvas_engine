import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_interaction_runtime.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneController unit', () {
    test('read API + setters + validation', () {
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-9'),
            ContentLayer(
              id: 'layer-auto-10',
              nodes: <SceneNode>[RectNode(id: 'n', size: const Size(10, 8))],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.snapshot.layers.length, 2);
      expect(controller.snapshot.layers.length, 2);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.interaction.mode, CanvasMode.move);
      expect(controller.interaction.drawTool, DrawTool.pen);
      expect(controller.interaction.drawColor, isA<Color>());
      expect(controller.interaction.penThickness, greaterThan(0));
      expect(controller.interaction.highlighterThickness, greaterThan(0));
      expect(controller.interaction.lineThickness, greaterThan(0));
      expect(controller.interaction.eraserThickness, greaterThan(0));
      expect(controller.interaction.highlighterOpacity, inInclusiveRange(0, 1));
      expect(controller.interaction.selectionRect, isNull);
      expect(controller.interaction.pendingLineStart, isNull);
      expect(controller.interaction.pendingLineTimestampMs, isNull);
      expect(controller.interaction.hasPendingLineStart, isFalse);
      expect(controller.interaction.hasActiveLinePreview, isFalse);
      expect(controller.interaction.pointerSettings.tapSlop, greaterThan(0));
      expect(
        controller.interaction.dragStartSlop,
        controller.interaction.pointerSettings.tapSlop,
      );
      expect(controller.scene.write<int>((_) => 42), 42);

      controller.interaction.penThickness = 2;
      controller.interaction.highlighterThickness = 6;
      controller.interaction.lineThickness = 3;
      controller.interaction.eraserThickness = 9;
      controller.interaction.highlighterOpacity = 0.4;
      controller.interaction.setDrawColor(const Color(0xFF336699));
      controller.interaction.setDrawColor(const Color(0xFF336699));
      controller.interaction.setPointerSettings(
        const PointerInputSettings(
          tapSlop: 12,
          doubleTapSlop: 30,
          doubleTapMaxDelayMs: 500,
        ),
      );

      expect(controller.interaction.penThickness, 2);
      expect(controller.interaction.highlighterThickness, 6);
      expect(controller.interaction.lineThickness, 3);
      expect(controller.interaction.eraserThickness, 9);
      expect(controller.interaction.highlighterOpacity, 0.4);
      expect(controller.interaction.drawColor, const Color(0xFF336699));
      expect(controller.interaction.pointerSettings.tapSlop, 12);
      expect(controller.interaction.dragStartSlop, 12);

      controller.interaction.setDragStartSlop(9);
      expect(controller.interaction.dragStartSlop, 9);
      controller.interaction.setDragStartSlop(0);
      expect(controller.interaction.dragStartSlop, 0);
      controller.interaction.setDragStartSlop(null);
      expect(controller.interaction.dragStartSlop, 12);

      expect(
        () => controller.interaction.penThickness = 0,
        throwsArgumentError,
      );
      expect(
        () => controller.interaction.highlighterThickness = double.nan,
        throwsArgumentError,
      );
      expect(
        () => controller.interaction.lineThickness = double.infinity,
        throwsArgumentError,
      );
      expect(
        () => controller.interaction.eraserThickness = -1,
        throwsArgumentError,
      );
      expect(
        () => controller.interaction.setDragStartSlop(-1),
        throwsArgumentError,
      );
      expect(
        () => controller.interaction.highlighterOpacity = -0.1,
        throwsArgumentError,
      );
      expect(
        () => controller.interaction.highlighterOpacity = 1.1,
        throwsArgumentError,
      );
      expect(
        () => controller.scene.setCameraOffset(const Offset(double.nan, 0)),
        throwsArgumentError,
      );

      controller.scene.setGridEnabled(false);
      expect(
        () => controller.scene.setGridCellSize(-12),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'cellSize',
          ),
        ),
      );
      controller.scene.setGridEnabled(true);
      controller.scene.setGridCellSize(0.5);
      expect(controller.snapshot.background.grid.cellSize, minGridCellSize);

      final actionSub = controller.actions.listen((_) {});
      final editSub = controller.editTextRequests.listen((_) {});
      addTearDown(actionSub.cancel);
      addTearDown(editSub.cancel);
    });

    test('setPointerSettings validates numeric fields', () {
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-11'),
            ContentLayer(id: 'layer-auto-12'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.interaction.setPointerSettings(
          const PointerInputSettings(tapSlop: double.infinity),
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'tapSlop'),
        ),
      );
      expect(
        () => controller.interaction.setPointerSettings(
          const PointerInputSettings(doubleTapSlop: -1),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'doubleTapSlop',
          ),
        ),
      );
      expect(
        () => controller.interaction.setPointerSettings(
          const PointerInputSettings(doubleTapMaxDelayMs: -10),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'doubleTapMaxDelayMs',
          ),
        ),
      );

      controller.interaction.setPointerSettings(
        const PointerInputSettings(
          tapSlop: 0,
          doubleTapSlop: 0,
          doubleTapMaxDelayMs: 0,
        ),
      );
      expect(controller.interaction.pointerSettings.doubleTapMaxDelayMs, 0);
    });

    test('constructor validates pointerSettings', () {
      expect(
        () => SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-0'),
            ],
          ),
          pointerSettings: const PointerInputSettings(tapSlop: -1),
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'tapSlop'),
        ),
      );
    });

    test('constructor and setter share dragStartSlop validation contract', () {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-0'),
          ],
        ),
        dragStartSlop: 0,
      );
      addTearDown(controller.dispose);

      expect(controller.interaction.dragStartSlop, 0);
      controller.interaction.setDragStartSlop(0);
      expect(controller.interaction.dragStartSlop, 0);

      expect(
        () => SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-1'),
            ],
          ),
          dragStartSlop: -1,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'dragStartSlop',
          ),
        ),
      );
      expect(
        () => SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-2'),
            ],
          ),
          dragStartSlop: double.nan,
        ),
        throwsArgumentError,
      );
    });

    test('handlePointer notifications are deferred', () async {
      // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-13'),
            ContentLayer(id: 'layer-auto-14'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.interaction.handlePointer(
        sampleInput(
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
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-15'),
            ContentLayer(id: 'layer-auto-16'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);
      controller.interaction.setDrawColor(const Color(0xFF123456));
      controller.interaction.setDragStartSlop(9);

      expect(notifications, 0);
      await pumpEventQueue();
      expect(notifications, 1);
    });

    test('core-change forwarding is deferred', () async {
      final node = RectNode(id: 'n', size: const Size(10, 10))
        ..position = const Offset(10, 10);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-17'),
            ContentLayer(id: 'layer-auto-18', nodes: <SceneNode>[node]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.selection.setSelection(const <NodeId>{'n'});

      expect(notifications, 0);
      await pumpEventQueue(times: 2);
      expect(notifications, 1);
    });

    test('reentrant handlePointer throws StateError', () {
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-19'),
            ContentLayer(id: 'layer-auto-20'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final sample = sampleInput(
        pointerId: 1,
        position: const Offset(100, 100),
        timestampMs: 1,
        phase: CanvasPointerPhase.down,
      );

      Object? nestedError;
      setBeforePointerDispatchHook(controller, () {
        setBeforePointerDispatchHook(controller, null);
        try {
          controller.interaction.handlePointer(sample);
        } catch (error) {
          nestedError = error;
        }
      });

      controller.interaction.handlePointer(sample);
      expect(nestedError, isA<StateError>());
    });

    test(
      'marquee emits select action when selection set changes with same length',
      () async {
        final nodeA = RectNode(id: 'a', size: const Size(40, 40))
          ..position = const Offset(20, 20);
        final nodeB = RectNode(id: 'b', size: const Size(40, 40))
          ..position = const Offset(120, 20);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-21'),
              ContentLayer(
                id: 'layer-auto-22',
                nodes: <SceneNode>[nodeA, nodeB],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.selection.setSelection(const <NodeId>{'a'});
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(80, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(180, 80),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
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
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-1'),
            ContentLayerSnapshot(id: 'layer-auto-2'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(
        controller.scene.addNode(
          RectNodeSpec(id: 'spec-rect', size: const Size(10, 8)),
        ),
        'spec-rect',
      );
      expect(
        controller.scene.addNode(
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
        controller.scene.addNode(
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
        controller.scene.addNode(
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
        controller.scene.addNode(
          ImageNodeSpec(
            id: 'spec-image',
            imageId: 'img',
            size: const Size(20, 20),
          ),
        ),
        'spec-image',
      );
      expect(
        controller.scene.addNode(
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
      'addNode supports insertIndex and ensureLayer preserves fail-fast ids',
      () {
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(
                id: 'layer-auto-3',
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(id: 'base', size: Size(10, 10)),
                ],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        expect(controller.scene.ensureLayer('layer-auto-2', index: 0), isTrue);
        expect(controller.scene.ensureLayer('layer-auto-2', index: 1), isFalse);
        controller.scene.addNode(
          RectNodeSpec(id: 'under-base', size: const Size(10, 8)),
          layerId: 'layer-auto-3',
          insertIndex: 0,
        );

        expect(
          controller.snapshot.layers
              .map((layer) => layer.id)
              .toList(growable: false),
          <String>['layer-auto-2', 'layer-auto-3'],
        );
        expect(
          controller.snapshot.layers[1].nodes
              .map((node) => node.id)
              .toList(growable: false),
          <String>['under-base', 'base'],
        );
        expect(
          () => controller.scene.addNode(
            RectNodeSpec(id: 'bad-layer', size: const Size(4, 4)),
            layerId: 'missing-layer',
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'textFontFamilyByDefault applies to write inserts only when absent',
      () {
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-4'),
            ],
          ),
          textFontFamilyByDefault: 'Mono',
        );
        addTearDown(controller.dispose);

        controller.scene.write<void>((txn) {
          txn.writeNodeInsert(
            TextNodeSpec(
              id: 'default-font',
              text: 'hello',
              color: const Color(0xFF111111),
            ),
          );
          txn.writeNodeInsert(
            TextNodeSpec(
              id: 'explicit-font',
              text: 'world',
              color: const Color(0xFF111111),
              fontFamily: 'Serif',
            ),
          );
        });

        final textNodes = controller.snapshot.layers.single.nodes
            .whereType<TextNodeSnapshot>()
            .toList(growable: false);
        expect(textNodes[0].fontFamily, 'Mono');
        expect(textNodes[1].fontFamily, 'Serif');
      },
    );

    test(
      'handlePointer accepts null timestamp hint and keeps monotonic time',
      () async {
        // INV:INV-ENG-TIMESTAMP-MS-MONOTONIC
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-23'),
              ContentLayer(id: 'layer-auto-24'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.pen);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(12, 12),
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
        );
        controller.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(20, 20),
            phase: CanvasPointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
        );

        controller.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 2,
            position: Offset(30, 30),
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
        );
        controller.interaction.handlePointer(
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
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-3'),
            ContentLayerSnapshot(id: 'layer-auto-4'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      expect(controller.scene.removeNode('missing', timestampMs: 1), isFalse);
      controller.scene.addNode(
        RectNodeSpec(id: 'n1', size: const Size(10, 10)),
      );
      expect(controller.scene.removeNode('n1', timestampMs: 5), isTrue);

      controller.scene.addNode(
        RectNodeSpec(id: 'n2', size: const Size(10, 10)),
      );
      expect(controller.scene.removeNode('n2', timestampMs: 3), isTrue);

      await pumpEventQueue();
      expect(actions.length, 2);
      expect(actions[0].type, ActionType.delete);
      expect(actions[0].timestampMs, 5);
      expect(actions[1].timestampMs, greaterThan(actions[0].timestampMs));
    });

    test('actions stream delivery is asynchronous', () async {
      // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-5'),
            ContentLayerSnapshot(id: 'layer-auto-6'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.scene.addNode(
        RectNodeSpec(id: 'n1', size: const Size(10, 10)),
      );

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      expect(controller.scene.removeNode('n1', timestampMs: 5), isTrue);
      expect(actions, isEmpty);

      await pumpEventQueue();

      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.delete);
    });

    test(
      'interactive action stream and notify are async without strict ordering contract',
      () async {
        // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-7'),
              ContentLayerSnapshot(
                id: 'layer-auto-8',
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

        expect(controller.scene.removeNode('n1', timestampMs: 5), isTrue);
        expect(trace, isEmpty);

        await pumpEventQueue(times: 2);

        expect(trace.where((entry) => entry == 'action'), hasLength(1));
        expect(trace.where((entry) => entry == 'notify'), hasLength(1));
      },
    );

    test(
      'setCameraOffset forces active gesture reset before camera mutation',
      () {
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-15'),
              ContentLayer(id: 'layer-auto-16'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(40, 40),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        expect(controller.interaction.selectionRect, isNotNull);

        controller.scene.setCameraOffset(const Offset(5, 6));

        expect(controller.snapshot.camera.offset, const Offset(5, 6));
        expect(controller.interaction.selectionRect, isNull);
        expect(controller.selectedNodeIds, isEmpty);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(40, 40),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.interaction.selectionRect, isNull);
        expect(controller.selectedNodeIds, isEmpty);
      },
    );

    test('setCameraOffset no-op preserves active move gesture state', () {
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-19'),
            ContentLayer(id: 'layer-auto-20'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(40, 40),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.interaction.selectionRect, isNotNull);

      controller.scene.setCameraOffset(controller.snapshot.camera.offset);

      expect(controller.interaction.selectionRect, isNotNull);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(40, 40),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.interaction.selectionRect, isNull);
    });

    test('setCameraOffset no-op preserves active draw gesture state', () {
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-21'),
            ContentLayer(id: 'layer-auto-22'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.pen);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(20, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.interaction.hasActiveStrokePreview, isTrue);
      expect(controller.interaction.activeStrokePreviewPoints, <Offset>[
        const Offset(10, 10),
        const Offset(20, 10),
      ]);

      controller.scene.setCameraOffset(controller.snapshot.camera.offset);

      expect(controller.interaction.hasActiveStrokePreview, isTrue);
      expect(controller.interaction.activeStrokePreviewPoints, <Offset>[
        const Offset(10, 10),
        const Offset(20, 10),
      ]);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(controller.interaction.activeStrokePreviewPoints, <Offset>[
        const Offset(10, 10),
        const Offset(20, 10),
        const Offset(30, 10),
      ]);
    });

    test(
      'replaceScene validation failure preserves active move gesture state',
      () {
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-23'),
              ContentLayer(id: 'layer-auto-24'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(40, 40),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        expect(controller.interaction.selectionRect, isNotNull);

        expect(
          () => controller.scene.replaceScene(
            SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-invalid-0'),
                ContentLayerSnapshot(
                  id: 'layer-invalid-1',
                  nodes: <NodeSnapshot>[
                    RectNodeSnapshot(id: 'dup', size: Size(5, 5)),
                    RectNodeSnapshot(id: 'dup', size: Size(6, 6)),
                  ],
                ),
              ],
            ),
          ),
          throwsA(isA<SceneDataException>()),
        );

        expect(controller.interaction.selectionRect, isNotNull);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(50, 50),
            timestampMs: 3,
            phase: CanvasPointerPhase.move,
          ),
        );
        expect(controller.interaction.selectionRect, isNotNull);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(50, 50),
            timestampMs: 4,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.interaction.selectionRect, isNull);
      },
    );

    test(
      'replaceScene validation failure preserves active draw gesture state',
      () async {
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-25'),
              ContentLayer(id: 'layer-auto-26'),
            ],
          ),
        );
        addTearDown(controller.dispose);
        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.pen);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(20, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        expect(controller.interaction.hasActiveStrokePreview, isTrue);
        expect(
          controller.interaction.activeStrokePreviewThickness,
          greaterThan(0),
        );

        expect(
          () => controller.scene.replaceScene(
            SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-invalid-2'),
                ContentLayerSnapshot(
                  id: 'layer-invalid-3',
                  nodes: <NodeSnapshot>[
                    RectNodeSnapshot(id: 'dup-draw', size: Size(5, 5)),
                    RectNodeSnapshot(id: 'dup-draw', size: Size(6, 6)),
                  ],
                ),
              ],
            ),
          ),
          throwsA(isA<SceneDataException>()),
        );

        expect(controller.interaction.hasActiveStrokePreview, isTrue);
        expect(controller.interaction.activeStrokePreviewPoints, <Offset>[
          const Offset(10, 10),
          const Offset(20, 10),
        ]);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(30, 10),
            timestampMs: 3,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(30, 10),
            timestampMs: 4,
            phase: CanvasPointerPhase.up,
          ),
        );

        await pumpEventQueue();
        expect(
          actions.where((event) => event.type == ActionType.drawStroke),
          hasLength(1),
        );
      },
    );

    test('interaction runtime access reports active gesture lifecycle', () {
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-gesture-0'),
            ContentLayer(id: 'layer-auto-gesture-1'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.pen);

      final access = sceneControllerInternalInteractionAccessForTest(
        controller,
      );
      expect(access.runtime.hasActiveGesture, isFalse);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(access.runtime.hasActiveGesture, isTrue);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(access.runtime.hasActiveGesture, isFalse);
    });

    test('down dispatch resets active gesture owner when dispatch throws', () {
      final rect = RectNode(id: 'node', size: const Size(20, 20))
        ..position = const Offset(40, 40);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-17'),
            ContentLayer(id: 'layer-auto-18', nodes: <SceneNode>[rect]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      setBeforePointerDispatchHook(controller, () {
        setBeforePointerDispatchHook(controller, null);
        controller.dispose();
      });

      expect(
        () => controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(40, 40),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        ),
        throwsStateError,
      );
    });

    // Gap matrix (P2 hardening):
    // - invalid pointer data: existing non-finite down/move + new up/cancel recovery
    // - long gesture guardrails: existing pen/eraser + new highlighter commit/preview
    // - line pending cancel semantics: existing cancel clear + new invalid second-tap no-op
    // - single-active-pointer semantics: existing move/draw policy group

    test(
      'internal interaction access reads snapshot through the public controller facade',
      () {
        final controller = _SnapshotOverrideController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-0'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final overriddenSnapshot = SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-override'),
          ],
        );
        controller.snapshotOverride = overriddenSnapshot;

        expect(
          sceneControllerInternalInteractionAccessForTest(controller).snapshot,
          same(overriddenSnapshot),
        );
      },
    );

    test(
      'transform and delete public APIs stay no-op for ineligible selection',
      () async {
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-15'),
              ContentLayer(
                id: 'layer-auto-16',
                nodes: <SceneNode>[
                  RectNode(
                    id: 'locked-protected',
                    size: const Size(10, 8),
                    isLocked: true,
                    isDeletable: false,
                  ),
                  RectNode(
                    id: 'rigid-protected',
                    size: const Size(10, 8),
                    isTransformable: false,
                    isDeletable: false,
                  ),
                ],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.selection.setSelection(const <NodeId>{
          'locked-protected',
          'rigid-protected',
        });
        controller.selection.rotateSelection(clockwise: true, timestampMs: 30);
        controller.selection.flipSelectionHorizontal(timestampMs: 31);
        controller.selection.flipSelectionVertical(timestampMs: 32);
        controller.selection.deleteSelection(timestampMs: 33);

        await pumpEventQueue();

        expect(actions, isEmpty);
        final remaining = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(remaining, const <NodeId>{
          'locked-protected',
          'rigid-protected',
        });
      },
    );
  });
}

class _SnapshotOverrideController extends SceneController {
  _SnapshotOverrideController({required super.initialSnapshot});

  SceneSnapshot? snapshotOverride;

  @override
  SceneSnapshot get snapshot => snapshotOverride ?? super.snapshot;
}

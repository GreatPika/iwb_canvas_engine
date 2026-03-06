import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
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
      expect(
        () => controller.setGridCellSize(-12),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'cellSize',
          ),
        ),
      );
      controller.setGridEnabled(true);
      controller.setGridCellSize(0.5);
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
        () => controller.setPointerSettings(
          const PointerInputSettings(tapSlop: double.infinity),
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'tapSlop'),
        ),
      );
      expect(
        () => controller.setPointerSettings(
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
        () => controller.setPointerSettings(
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

      controller.setPointerSettings(
        const PointerInputSettings(
          tapSlop: 0,
          doubleTapSlop: 0,
          doubleTapMaxDelayMs: 0,
        ),
      );
      expect(controller.pointerSettings.doubleTapMaxDelayMs, 0);
    });

    test('constructor validates pointerSettings', () {
      expect(
        () => SceneControllerInteractive(
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

      controller.handlePointer(
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

      controller.setSelection(const <NodeId>{'n'});

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
          controller.handlePointer(sample);
        } catch (error) {
          nestedError = error;
        }
      });

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

        controller.setSelection(const <NodeId>{'a'});
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(80, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(180, 80),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
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
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-1'),
            ContentLayerSnapshot(id: 'layer-auto-2'),
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
      'addNode supports insertIndex and ensureLayer preserves fail-fast ids',
      () {
        final controller = SceneControllerInteractive(
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

        expect(controller.ensureLayer('layer-auto-2', index: 0), isTrue);
        expect(controller.ensureLayer('layer-auto-2', index: 1), isFalse);
        controller.addNode(
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
          () => controller.addNode(
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
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-4'),
            ],
          ),
          textFontFamilyByDefault: 'Mono',
        );
        addTearDown(controller.dispose);

        controller.write<void>((txn) {
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
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-23'),
              ContentLayer(id: 'layer-auto-24'),
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
            ContentLayerSnapshot(id: 'layer-auto-3'),
            ContentLayerSnapshot(id: 'layer-auto-4'),
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
            ContentLayerSnapshot(id: 'layer-auto-5'),
            ContentLayerSnapshot(id: 'layer-auto-6'),
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
  });
}

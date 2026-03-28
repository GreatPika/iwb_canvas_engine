import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneController unit', () {
    group('after dispose fail-fast matrix', () {
      // INV:INV-ENG-DISPOSE-FAIL-FAST
      final cases = <DisposeMatrixCase>[
        DisposeMatrixCase(
          name: 'setMode',
          call: (controller) => controller.interaction.setMode(CanvasMode.draw),
        ),
        DisposeMatrixCase(
          name: 'setDrawTool',
          call: (controller) =>
              controller.interaction.setDrawTool(DrawTool.line),
        ),
        DisposeMatrixCase(
          name: 'setDrawColor',
          call: (controller) =>
              controller.interaction.setDrawColor(const Color(0xFF123456)),
        ),
        DisposeMatrixCase(
          name: 'setPointerSettings',
          call: (controller) => controller.interaction.setPointerSettings(
            const PointerInputSettings(
              tapSlop: 9,
              doubleTapSlop: 18,
              doubleTapMaxDelayMs: 250,
            ),
          ),
        ),
        DisposeMatrixCase(
          name: 'setDragStartSlop',
          call: (controller) => controller.interaction.setDragStartSlop(9),
        ),
        DisposeMatrixCase(
          name: 'set penThickness',
          call: (controller) => controller.interaction.penThickness = 2,
        ),
        DisposeMatrixCase(
          name: 'set highlighterThickness',
          call: (controller) => controller.interaction.highlighterThickness = 3,
        ),
        DisposeMatrixCase(
          name: 'set lineThickness',
          call: (controller) => controller.interaction.lineThickness = 4,
        ),
        DisposeMatrixCase(
          name: 'set eraserThickness',
          call: (controller) => controller.interaction.eraserThickness = 5,
        ),
        DisposeMatrixCase(
          name: 'set highlighterOpacity',
          call: (controller) => controller.interaction.highlighterOpacity = 0.5,
        ),
        DisposeMatrixCase(
          name: 'setBackgroundColor',
          call: (controller) =>
              controller.scene.setBackgroundColor(const Color(0xFF010203)),
        ),
        DisposeMatrixCase(
          name: 'setGridEnabled',
          call: (controller) => controller.scene.setGridEnabled(true),
        ),
        DisposeMatrixCase(
          name: 'setGridCellSize',
          call: (controller) => controller.scene.setGridCellSize(16),
        ),
        DisposeMatrixCase(
          name: 'setCameraOffset',
          call: (controller) =>
              controller.scene.setCameraOffset(const Offset(4, 5)),
        ),
        DisposeMatrixCase(
          name: 'addNode',
          call: (controller) => controller.scene.addNode(
            RectNodeSpec(id: 'added', size: const Size(10, 10)),
          ),
        ),
        DisposeMatrixCase(
          name: 'patchNode',
          call: (controller) => controller.scene.patchNode(
            RectNodePatch(id: 'a', size: PatchField<Size>.value(Size(30, 20))),
          ),
        ),
        DisposeMatrixCase(
          name: 'removeNode',
          call: (controller) => controller.scene.removeNode('a'),
        ),
        DisposeMatrixCase(
          name: 'setSelection',
          call: (controller) =>
              controller.selection.setSelection(const <NodeId>{'a'}),
        ),
        DisposeMatrixCase(
          name: 'toggleSelection',
          call: (controller) => controller.selection.toggleSelection('a'),
        ),
        DisposeMatrixCase(
          name: 'clearSelection',
          call: (controller) => controller.selection.clearSelection(),
        ),
        DisposeMatrixCase(
          name: 'selectAll',
          call: (controller) =>
              controller.selection.selectAll(onlySelectable: true),
        ),
        DisposeMatrixCase(
          name: 'rotateSelection',
          call: (controller) => controller.selection.rotateSelection(
            clockwise: true,
            timestampMs: 10,
          ),
        ),
        DisposeMatrixCase(
          name: 'flipSelectionVertical',
          call: (controller) =>
              controller.selection.flipSelectionVertical(timestampMs: 11),
        ),
        DisposeMatrixCase(
          name: 'flipSelectionHorizontal',
          call: (controller) =>
              controller.selection.flipSelectionHorizontal(timestampMs: 12),
        ),
        DisposeMatrixCase(
          name: 'deleteSelection',
          call: (controller) =>
              controller.selection.deleteSelection(timestampMs: 13),
        ),
        DisposeMatrixCase(
          name: 'clearScene',
          call: (controller) => controller.scene.clearScene(timestampMs: 14),
        ),
        DisposeMatrixCase(
          name: 'replaceScene',
          call: (controller) => controller.scene.replaceScene(
            SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-auto-0'),
                ContentLayerSnapshot(
                  id: 'layer-auto-1',
                  nodes: <NodeSnapshot>[
                    RectNodeSnapshot(id: 'new', size: Size(5, 5)),
                  ],
                ),
              ],
            ),
          ),
        ),
        DisposeMatrixCase(
          name: 'notifySceneChanged',
          call: (controller) => controller.scene.notifySceneChanged(),
        ),
        DisposeMatrixCase(
          name: 'write',
          call: (controller) => controller.scene.write<void>((writer) {
            writer.writeSelectionClear();
          }),
        ),
        DisposeMatrixCase(
          name: 'handlePointer',
          call: (controller) => controller.interaction.handlePointer(
            sampleInput(
              pointerId: 42,
              position: const Offset(60, 60),
              timestampMs: 100,
              phase: CanvasPointerPhase.down,
            ),
          ),
        ),
        DisposeMatrixCase(
          name: 'handleDoubleTap',
          call: (controller) => controller.interaction.handleDoubleTap(
            position: const Offset(60, 60),
          ),
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
            final controller = controllerFromScene(
              Scene(
                layers: <ContentLayer>[
                  ContentLayer(id: 'layer-auto-6'),
                  ContentLayer(
                    id: 'layer-auto-7',
                    nodes: <SceneNode>[rectA, rectB, textNode],
                  ),
                ],
              ),
            );

            controller.selection.setSelection(const <NodeId>{'a', 'b'});
            final before = captureStableState(controller);

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

            expectStableStateUnchanged(controller, before);
            expect(actions, isEmpty);
            expect(edits, isEmpty);
            expect(notifications, 0);
          },
        );
      }
    });

    testWidgets('pending two-tap line expires after timeout', (tester) async {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-2'),
            ContentLayerSnapshot(id: 'layer-auto-3'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);
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
          position: const Offset(10, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.interaction.hasPendingLineStart, isTrue);
      await tester.pump(const Duration(seconds: 11));
      expect(controller.interaction.hasPendingLineStart, isFalse);
    });

    test(
      'configured draw-mode entry clears selection and delegates commands',
      () {
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-8'),
              ContentLayer(
                id: 'layer-auto-9',
                nodes: <SceneNode>[RectNode(id: 'n', size: const Size(10, 10))],
              ),
            ],
          ),
          clearSelectionOnDrawModeEnter: true,
        );
        addTearDown(controller.dispose);

        controller.selection.setSelection(const <String>{'n'});
        expect(controller.selectedNodeIds, isNotEmpty);
        controller.interaction.setMode(CanvasMode.draw);
        expect(controller.selectedNodeIds, isEmpty);

        controller.interaction.setDrawTool(DrawTool.pen);
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        expect(
          controller.interaction.activeStrokePreviewColor,
          controller.interaction.drawColor,
        );

        controller.scene.setBackgroundColor(const Color(0xFF010203));
        expect(controller.snapshot.background.color, const Color(0xFF010203));

        controller.scene.setCameraOffset(const Offset(3, 4));
        expect(controller.snapshot.camera.offset, const Offset(3, 4));

        expect(
          controller.scene.patchNode(
            RectNodePatch(id: 'n', size: PatchField<Size>.value(Size(20, 10))),
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
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-10'),
              ContentLayer(
                id: 'layer-auto-11',
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

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.eraser);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 10,
            position: const Offset(10, 20),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 10,
            position: const Offset(30, 20),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 10,
            position: const Offset(30, 20),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        await pumpEventQueue();
        expect(actions.any((a) => a.type == ActionType.erase), isTrue);

        controller.scene.replaceScene(
          SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-4'),
              ContentLayerSnapshot(
                id: 'layer-auto-5',
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
        controller.interaction.setMode(CanvasMode.move);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 20,
            position: const Offset(0, 0),
            timestampMs: 10,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 20,
            position: const Offset(80, 80),
            timestampMs: 11,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 20,
            position: const Offset(80, 80),
            timestampMs: 12,
            phase: CanvasPointerPhase.up,
          ),
        );

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 21,
            position: const Offset(50, 50),
            timestampMs: 13,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
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

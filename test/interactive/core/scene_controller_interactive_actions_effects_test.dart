import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
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
              ContentLayer(id: 'layer-auto-0'),
              ContentLayer(
                id: 'layer-auto-1',
                nodes: <SceneNode>[rect, locked],
              ),
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

    test('clearScene emits clear action for structural-only clear', () async {
      final controller = controllerFromScene(
        Scene(layers: <ContentLayer>[ContentLayer(id: 'layer-auto-empty')]),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.clearScene(timestampMs: 205);
      await pumpEventQueue();

      final clearActions = actions.where((a) => a.type == ActionType.clear);
      expect(clearActions, hasLength(1));
      expect(clearActions.single.nodeIds, isEmpty);
    });

    test('clearScene no-op does not emit clear action', () async {
      final controller = controllerFromScene(
        Scene(backgroundLayer: BackgroundLayer()),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.clearScene(timestampMs: 206);
      await pumpEventQueue();

      expect(actions.where((a) => a.type == ActionType.clear), isEmpty);
    });

    test('move drag up emits transform action with delta payload', () async {
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-2'),
            ContentLayer(id: 'layer-auto-3', nodes: <SceneNode>[rect]),
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

    test(
      'move drag applies resolved delta to commit and action payload',
      () async {
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-2b'),
              ContentLayer(id: 'layer-auto-3b', nodes: <SceneNode>[rect]),
            ],
          ),
          moveCommitDeltaResolver:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) {
                expect(snapshot.layers, hasLength(2));
                expect(movedNodes.map((node) => node.id), <String>['node']);
                expect(proposedDelta, const Offset(30, 0));
                return const Offset(40, 0);
              },
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
        final moved = nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(moved.transform.tx, closeTo(100, 1e-6));
        final transformAction = actions.lastWhere(
          (event) => event.type == ActionType.transform,
        );
        expect(transformAction.tryTransformDelta()?.tx, closeTo(40, 1e-6));
      },
    );

    test('move drag skips commit when resolver returns zero delta', () async {
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-2c'),
            ContentLayer(id: 'layer-auto-3c', nodes: <SceneNode>[rect]),
          ],
        ),
        moveCommitDeltaResolver:
            ({
              required SceneSnapshot snapshot,
              required List<NodeSnapshot> movedNodes,
              required Offset proposedDelta,
            }) {
              expect(snapshot.layers, hasLength(2));
              expect(movedNodes, isNotEmpty);
              expect(proposedDelta, const Offset(30, 0));
              return Offset.zero;
            },
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
      final moved = nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(moved.transform.tx, closeTo(60, 1e-6));
      expect(
        actions.where((event) => event.type == ActionType.transform),
        isEmpty,
      );
    });

    test(
      'mutating controller API inside resolver throws and rolls back move commit',
      () async {
        // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        late SceneControllerInteractive controller;
        controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-2resolver'),
              ContentLayer(
                id: 'layer-auto-3resolver',
                nodes: <SceneNode>[rect],
              ),
            ],
          ),
          moveCommitDeltaResolver:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) {
                expect(snapshot.layers, hasLength(2));
                expect(movedNodes.map((node) => node.id), <String>['node']);
                expect(proposedDelta, const Offset(30, 0));
                controller.setMode(CanvasMode.draw);
                return proposedDelta;
              },
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

        expect(
          () => controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 60),
              timestampMs: 3,
              phase: CanvasPointerPhase.up,
            ),
          ),
          throwsStateError,
        );

        await pumpEventQueue();
        final moved = nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(moved.transform.tx, closeTo(60, 1e-6));
        expect(controller.mode, CanvasMode.move);
        expect(
          actions.where((event) => event.type == ActionType.transform),
          isEmpty,
        );
        expect(controller.selectionRect, isNull);

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.selectionRect, isNotNull);
      },
    );

    test(
      'handleDoubleTap inside resolver throws before edit request and clears gesture state',
      () async {
        // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
        final text = TextNode(
          id: 'node',
          text: 'hello',
          size: const Size(80, 24),
          color: const Color(0xFF000000),
        )..position = const Offset(60, 60);
        late SceneControllerInteractive controller;
        controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-2doubletap'),
              ContentLayer(
                id: 'layer-auto-3doubletap',
                nodes: <SceneNode>[text],
              ),
            ],
          ),
          moveCommitDeltaResolver:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) {
                expect(snapshot.layers, hasLength(2));
                expect(movedNodes.map((node) => node.id), <String>['node']);
                expect(proposedDelta, const Offset(30, 0));
                controller.handleDoubleTap(
                  position: const Offset(60, 60),
                  timestampMs: 99,
                );
                return proposedDelta;
              },
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final actionSub = controller.actions.listen(actions.add);
        addTearDown(actionSub.cancel);
        final editRequests = <EditTextRequested>[];
        final editSub = controller.editTextRequests.listen(editRequests.add);
        addTearDown(editSub.cancel);

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

        expect(
          () => controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 60),
              timestampMs: 3,
              phase: CanvasPointerPhase.up,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.toString(),
              'message',
              contains(
                'handleDoubleTap is not allowed during moveCommitDeltaResolver.',
              ),
            ),
          ),
        );

        await pumpEventQueue();
        expect(
          nodeById(controller.snapshot, 'node').transform.tx,
          closeTo(60, 1e-6),
        );
        expect(
          actions.where((event) => event.type == ActionType.transform),
          isEmpty,
        );
        expect(editRequests, isEmpty);
        expect(controller.selectionRect, isNull);

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.selectionRect, isNotNull);
      },
    );

    test(
      'handlePointer inside resolver throws purity guard before reentrancy check',
      () async {
        // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        late SceneControllerInteractive controller;
        controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-2handlepointer'),
              ContentLayer(
                id: 'layer-auto-3handlepointer',
                nodes: <SceneNode>[rect],
              ),
            ],
          ),
          moveCommitDeltaResolver:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) {
                expect(snapshot.layers, hasLength(2));
                expect(movedNodes.map((node) => node.id), <String>['node']);
                expect(proposedDelta, const Offset(30, 0));
                controller.handlePointer(
                  sampleInput(
                    pointerId: 99,
                    position: const Offset(500, 500),
                    timestampMs: 99,
                    phase: CanvasPointerPhase.down,
                  ),
                );
                return proposedDelta;
              },
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

        expect(
          () => controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 60),
              timestampMs: 3,
              phase: CanvasPointerPhase.up,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.toString(),
              'message',
              contains(
                'handlePointer is not allowed during moveCommitDeltaResolver.',
              ),
            ),
          ),
        );

        await pumpEventQueue();
        expect(
          nodeById(controller.snapshot, 'node').transform.tx,
          closeTo(60, 1e-6),
        );
        expect(
          actions.where((event) => event.type == ActionType.transform),
          isEmpty,
        );
        expect(controller.selectionRect, isNull);

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.selectionRect, isNotNull);
      },
    );

    test(
      'reentrant moveCommitDeltaResolver throws and clears gesture state',
      () {
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        late SceneControllerInteractive controller;
        controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-2reentrant'),
              ContentLayer(
                id: 'layer-auto-3reentrant',
                nodes: <SceneNode>[rect],
              ),
            ],
          ),
          moveCommitDeltaResolver:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) {
                return runMoveCommitDeltaResolverForTest(
                  controller,
                  snapshot: snapshot,
                  movedNodes: movedNodes,
                  proposedDelta: proposedDelta,
                );
              },
        );
        addTearDown(controller.dispose);

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

        expect(
          () => controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 60),
              timestampMs: 3,
              phase: CanvasPointerPhase.up,
            ),
          ),
          throwsStateError,
        );

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.selectionRect, isNotNull);
      },
    );

    test('invalid resolved delta clears gesture state before rethrow', () {
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-2d'),
            ContentLayer(id: 'layer-auto-3d', nodes: <SceneNode>[rect]),
          ],
        ),
        moveCommitDeltaResolver:
            ({
              required SceneSnapshot snapshot,
              required List<NodeSnapshot> movedNodes,
              required Offset proposedDelta,
            }) {
              expect(snapshot.layers, hasLength(2));
              expect(movedNodes, isNotEmpty);
              expect(proposedDelta, const Offset(30, 0));
              return const Offset(double.nan, 0);
            },
      );
      addTearDown(controller.dispose);

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

      expect(
        () => controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(100, 60),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        ),
        throwsArgumentError,
      );

      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(200, 200),
          timestampMs: 4,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(230, 230),
          timestampMs: 5,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(controller.selectionRect, isNotNull);
    });

    test('rotateSelection emits transform for multi-node selection', () async {
      final first = RectNode(id: 'a', size: const Size(30, 20))
        ..position = const Offset(40, 40);
      final second = RectNode(id: 'b', size: const Size(30, 20))
        ..position = const Offset(140, 40);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-4'),
            ContentLayer(id: 'layer-auto-5', nodes: <SceneNode>[first, second]),
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
  });
}

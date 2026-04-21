import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

// INV:INV-ENG-INTERACTIVE-MOVE-COMMIT-RESOLVER-NON-REENTRANT

void main() {
  group('SceneController unit', () {
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
        controller.scene.notifySceneChanged();
        await pumpEventQueue();
        expect(notifications, 1);

        controller.selection.setSelection(const <NodeId>{'r', 'locked'});
        controller.selection.rotateSelection(clockwise: true, timestampMs: 100);
        controller.selection.flipSelectionHorizontal(timestampMs: 101);
        controller.selection.flipSelectionVertical(timestampMs: 102);
        controller.selection.deleteSelection(timestampMs: 103);
        expect(nodeById(controller.snapshot, 'locked').id, 'locked');

        controller.scene.clearScene(timestampMs: 104);
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

      controller.scene.clearScene(timestampMs: 205);
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

      controller.scene.clearScene(timestampMs: 206);
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

      controller.selection.setSelection(const <NodeId>{'node'});
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(60, 60),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(90, 60),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.interaction.handlePointer(
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

        controller.selection.setSelection(const <NodeId>{'node'});
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(90, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.interaction.handlePointer(
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

      controller.selection.setSelection(const <NodeId>{'node'});
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(60, 60),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(90, 60),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.interaction.handlePointer(
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
        late SceneController controller;
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
                controller.interaction.setMode(CanvasMode.draw);
                return proposedDelta;
              },
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.selection.setSelection(const <NodeId>{'node'});
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(90, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(
          () => controller.interaction.handlePointer(
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
        expect(controller.interaction.mode, CanvasMode.move);
        expect(
          actions.where((event) => event.type == ActionType.transform),
          isEmpty,
        );
        expect(controller.interaction.selectionRect, isNull);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.interaction.selectionRect, isNotNull);
      },
    );

    test(
      'handleDoubleTap inside resolver throws before edit request and clears gesture state',
      () async {
        // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
        final text = TextNode(
          id: 'node',
          text: 'hello',
          color: const Color(0xFF000000),
        )..position = const Offset(60, 60);
        late SceneController controller;
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
                controller.interaction.handleDoubleTap(
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

        controller.selection.setSelection(const <NodeId>{'node'});
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(90, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(
          () => controller.interaction.handlePointer(
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
        expect(controller.interaction.selectionRect, isNull);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.interaction.selectionRect, isNotNull);
      },
    );

    test(
      'handlePointer inside resolver throws purity guard before reentrancy check',
      () async {
        // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        late SceneController controller;
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
                controller.interaction.handlePointer(
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

        controller.selection.setSelection(const <NodeId>{'node'});
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(90, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(
          () => controller.interaction.handlePointer(
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
        expect(controller.interaction.selectionRect, isNull);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.interaction.selectionRect, isNotNull);
      },
    );

    test(
      'reentrant moveCommitDeltaResolver throws and clears gesture state',
      () {
        // INV:INV-ENG-INTERACTIVE-MOVE-COMMIT-RESOLVER-NON-REENTRANT
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        late SceneController controller;
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

        controller.selection.setSelection(const <NodeId>{'node'});
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(90, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(
          () => controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 60),
              timestampMs: 3,
              phase: CanvasPointerPhase.up,
            ),
          ),
          throwsStateError,
        );

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(200, 200),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(230, 230),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );

        expect(controller.interaction.selectionRect, isNotNull);
      },
    );

    test('invalid resolved delta clears gesture state before rethrow', () {
      // INV:INV-ENG-INTERACTIVE-MOVE-COMMIT-RESOLVER-NON-REENTRANT
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

      controller.selection.setSelection(const <NodeId>{'node'});
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(60, 60),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(90, 60),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(
        () => controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(100, 60),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        ),
        throwsArgumentError,
      );

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(200, 200),
          timestampMs: 4,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(230, 230),
          timestampMs: 5,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(controller.interaction.selectionRect, isNotNull);
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

      controller.selection.setSelection(const <NodeId>{'a', 'b'});
      controller.selection.rotateSelection(clockwise: true, timestampMs: 200);

      await pumpEventQueue();
      final transformActions = actions
          .where((event) => event.type == ActionType.transform)
          .toList(growable: false);
      expect(transformActions, isNotEmpty);
      expect(transformActions.last.nodeIds.toSet(), const <NodeId>{'a', 'b'});
    });

    test(
      'transform and delete actions use shared preflight eligibility',
      () async {
        final movable = RectNode(id: 'movable', size: const Size(30, 20))
          ..position = const Offset(40, 40);
        final locked = RectNode(
          id: 'locked',
          size: const Size(30, 20),
          isLocked: true,
        )..position = const Offset(120, 40);
        final protected = RectNode(
          id: 'protected',
          size: const Size(30, 20),
          isDeletable: false,
        )..position = const Offset(200, 40);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-6'),
              ContentLayer(
                id: 'layer-auto-7',
                nodes: <SceneNode>[movable, locked, protected],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.selection.setSelection(const <NodeId>{
          'movable',
          'locked',
          'protected',
        });
        controller.selection.rotateSelection(clockwise: true, timestampMs: 300);
        controller.selection.deleteSelection(timestampMs: 301);

        await pumpEventQueue();

        final transformActions = actions
            .where((event) => event.type == ActionType.transform)
            .toList(growable: false);
        expect(transformActions, hasLength(1));
        expect(transformActions.single.nodeIds, const <NodeId>[
          'movable',
          'protected',
        ]);

        final deleteActions = actions
            .where((event) => event.type == ActionType.delete)
            .toList(growable: false);
        expect(deleteActions, hasLength(1));
        expect(deleteActions.single.nodeIds, const <NodeId>[
          'movable',
          'locked',
        ]);

        final remaining = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(remaining.contains('protected'), isTrue);
        expect(remaining.contains('movable'), isFalse);
        expect(remaining.contains('locked'), isFalse);
      },
    );

    test(
      'move transform action uses the same eligibility as move preview',
      () async {
        // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
        final movable = RectNode(id: 'movable', size: const Size(30, 20))
          ..position = const Offset(40, 40);
        final locked = RectNode(
          id: 'locked',
          size: const Size(30, 20),
          isLocked: true,
        )..position = const Offset(120, 40);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-8'),
              ContentLayer(
                id: 'layer-auto-9',
                nodes: <SceneNode>[movable, locked],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.selection.setSelection(const <NodeId>{'movable', 'locked'});
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(40, 40),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(80, 40),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(80, 40),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        await pumpEventQueue();

        final transformActions = actions
            .where((event) => event.type == ActionType.transform)
            .toList(growable: false);
        expect(transformActions, hasLength(1));
        expect(transformActions.single.nodeIds, const <NodeId>['movable']);
        expect(
          transformActions.single.tryTransformDelta()?.tx,
          closeTo(40, 1e-6),
        );

        final movableAfter =
            nodeById(controller.snapshot, 'movable') as RectNodeSnapshot;
        final lockedAfter =
            nodeById(controller.snapshot, 'locked') as RectNodeSnapshot;
        expect(movableAfter.transform.tx, closeTo(80, 1e-6));
        expect(lockedAfter.transform.tx, closeTo(120, 1e-6));
      },
    );

    test(
      'move commit does not translate visible non-selectable selected nodes',
      () async {
        final movable = RectNode(id: 'movable', size: const Size(30, 20))
          ..position = const Offset(40, 40);
        final hiddenFromSelectionPolicy = RectNode(
          id: 'non-selectable',
          size: const Size(30, 20),
          isSelectable: false,
        )..position = const Offset(120, 40);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-10'),
              ContentLayer(
                id: 'layer-auto-11',
                nodes: <SceneNode>[movable, hiddenFromSelectionPolicy],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.selection.setSelection(const <NodeId>{
          'movable',
          'non-selectable',
        });
        expect(controller.selectedNodeIds, const <NodeId>{
          'movable',
          'non-selectable',
        });

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(40, 40),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(80, 40),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(80, 40),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        await pumpEventQueue();

        final transformActions = actions
            .where((event) => event.type == ActionType.transform)
            .toList(growable: false);
        expect(transformActions, hasLength(1));
        expect(transformActions.single.nodeIds, const <NodeId>['movable']);

        final movableAfter =
            nodeById(controller.snapshot, 'movable') as RectNodeSnapshot;
        final nonSelectableAfter =
            nodeById(controller.snapshot, 'non-selectable') as RectNodeSnapshot;
        expect(movableAfter.transform.tx, closeTo(80, 1e-6));
        expect(nonSelectableAfter.transform.tx, closeTo(120, 1e-6));
      },
    );
  });
}

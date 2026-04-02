import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/core/grid_safety_limits.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_interaction_runtime.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_mutation_boundary.dart';

// INV:INV-ENG-INTERACTIVE-MUTATION-BOUNDARY

void main() {
  group('SceneControllerMutationBoundary', () {
    test('applies scene mutations and replacement side effects', () async {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'base', size: const Size(20, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final emitted =
          <
            ({
              ActionType type,
              List<NodeId> nodeIds,
              int timestampMs,
              Map<String, Object?>? payload,
            })
          >[];
      var clearPointerNormalizationCalls = 0;
      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      final boundary = SceneControllerMutationBoundary(
        storeController: controller,
        readSnapshot: () => controller.snapshot,
        callbacks: SceneControllerMutationBoundaryCallbacks(
          resolveTimestampMs: (timestampMs) => timestampMs ?? -1,
          emitAction:
              (type, nodeIds, timestampMs, {Map<String, Object?>? payload}) {
                emitted.add((
                  type: type,
                  nodeIds: List<NodeId>.from(nodeIds),
                  timestampMs: timestampMs,
                  payload: payload,
                ));
              },
          resolveMoveCommitDelta:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) => proposedDelta,
          requireFiniteOffset: (value, {required name}) {
            if (!value.dx.isFinite || !value.dy.isFinite) {
              throw ArgumentError.value(value, name, 'Must be finite.');
            }
          },
          clearPointerNormalizationState: () {
            clearPointerNormalizationCalls = clearPointerNormalizationCalls + 1;
          },
        ),
      );

      expect(boundary.ensureLayer('layer-auto-1', index: 0), isTrue);
      expect(
        boundary.addNode(
          RectNodeSpec(id: 'added', size: const Size(8, 8)),
          layerId: 'layer-auto-1',
        ),
        'added',
      );
      expect(
        boundary.patchNode(
          RectNodePatch(id: 'added', strokeWidth: PatchField<double>.value(2)),
        ),
        isTrue,
      );
      expect(boundary.removeNode('added', timestampMs: 7), isTrue);
      expect(emitted.last.type, ActionType.delete);
      expect(emitted.last.nodeIds, <NodeId>['added']);
      expect(emitted.last.timestampMs, 7);

      boundary.setBackgroundColor(const Color(0xFF00FF00));
      boundary.setGridEnabled(true);
      boundary.setGridCellSize(1);
      expect(controller.snapshot.background.grid.cellSize, kMinGridCellSize);

      expect(() => boundary.setGridCellSize(0), throwsArgumentError);
      expect(
        () => boundary.validateCameraOffset(const Offset(double.nan, 0)),
        throwsArgumentError,
      );
      boundary.validateCameraOffset(const Offset(5, 6));
      expect(boundary.shouldApplyCameraOffset(const Offset(5, 6)), isTrue);
      boundary.setCameraOffset(const Offset(5, 6));
      expect(boundary.shouldApplyCameraOffset(const Offset(5, 6)), isFalse);

      boundary.clearScene(timestampMs: 8);
      expect(emitted.last.type, ActionType.clear);
      expect(emitted.last.nodeIds, <NodeId>['base']);
      expect(emitted.last.timestampMs, 8);

      final replacement = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-replaced',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'fresh',
                size: const Size(4, 4),
                transform: Transform2D.translation(const Offset(3, 4)),
              ),
            ],
          ),
        ],
      );
      final prepared = boundary.prepareSceneReplacement(replacement);
      boundary.replaceScene(prepared);
      expect(clearPointerNormalizationCalls, 1);
      expect(controller.snapshot.layers.single.nodes.single.id, 'fresh');

      boundary.notifySceneChanged();
      await pumpEventQueue();
      expect(notifications, greaterThan(0));
    });

    test('emits clear action for structural clear without removed nodes', () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: const <NodeSnapshot>[],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final emitted =
          <
            ({
              ActionType type,
              List<NodeId> nodeIds,
              int timestampMs,
              Map<String, Object?>? payload,
            })
          >[];

      final boundary = SceneControllerMutationBoundary(
        storeController: controller,
        readSnapshot: () => controller.snapshot,
        callbacks: SceneControllerMutationBoundaryCallbacks(
          resolveTimestampMs: (timestampMs) => timestampMs ?? -1,
          emitAction:
              (type, nodeIds, timestampMs, {Map<String, Object?>? payload}) {
                emitted.add((
                  type: type,
                  nodeIds: List<NodeId>.from(nodeIds),
                  timestampMs: timestampMs,
                  payload: payload,
                ));
              },
          resolveMoveCommitDelta:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) => proposedDelta,
          requireFiniteOffset: (value, {required name}) {},
          clearPointerNormalizationState: () {},
        ),
      );

      boundary.clearScene(timestampMs: 9);

      expect(emitted, hasLength(1));
      expect(emitted.single.type, ActionType.clear);
      expect(emitted.single.nodeIds, isEmpty);
      expect(emitted.single.timestampMs, 9);
    });

    test('applies selection transforms deletion and move commits', () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'a',
                  size: const Size(20, 10),
                  transform: Transform2D.translation(const Offset(10, 10)),
                ),
                RectNodeSnapshot(
                  id: 'b',
                  size: const Size(20, 10),
                  transform: Transform2D.translation(const Offset(40, 10)),
                ),
                RectNodeSnapshot(
                  id: 'locked',
                  size: const Size(20, 10),
                  isLocked: true,
                  isDeletable: false,
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final emitted =
          <
            ({
              ActionType type,
              List<NodeId> nodeIds,
              int timestampMs,
              Map<String, Object?>? payload,
            })
          >[];

      final boundary = SceneControllerMutationBoundary(
        storeController: controller,
        readSnapshot: () => controller.snapshot,
        callbacks: SceneControllerMutationBoundaryCallbacks(
          resolveTimestampMs: (timestampMs) => timestampMs ?? -1,
          emitAction:
              (type, nodeIds, timestampMs, {Map<String, Object?>? payload}) {
                emitted.add((
                  type: type,
                  nodeIds: List<NodeId>.from(nodeIds),
                  timestampMs: timestampMs,
                  payload: payload,
                ));
              },
          resolveMoveCommitDelta:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) {
                expect(snapshot.layers.single.nodes, hasLength(2));
                expect(movedNodes.map((node) => node.id), <NodeId>['b']);
                expect(proposedDelta, const Offset(10, 0));
                return const Offset(15, 0);
              },
          requireFiniteOffset: (value, {required name}) {
            if (!value.dx.isFinite || !value.dy.isFinite) {
              throw ArgumentError.value(value, name, 'Must be finite.');
            }
          },
          clearPointerNormalizationState: () {},
        ),
      );

      boundary.setSelection(const <NodeId>{'a', 'b'});
      boundary.rotateSelection(clockwise: true, timestampMs: 10);
      boundary.flipSelectionHorizontal(timestampMs: 11);
      boundary.flipSelectionVertical(timestampMs: 12);

      final transformActions = emitted
          .where((event) => event.type == ActionType.transform)
          .toList(growable: false);
      expect(transformActions, hasLength(3));
      expect(
        transformActions.every((event) => event.payload?['delta'] != null),
        isTrue,
      );

      boundary.toggleSelection('locked');
      expect(controller.selectedNodeIds, const <NodeId>{'a', 'b', 'locked'});
      boundary.clearSelection();
      expect(controller.selectedNodeIds, isEmpty);
      boundary.selectAll(onlySelectable: false);
      expect(controller.selectedNodeIds, const <NodeId>{'a', 'b', 'locked'});

      boundary.deleteSelection(timestampMs: 13);
      expect(emitted.last.type, ActionType.delete);
      expect(emitted.last.nodeIds, <NodeId>['a', 'b']);
      expect(
        controller.snapshot.layers.single.nodes.map((node) => node.id).toList(),
        <NodeId>['locked'],
      );

      controller.write<void>((writer) {
        writer.writeNodeInsert(
          RectNodeSpec(
            id: 'b',
            size: const Size(20, 10),
            transform: Transform2D.translation(const Offset(40, 10)),
          ),
        );
        writer.writeSelectionReplace(const <NodeId>{'b'});
      });

      final moveResult = boundary.commitMoveSelection(const Offset(10, 0));
      expect(moveResult.appliedDelta, const Offset(15, 0));
      expect(moveResult.movedIds, <NodeId>['b']);

      final movedNode =
          controller.snapshot.layers.single.nodes.last as RectNodeSnapshot;
      expect(movedNode.transform.tx, 55);
      expect(movedNode.transform.ty, 10);
    });

    test(
      'runtime mutation api covers selection action delegation shells',
      () async {
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(
                id: 'layer-auto-0',
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(
                    id: 'a',
                    size: const Size(20, 10),
                    transform: Transform2D.translation(const Offset(10, 10)),
                  ),
                  RectNodeSnapshot(
                    id: 'b',
                    size: const Size(20, 10),
                    transform: Transform2D.translation(const Offset(40, 10)),
                  ),
                  RectNodeSnapshot(id: 'extra', size: const Size(12, 12)),
                ],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final committed = <ActionCommitted>[];
        final sub = controller.actions.listen(committed.add);
        addTearDown(sub.cancel);

        final runtime = sceneControllerInternalInteractionAccessForTest(
          controller,
        ).runtime;

        expect(runtime.resolveTimestampMs(77), 77);
        runtime.emitAction(ActionType.clear, const <NodeId>[], 78);

        controller.selection.setSelection(const <NodeId>{'a', 'b'});
        runtime.rotateSelection(clockwise: true, timestampMs: 79);
        runtime.flipSelectionHorizontal(timestampMs: 80);
        runtime.flipSelectionVertical(timestampMs: 81);

        final moveResult = runtime.selectionActions.commitMoveSelection(
          const Offset(5, 0),
        );
        expect(moveResult.appliedDelta, const Offset(5, 0));
        expect(moveResult.movedIds, unorderedEquals(const <NodeId>['a', 'b']));

        runtime.deleteSelection(timestampMs: 82);
        runtime.clearSceneSelectionState(timestampMs: 83);
        runtime.clearPointerNormalizationState();

        await pumpEventQueue();

        expect(
          committed.any((event) => event.type == ActionType.clear),
          isTrue,
        );
        expect(
          committed.where((event) => event.type == ActionType.transform),
          isNotEmpty,
        );
        expect(
          committed.where((event) => event.type == ActionType.delete),
          isNotEmpty,
        );
        expect(
          controller.snapshot.layers.every((layer) => layer.nodes.isEmpty),
          isTrue,
        );
      },
    );
  });
}

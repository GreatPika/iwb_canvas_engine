import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller_committed_mutation_access.dart';
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

      final mutationAccess = SceneStoreControllerCommittedMutationAccess(
        controller,
      );
      final boundary = SceneControllerMutationBoundary(
        mutationAccess: mutationAccess,
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
          schedulePublicNotify: () {},
          scheduleSceneRepaint: () {},
          scheduleOverlayRepaint: () {},
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

      final strokeId = boundary.commitDrawStroke(
        points: const <Offset>[Offset.zero, Offset(4, 4)],
        thickness: 2,
        color: const Color(0xFF112233),
        opacity: 1,
      );
      final lineId = boundary.commitDrawLineFromWorldSegment(
        start: const Offset(2, 2),
        end: const Offset(8, 8),
        thickness: 3,
        color: const Color(0xFF445566),
        opacity: 1,
      );
      final removedDrawCount = boundary.commitEraseNodes(<NodeId>{strokeId});
      expect(strokeId, isNotEmpty);
      expect(lineId, isNotEmpty);
      expect(removedDrawCount, 1);
      expect(
        controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .map((node) => node.id)
            .contains(lineId),
        isTrue,
      );

      boundary.setBackgroundColor(const Color(0xFF00FF00));
      boundary.setGridEnabled(true);
      boundary.setGridCellSize(kMinGridCellSize);
      expect(controller.snapshot.background.grid.cellSize, kMinGridCellSize);

      expect(() => boundary.setGridCellSize(0), throwsArgumentError);
      expect(() => boundary.setGridCellSize(0.5), throwsArgumentError);
      boundary.setGridEnabled(false);
      boundary.setGridCellSize(0.5);
      expect(controller.snapshot.background.grid.cellSize, 0.5);
      expect(() => boundary.setGridEnabled(true), throwsArgumentError);
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
      expect(emitted.last.nodeIds, unorderedEquals(<NodeId>['base', lineId]));
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
      var interruptCalls = 0;
      boundary.replaceScene(
        replacement,
        interruptBeforeApply: () {
          interruptCalls = interruptCalls + 1;
          expect(controller.snapshot.layers, isEmpty);
        },
      );
      expect(interruptCalls, 1);
      expect(clearPointerNormalizationCalls, 1);
      expect(controller.snapshot.layers.single.nodes.single.id, 'fresh');

      boundary.notifySceneChanged();
      await pumpEventQueue();
      expect(notifications, greaterThan(0));
    });

    test('schedules repaint callbacks only for real committed changes', () {
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

      var publicNotifyCalls = 0;
      var sceneRepaintCalls = 0;
      var overlayRepaintCalls = 0;

      final boundary = SceneControllerMutationBoundary(
        mutationAccess: SceneStoreControllerCommittedMutationAccess(controller),
        readSnapshot: () => controller.snapshot,
        callbacks: SceneControllerMutationBoundaryCallbacks(
          resolveTimestampMs: (timestampMs) => timestampMs ?? -1,
          emitAction:
              (type, nodeIds, timestampMs, {Map<String, Object?>? payload}) {},
          resolveMoveCommitDelta:
              ({
                required SceneSnapshot snapshot,
                required List<NodeSnapshot> movedNodes,
                required Offset proposedDelta,
              }) => proposedDelta,
          requireFiniteOffset: (value, {required name}) {},
          clearPointerNormalizationState: () {},
          schedulePublicNotify: () {
            publicNotifyCalls += 1;
          },
          scheduleSceneRepaint: () {
            sceneRepaintCalls += 1;
          },
          scheduleOverlayRepaint: () {
            overlayRepaintCalls += 1;
          },
        ),
      );

      boundary.write<void>((_) {});
      boundary.setBackgroundColor(controller.snapshot.background.color);
      boundary.setGridEnabled(controller.snapshot.background.grid.isEnabled);
      boundary.setGridCellSize(controller.snapshot.background.grid.cellSize);
      boundary.setSelection(const <NodeId>{});
      boundary.clearSelection();
      boundary.toggleSelection('missing');

      expect(publicNotifyCalls, 0);
      expect(sceneRepaintCalls, 0);
      expect(overlayRepaintCalls, 0);

      boundary.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'base'});
      });
      expect(publicNotifyCalls, 1);
      expect(sceneRepaintCalls, 1);
      expect(overlayRepaintCalls, 1);

      publicNotifyCalls = 0;
      sceneRepaintCalls = 0;
      overlayRepaintCalls = 0;

      boundary.clearSelection();
      expect(publicNotifyCalls, 1);
      expect(sceneRepaintCalls, 1);
      expect(overlayRepaintCalls, 0);
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

      final mutationAccess = SceneStoreControllerCommittedMutationAccess(
        controller,
      );
      final boundary = SceneControllerMutationBoundary(
        mutationAccess: mutationAccess,
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
          schedulePublicNotify: () {},
          scheduleSceneRepaint: () {},
          scheduleOverlayRepaint: () {},
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

      final mutationAccess = SceneStoreControllerCommittedMutationAccess(
        controller,
      );
      final boundary = SceneControllerMutationBoundary(
        mutationAccess: mutationAccess,
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
          schedulePublicNotify: () {},
          scheduleSceneRepaint: () {},
          scheduleOverlayRepaint: () {},
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

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/action_events.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_gesture_machine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_move_callbacks.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_move_session.dart';

void main() {
  InteractiveMoveSessionCallbacks buildCallbacks({
    required VoidCallback onPublicStateChanged,
    required VoidCallback onSceneStateChanged,
    required VoidCallback onOverlayStateChanged,
    SceneSnapshot Function()? readSnapshot,
    Set<NodeId> Function()? readSelectedNodeIds,
    List<SceneHitTestSpatialCandidate> Function(Rect bounds)?
    queryHitTestCandidates,
    NodeSnapshot? Function(SceneSpatialCandidateReference candidate)?
    resolveSpatialCandidateSnapshot,
    MoveCommitSelectionResult Function(Offset proposedDelta)?
    commitMoveSelection,
    void Function(
      ActionType actionType,
      List<NodeId> nodeIds,
      int timestampMs, {
      Map<String, Object?>? payload,
    })?
    emitAction,
  }) {
    return InteractiveMoveSessionCallbacks(
      onPublicStateChanged: onPublicStateChanged,
      onSceneStateChanged: onSceneStateChanged,
      onOverlayStateChanged: onOverlayStateChanged,
      readSnapshot: readSnapshot ?? SceneSnapshot.new,
      readSelectedNodeIds: readSelectedNodeIds ?? () => const <NodeId>{},
      queryHitTestCandidates:
          queryHitTestCandidates ??
          (_) => const <SceneHitTestSpatialCandidate>[],
      resolveSpatialCandidateSnapshot:
          resolveSpatialCandidateSnapshot ?? (_) => null,
      writeSelectionReplace: (_) {},
      writeSelectionClear: () {},
      commitMoveSelection:
          commitMoveSelection ??
          (_) => (appliedDelta: Offset.zero, movedIds: const <NodeId>[]),
      emitAction:
          emitAction ??
          (
            ActionType actionType,
            List<NodeId> nodeIds,
            int timestampMs, {
            Map<String, Object?>? payload,
          }) {},
    );
  }

  group('Interactive internals', () {
    test('gesture machine keeps active gesture state coherent', () {
      final machine = InteractiveGestureMachine();

      expect(machine.hasActiveGesture, isFalse);
      final activeGesture = machine.begin(
        pointerId: 7,
        family: InteractiveGestureFamily.move,
        dragStartSlop: 12,
      );

      expect(activeGesture, isNotNull);
      expect(activeGesture?.pointerId, 7);
      expect(activeGesture?.family, InteractiveGestureFamily.move);
      expect(activeGesture?.dragStartSlop, 12);
      expect(machine.ownsPointer(7), isTrue);
      expect(machine.activeGestureForPointer(7), same(activeGesture));
      expect(machine.activeFamily, InteractiveGestureFamily.move);
      expect(machine.activeDragStartSlop, 12);

      expect(machine.interruptActiveGesture(), InteractiveGestureFamily.move);
      expect(machine.hasActiveGesture, isFalse);
      expect(machine.activeGesture, isNull);
      expect(machine.activeFamily, isNull);
      expect(machine.activeDragStartSlop, isNull);
    });

    test('setSelectionRect notifies only for actual changes', () {
      var stateChanges = 0;
      final session = InteractiveMoveSession(
        callbacks: buildCallbacks(
          onPublicStateChanged: () {},
          onSceneStateChanged: () {
            stateChanges += 1;
          },
          onOverlayStateChanged: () {
            stateChanges += 1;
          },
        ),
      );
      addTearDown(session.dispose);

      final rect = Rect.fromLTWH(10, 20, 30, 40);
      session.setSelectionRect(rect);
      session.setSelectionRect(rect);
      session.setSelectionRect(null);

      expect(stateChanges, 2);
      expect(session.selectionRect, isNull);
    });

    group('move preview scene notifications', () {
      const nodeId = 'node';
      final rect = RectNodeSnapshot(
        id: nodeId,
        size: const Size(20, 20),
        strokeColor: const Color(0xFF000000),
      );
      final snapshot = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(id: 'layer', nodes: <NodeSnapshot>[rect]),
        ],
      );
      const candidate = SceneHitTestSpatialCandidate(
        nodeId: nodeId,
        layerIndex: 0,
        nodeIndex: 0,
        hitTestBoundsWorld: Rect.fromLTWH(0, 0, 20, 20),
      );

      InteractiveMoveSession buildMoveSession({
        required VoidCallback onSceneStateChanged,
        required MoveCommitSelectionResult Function(Offset proposedDelta)
        commitMoveSelection,
        required void Function(
          ActionType actionType,
          List<NodeId> nodeIds,
          int timestampMs, {
          Map<String, Object?>? payload,
        })
        emitAction,
      }) {
        return InteractiveMoveSession(
          callbacks: buildCallbacks(
            onPublicStateChanged: () {},
            onSceneStateChanged: onSceneStateChanged,
            onOverlayStateChanged: () {},
            readSnapshot: () => snapshot,
            readSelectedNodeIds: () => const <NodeId>{nodeId},
            queryHitTestCandidates: (_) => const <SceneHitTestSpatialCandidate>[
              candidate,
            ],
            resolveSpatialCandidateSnapshot: (location) =>
                location.layerIndex == candidate.layerIndex &&
                    location.nodeIndex == candidate.nodeIndex
                ? rect
                : null,
            commitMoveSelection: commitMoveSelection,
            emitAction: emitAction,
          ),
        );
      }

      test('selected-node move tap emits no scene callback or action', () {
        var sceneChanges = 0;
        var commitCalls = 0;
        var emittedActions = 0;
        final session = buildMoveSession(
          onSceneStateChanged: () {
            sceneChanges += 1;
          },
          commitMoveSelection: (_) {
            commitCalls += 1;
            return (appliedDelta: Offset.zero, movedIds: const <NodeId>[]);
          },
          emitAction: (_, _, _, {payload}) {
            emittedActions += 1;
          },
        );
        addTearDown(session.dispose);

        session.handlePointer(
          const PointerSample(
            pointerId: 1,
            position: Offset(10, 10),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          const Offset(10, 10),
          dragStartSlop: 8,
        );
        session.handlePointer(
          const PointerSample(
            pointerId: 1,
            position: Offset(10, 10),
            timestampMs: 2,
            phase: PointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
          const Offset(10, 10),
          dragStartSlop: 8,
        );

        expect(sceneChanges, 0);
        expect(commitCalls, 0);
        expect(emittedActions, 0);
        expect(session.movePreviewDeltaForNode(nodeId), Offset.zero);
      });

      test('selected-node move drag emits scene callback from move only', () {
        var sceneChanges = 0;
        final session = buildMoveSession(
          onSceneStateChanged: () {
            sceneChanges += 1;
          },
          commitMoveSelection: (proposedDelta) =>
              (appliedDelta: proposedDelta, movedIds: const <NodeId>[nodeId]),
          emitAction: (_, _, _, {payload}) {},
        );
        addTearDown(session.dispose);

        session.handlePointer(
          const PointerSample(
            pointerId: 1,
            position: Offset(10, 10),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          const Offset(10, 10),
          dragStartSlop: 1,
        );
        session.handlePointer(
          const PointerSample(
            pointerId: 1,
            position: Offset(16, 10),
            timestampMs: 2,
            phase: PointerPhase.move,
            kind: PointerDeviceKind.touch,
          ),
          const Offset(16, 10),
          dragStartSlop: 1,
        );

        expect(sceneChanges, 1);
        expect(session.movePreviewDeltaForNode(nodeId), const Offset(6, 0));
      });
    });
  });
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/action_events.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_gesture_machine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_move_callbacks.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_move_session.dart';

void main() {
  InteractiveMoveSessionCallbacks buildCallbacks({
    required VoidCallback onStateChanged,
  }) {
    return InteractiveMoveSessionCallbacks(
      onStateChanged: onStateChanged,
      readSnapshot: SceneSnapshot.new,
      readSelectedNodeIds: () => const <NodeId>{},
      querySpatialCandidates: (_) => const <SceneSpatialCandidate>[],
      resolveSpatialCandidateNode: (_) => null,
      writeSelectionReplace: (_) {},
      writeSelectionClear: () {},
      commitMoveSelection: (_) =>
          (appliedDelta: Offset.zero, movedIds: const <NodeId>[]),
      emitAction:
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

      expect(machine.reset(), InteractiveGestureFamily.move);
      expect(machine.hasActiveGesture, isFalse);
      expect(machine.activeGesture, isNull);
      expect(machine.activeFamily, isNull);
      expect(machine.activeDragStartSlop, isNull);
    });

    test('setSelectionRect notifies only for actual changes', () {
      var stateChanges = 0;
      final session = InteractiveMoveSession(
        callbacks: buildCallbacks(
          onStateChanged: () {
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
  });
}

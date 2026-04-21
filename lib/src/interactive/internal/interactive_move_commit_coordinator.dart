import 'dart:ui';

import '../../contract/pointer_input.dart';
import '../../core/action_events.dart';
import '../../contract/transform2d.dart';
import 'interactive_move_callbacks.dart';
import 'interactive_move_gesture_state.dart';
import 'interactive_move_preview_state.dart';
import 'interactive_move_selection_coordinator.dart';

final class InteractiveMoveCommitCoordinator {
  const InteractiveMoveCommitCoordinator({
    required this.callbacks,
    required this.previewState,
    required this.selectionCoordinator,
  });

  final InteractiveMoveSessionCallbacks callbacks;
  final InteractiveMovePreviewState previewState;
  final InteractiveMoveSelectionCoordinator selectionCoordinator;

  void commit(
    PointerSample sample, {
    required InteractiveMoveGestureState gestureState,
  }) {
    switch (sample.phase) {
      case PointerPhase.down:
      case PointerPhase.move:
      case PointerPhase.cancel:
        return;
      case PointerPhase.up:
        break;
    }

    if (gestureState.target == InteractiveMoveDragTarget.move) {
      _commitMovePreview(sample, gestureState: gestureState);
      return;
    }

    if (gestureState.target != InteractiveMoveDragTarget.marquee) {
      return;
    }

    final rect = gestureState.selectionRect;
    if (gestureState.dragStarted && rect != null) {
      selectionCoordinator.commitMarquee(
        rect: rect,
        timestampMs: sample.timestampMs,
      );
      return;
    }

    if (gestureState.pendingClearSelection) {
      selectionCoordinator.writeSelectionClearIfChanged();
    }
  }

  void commitCancelRestore() {
    selectionCoordinator.restoreBaselineSelectionIfNeeded();
  }

  void _commitMovePreview(
    PointerSample sample, {
    required InteractiveMoveGestureState gestureState,
  }) {
    final proposedDelta = previewState.delta;
    if (!gestureState.dragStarted || proposedDelta == Offset.zero) {
      return;
    }

    final moveCommit = callbacks.commitMoveSelection(proposedDelta);
    if (moveCommit.appliedDelta == Offset.zero || moveCommit.movedIds.isEmpty) {
      return;
    }

    final delta = Transform2D.translation(moveCommit.appliedDelta);
    callbacks.emitAction(
      ActionType.transform,
      moveCommit.movedIds,
      sample.timestampMs,
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
  }
}

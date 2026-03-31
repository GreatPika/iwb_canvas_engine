import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_controller.dart';
import '../../core/action_events.dart';
import '../../core/interaction_types.dart';
import '../scene_controller_interaction.dart';
import 'interactive_draw_style.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_runtime.dart';
import 'interactive_runtime_callbacks.dart';
import 'interactive_selection_actions.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required MoveCommitDeltaResolver? moveCommitDeltaResolver,
    required this.core,
    required this.notifyScheduler,
    required this.events,
    required this.selectionActions,
    required this.runtime,
  }) : _moveCommitDeltaResolver = moveCommitDeltaResolver;

  final SceneControllerCore core;
  final MoveCommitDeltaResolver? _moveCommitDeltaResolver;
  final InteractiveNotifyScheduler notifyScheduler;
  final InteractiveEventDispatcher events;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;

  bool _isDisposed = false;
  bool _moveCommitResolverActive = false;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {
    if (_moveCommitResolverActive) {
      throw StateError(
        '$operation is not allowed during moveCommitDeltaResolver.',
      );
    }
    if (!allowAfterDispose && _isDisposed) {
      throw StateError('SceneController is disposed and no longer usable.');
    }
  }

  void ensureExternalMutationAllowed(String operation) {
    if (runtime.hasActiveGesture) {
      throw StateError('$operation is not allowed during an active gesture.');
    }
  }

  void resetActiveGestureForExternalMutation(String _) {
    runtime.resetInteractiveState();
  }

  void scheduleNotify() {
    notifyScheduler.schedule();
  }

  Offset runMoveCommitDeltaResolver({
    required SceneSnapshot snapshot,
    required List<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  }) {
    final resolver = _moveCommitDeltaResolver;
    if (resolver == null) {
      return proposedDelta;
    }
    if (_moveCommitResolverActive) {
      throw StateError(
        'Reentrant moveCommitDeltaResolver(...) is not allowed.',
      );
    }

    _moveCommitResolverActive = true;
    try {
      return resolver(
        snapshot: snapshot,
        movedNodes: movedNodes,
        proposedDelta: proposedDelta,
      );
    } finally {
      _moveCommitResolverActive = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    notifyScheduler.dispose();
    runtime.dispose();
    events.dispose();
  }

  void _handleCoreChanged() {
    scheduleNotify();
  }
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.notifyListeners,
    required this.core,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readMode,
    required this.readDragStartSlop,
    required this.readDrawStyle,
    required this.requireFiniteOffset,
    required this.moveCommitDeltaResolver,
  });

  final void Function() notifyListeners;
  final SceneControllerCore core;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final CanvasMode Function() readMode;
  final double Function() readDragStartSlop;
  final InteractiveDrawStyle Function() readDrawStyle;
  final void Function(Offset value, {required String name}) requireFiniteOffset;
  final MoveCommitDeltaResolver? moveCommitDeltaResolver;
}

SceneControllerInteractionRuntime createSceneControllerInteractionRuntime({
  required SceneControllerInteractionRuntimeRequest request,
}) {
  final notifyScheduler = InteractiveNotifyScheduler(
    notifyListeners: request.notifyListeners,
  );
  final events = InteractiveEventDispatcher();
  late final SceneControllerInteractionRuntime wiredRuntime;
  final selectionActions = _createSelectionActions(request, () => wiredRuntime);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    notifyScheduler: notifyScheduler,
    events: events,
    selectionActions: selectionActions,
  );
  wiredRuntime = SceneControllerInteractionRuntime._(
    moveCommitDeltaResolver: request.moveCommitDeltaResolver,
    core: request.core,
    notifyScheduler: notifyScheduler,
    events: events,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
  request.core.addListener(wiredRuntime._handleCoreChanged);
  return wiredRuntime;
}

extension SceneControllerInteractionRuntimeStateApi
    on SceneControllerInteractionRuntime {
  bool get isDisposed => _isDisposed;
  Stream<ActionCommitted> get actions => events.actions;
  Stream<EditTextRequested> get editTextRequests => events.editTextRequests;
  Rect? get selectionRect => runtime.selectionRect;
  Offset? get pendingLineStart => runtime.pendingLineStart;
  int? get pendingLineTimestampMs => runtime.pendingLineTimestampMs;
  bool get hasPendingLineStart => runtime.hasPendingLineStart;
  bool get hasActiveGesture => runtime.hasActiveGesture;
  bool get isActiveDrawGesture => runtime.isActiveDrawGesture;
  bool get hasActiveStrokePoints => runtime.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      runtime.activeStrokePreviewPoints;
  Offset? get activeLinePreviewStart => runtime.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => runtime.activeLinePreviewEnd;
  int get activeEraserPointsLength => runtime.activeEraserPointsLength;
  int get eraserSpatialQueryCount => runtime.debugEraserSpatialQueryCount;
  int get eraserPreciseSegmentCheckCount =>
      runtime.debugEraserPreciseSegmentChecks;

  void resetInteractiveState() {
    runtime.resetInteractiveState();
  }

  void clearPointerNormalizationState() {
    runtime.clearPointerNormalizationState();
  }
}

extension SceneControllerInteractionRuntimeMutationApi
    on SceneControllerInteractionRuntime {
  int resolveTimestampMs(int? timestampMs) {
    return events.resolveTimestampMs(timestampMs);
  }

  void emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) {
    events.emitAction(type, nodeIds, timestampMs, payload: payload);
  }

  void clearSceneSelectionState({int? timestampMs}) {
    selectionActions.clearScene(timestampMs: timestampMs);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    selectionActions.rotateSelection(
      clockwise: clockwise,
      timestampMs: timestampMs,
    );
  }

  void flipSelectionVertical({int? timestampMs}) {
    selectionActions.flipSelectionVertical(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    selectionActions.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    selectionActions.deleteSelection(timestampMs: timestampMs);
  }

  Offset previewDeltaForNode(NodeId nodeId) {
    return runtime.debugMoveSession.movePreviewDeltaForNode(nodeId);
  }

  void setBeforePointerDispatchHook(VoidCallback? hook) {
    runtime.setBeforePointerDispatchHook(hook);
  }

  void handlePointer(CanvasPointerInput input) {
    runtime.handlePointer(input);
  }

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    runtime.handleDoubleTap(position: position, timestampMs: timestampMs);
  }
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerInteractionRuntimeRequest request,
  SceneControllerInteractionRuntime Function() readRuntime,
) {
  return InteractiveSelectionActions(
    core: request.core,
    callbacks: InteractiveSelectionActionsCallbacks(
      resolveTimestampMs: (timestampMs) =>
          readRuntime().events.resolveTimestampMs(timestampMs),
      emitAction: (type, nodeIds, timestampMs, {payload}) {
        readRuntime().events.emitAction(
          type,
          nodeIds,
          timestampMs,
          payload: payload,
        );
      },
      resolveMoveCommitDelta:
          ({required snapshot, required movedNodes, required proposedDelta}) =>
              readRuntime().runMoveCommitDeltaResolver(
                snapshot: snapshot,
                movedNodes: movedNodes,
                proposedDelta: proposedDelta,
              ),
      requireFiniteOffset: request.requireFiniteOffset,
    ),
  );
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required InteractiveNotifyScheduler notifyScheduler,
  required InteractiveEventDispatcher events,
  required InteractiveSelectionActions selectionActions,
}) {
  return InteractiveRuntime(
    events: events,
    callbacks: InteractiveRuntimeCallbacks(
      scheduleNotify: notifyScheduler.schedule,
      readSnapshot: request.readSnapshot,
      readSelectedNodeIds: request.readSelectedNodeIds,
      readMode: request.readMode,
      readDragStartSlop: request.readDragStartSlop,
      readDrawStyle: request.readDrawStyle,
      querySpatialCandidates: request.core.querySpatialCandidates,
      resolveSpatialCandidateNode: request.core.resolveSpatialCandidateNode,
      writeSelectionReplace: request.core.commands.writeSelectionReplace,
      writeSelectionClear: request.core.commands.writeSelectionClear,
      commitMoveSelection: selectionActions.commitMoveSelection,
      writeDrawStroke: request.core.draw.writeDrawStroke,
      writeDrawLineFromWorldSegment:
          request.core.draw.writeDrawLineFromWorldSegment,
      writeEraseNodes: request.core.draw.writeEraseNodes,
    ),
  );
}

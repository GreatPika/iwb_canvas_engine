import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import '../../controller/scene_store_controller.dart';
import '../../core/action_events.dart';
import '../../core/interaction_types.dart';
import '../scene_controller_interaction.dart';
import 'interactive_draw_style.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_runtime.dart';
import 'interactive_runtime_callbacks.dart';
import 'interactive_selection_actions.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required MoveCommitDeltaResolver? moveCommitDeltaResolver,
    required this.storeController,
    required this.notifyScheduler,
    required this.events,
    required this.mutationBoundary,
    required this.selectionActions,
    required this.runtime,
  }) : _moveCommitDeltaResolver = moveCommitDeltaResolver;

  final SceneStoreController storeController;
  final MoveCommitDeltaResolver? _moveCommitDeltaResolver;
  final InteractiveNotifyScheduler notifyScheduler;
  final InteractiveEventDispatcher events;
  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;
  final Set<PointerSessionToken> _pointerSessionTokens =
      <PointerSessionToken>{};

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

  void interruptForExternalMutation() {
    runtime.interruptForExternalMutation();
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
    _pointerSessionTokens.clear();
    notifyScheduler.dispose();
    runtime.dispose();
    events.dispose();
  }

  void _handleStoreControllerChanged() {
    scheduleNotify();
  }
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.notifyListeners,
    required this.storeController,
    required this.mutationAccess,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readMode,
    required this.readDragStartSlop,
    required this.readDrawStyle,
    required this.requireFiniteOffset,
    required this.moveCommitDeltaResolver,
  });

  final void Function() notifyListeners;
  final SceneStoreController storeController;
  final SceneControllerCommittedMutationAccess mutationAccess;
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
  final mutationBoundary = _createMutationBoundary(request, () => wiredRuntime);
  final selectionActions = _createSelectionActions(mutationBoundary);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    notifyScheduler: notifyScheduler,
    events: events,
    mutationBoundary: mutationBoundary,
  );
  wiredRuntime = SceneControllerInteractionRuntime._(
    moveCommitDeltaResolver: request.moveCommitDeltaResolver,
    storeController: request.storeController,
    notifyScheduler: notifyScheduler,
    events: events,
    mutationBoundary: mutationBoundary,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
  request.storeController.addListener(
    wiredRuntime._handleStoreControllerChanged,
  );
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
  InteractiveDrawStyle? get pendingLineStyle => runtime.pendingLineStyle;
  bool get hasActiveGesture => runtime.hasActiveGesture;
  bool get isActiveDrawGesture => runtime.isActiveDrawGesture;
  bool get hasActiveStrokePoints => runtime.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      runtime.activeStrokePreviewPoints;
  InteractiveDrawStyle? get activeDrawStyle => runtime.activeDrawStyle;
  Offset? get activeLinePreviewStart => runtime.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => runtime.activeLinePreviewEnd;
  int get activeEraserPointsLength => runtime.activeEraserPointsLength;
  int get eraserSpatialQueryCount => runtime.debugEraserSpatialQueryCount;
  int get eraserPreciseSegmentCheckCount =>
      runtime.debugEraserPreciseSegmentChecks;

  void interruptForInteractionConfigChange() {
    runtime.interruptForInteractionConfigChange();
  }

  void clearPointerNormalizationState() {
    runtime.clearPointerNormalizationState();
  }
}

extension SceneControllerInteractionRuntimeMutationApi
    on SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() {
    final token = PointerSessionToken();
    _pointerSessionTokens.add(token);
    return token;
  }

  void detachPointerSession(PointerSessionToken token) {
    if (!_pointerSessionTokens.contains(token)) {
      return;
    }
    runtime.detachPointerSession(token);
  }

  void releasePointerSessionToken(PointerSessionToken token) {
    _pointerSessionTokens.remove(token);
  }

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

  void handlePublicPointer(CanvasPointerInput input) {
    runtime.handlePublicPointer(input);
  }

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {
    runtime.handlePublicDoubleTap(position: position, timestampMs: timestampMs);
  }

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
  }

  void _ensureKnownPointerSessionToken(PointerSessionToken token) {
    if (!_pointerSessionTokens.contains(token)) {
      throw StateError('Unknown pointer session token.');
    }
  }
}

SceneControllerMutationBoundary _createMutationBoundary(
  SceneControllerInteractionRuntimeRequest request,
  SceneControllerInteractionRuntime Function() readRuntime,
) {
  return SceneControllerMutationBoundary(
    mutationAccess: request.mutationAccess,
    readSnapshot: request.readSnapshot,
    callbacks: SceneControllerMutationBoundaryCallbacks(
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
      clearPointerNormalizationState: () {
        readRuntime().runtime.clearPointerNormalizationState();
      },
    ),
  );
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerMutationBoundary mutationBoundary,
) {
  return InteractiveSelectionActions(mutations: mutationBoundary);
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required InteractiveNotifyScheduler notifyScheduler,
  required InteractiveEventDispatcher events,
  required SceneControllerMutationBoundary mutationBoundary,
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
      querySpatialCandidates: request.storeController.querySpatialCandidates,
      resolveSpatialCandidateNode:
          request.storeController.resolveSpatialCandidateNode,
      writeSelectionReplace: mutationBoundary.setSelection,
      writeSelectionClear: mutationBoundary.clearSelection,
      commitMoveSelection: mutationBoundary.commitMoveSelection,
      commitDrawStroke: mutationBoundary.commitDrawStroke,
      commitDrawLineFromWorldSegment:
          mutationBoundary.commitDrawLineFromWorldSegment,
      commitEraseNodes: mutationBoundary.commitEraseNodes,
    ),
  );
}

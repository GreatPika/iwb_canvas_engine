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
import 'interactive_move_preview_read.dart';
import 'interactive_runtime.dart';
import 'interactive_runtime_callbacks.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';
import 'scene_controller_pointer_session.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required MoveCommitDeltaResolver? moveCommitDeltaResolver,
    required this.publicNotifyScheduler,
    required this.sceneNotifyScheduler,
    required this.overlayNotifyScheduler,
    required this.events,
    required this.mutationBoundary,
    required this.runtime,
  }) : _moveCommitDeltaResolver = moveCommitDeltaResolver;

  final MoveCommitDeltaResolver? _moveCommitDeltaResolver;
  final InteractiveNotifyScheduler publicNotifyScheduler;
  final InteractiveNotifyScheduler sceneNotifyScheduler;
  final InteractiveNotifyScheduler overlayNotifyScheduler;
  final InteractiveEventDispatcher events;
  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveRuntime runtime;
  final Set<PointerSessionToken> _pointerSessionTokens =
      <PointerSessionToken>{};
  final Map<PointerSessionToken, SceneControllerPointerSession>
  _pointerSessionsByToken =
      <PointerSessionToken, SceneControllerPointerSession>{};

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
    _resetLivePointerSessions();
  }

  void scheduleNotify() {
    publicNotifyScheduler.schedule();
  }

  void scheduleSceneNotify() {
    sceneNotifyScheduler.schedule();
  }

  void scheduleOverlayNotify() {
    overlayNotifyScheduler.schedule();
  }

  Offset runMoveCommitDeltaResolver(MoveCommitDeltaRequest request) {
    final resolver = _moveCommitDeltaResolver;
    if (resolver == null) {
      return request.proposedDelta;
    }
    if (_moveCommitResolverActive) {
      throw StateError(
        'Reentrant moveCommitDeltaResolver(...) is not allowed.',
      );
    }

    _moveCommitResolverActive = true;
    try {
      return resolver(request);
    } finally {
      _moveCommitResolverActive = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    for (final session in _pointerSessionsByToken.values.toList(
      growable: false,
    )) {
      session.deactivateForOwnerDispose();
    }
    _pointerSessionsByToken.clear();
    _pointerSessionTokens.clear();
    publicNotifyScheduler.dispose();
    sceneNotifyScheduler.dispose();
    overlayNotifyScheduler.dispose();
    runtime.dispose();
    events.dispose();
  }
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.notifyPublicListeners,
    required this.notifySceneListeners,
    required this.notifyOverlayListeners,
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

  final void Function() notifyPublicListeners;
  final void Function() notifySceneListeners;
  final void Function() notifyOverlayListeners;
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
  final publicNotifyScheduler = InteractiveNotifyScheduler(
    notifyListeners: request.notifyPublicListeners,
  );
  final notifyScheduler = InteractiveNotifyScheduler(
    notifyListeners: request.notifySceneListeners,
  );
  final overlayNotifyScheduler = InteractiveNotifyScheduler(
    notifyListeners: request.notifyOverlayListeners,
  );
  final events = InteractiveEventDispatcher();
  late final SceneControllerInteractionRuntime wiredRuntime;
  final mutationBoundary = _createMutationBoundary(request, () => wiredRuntime);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    publicNotifyScheduler: publicNotifyScheduler,
    sceneNotifyScheduler: notifyScheduler,
    overlayNotifyScheduler: overlayNotifyScheduler,
    events: events,
    mutationBoundary: mutationBoundary,
  );
  wiredRuntime = SceneControllerInteractionRuntime._(
    moveCommitDeltaResolver: request.moveCommitDeltaResolver,
    publicNotifyScheduler: publicNotifyScheduler,
    sceneNotifyScheduler: notifyScheduler,
    overlayNotifyScheduler: overlayNotifyScheduler,
    events: events,
    mutationBoundary: mutationBoundary,
    runtime: interactiveRuntime,
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
  int get eraserProjectedPointCount => runtime.debugEraserProjectedPointCount;
  InteractiveMovePreviewRead get movePreviewRead => runtime.movePreviewRead;

  void interruptForInteractionConfigChange() {
    runtime.interruptForInteractionConfigChange();
    _resetLivePointerSessions();
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

  void registerPointerSession(
    SceneControllerPointerSession session, {
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    _pointerSessionsByToken[token] = session;
  }

  void detachPointerSession(PointerSessionToken token) {
    if (!_pointerSessionTokens.contains(token)) {
      return;
    }
    runtime.detachPointerSession(token);
  }

  void releasePointerSessionToken(PointerSessionToken token) {
    _pointerSessionsByToken.remove(token);
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
    mutationBoundary.clearScene(timestampMs: timestampMs);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    mutationBoundary.rotateSelection(
      clockwise: clockwise,
      timestampMs: timestampMs,
    );
  }

  void flipSelectionVertical({int? timestampMs}) {
    mutationBoundary.flipSelectionVertical(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    mutationBoundary.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    mutationBoundary.deleteSelection(timestampMs: timestampMs);
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
    if (_isDisposed) {
      return;
    }
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    if (_isDisposed) {
      return;
    }
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

  void _resetLivePointerSessions() {
    for (final session in _pointerSessionsByToken.values.toList(
      growable: false,
    )) {
      session.resetForInteractiveEpoch();
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
      resolveMoveCommitDelta: (request) =>
          readRuntime().runMoveCommitDeltaResolver(request),
      requireFiniteOffset: request.requireFiniteOffset,
      clearPointerNormalizationState: () {
        readRuntime().runtime.clearPointerNormalizationState();
      },
      schedulePublicNotify: () {
        readRuntime().scheduleNotify();
      },
      scheduleSceneRepaint: () {
        readRuntime().scheduleSceneNotify();
      },
      scheduleOverlayRepaint: () {
        readRuntime().scheduleOverlayNotify();
      },
    ),
  );
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required InteractiveNotifyScheduler publicNotifyScheduler,
  required InteractiveNotifyScheduler sceneNotifyScheduler,
  required InteractiveNotifyScheduler overlayNotifyScheduler,
  required InteractiveEventDispatcher events,
  required SceneControllerMutationBoundary mutationBoundary,
}) {
  return InteractiveRuntime(
    events: events,
    callbacks: InteractiveRuntimeCallbacks(
      schedulePublicNotify: publicNotifyScheduler.schedule,
      scheduleSceneNotify: sceneNotifyScheduler.schedule,
      scheduleOverlayNotify: overlayNotifyScheduler.schedule,
      readSnapshot: request.readSnapshot,
      readSelectedNodeIds: request.readSelectedNodeIds,
      readMode: request.readMode,
      readDragStartSlop: request.readDragStartSlop,
      readDrawStyle: request.readDrawStyle,
      queryHitTestCandidates: request.storeController.queryHitTestCandidates,
      resolveSpatialCandidateSnapshot:
          request.storeController.resolveSpatialCandidateSnapshot,
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

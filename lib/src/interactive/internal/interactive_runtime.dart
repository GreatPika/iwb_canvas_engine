import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_draw_style.dart';
import 'interactive_double_tap_router.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_gesture_machine.dart';
import 'interactive_gesture_router.dart';
import 'interactive_move_callbacks.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_runtime_callbacks.dart';
import 'pointer_session_token.dart';

class InteractiveRuntime {
  InteractiveRuntime({required this.callbacks, required this.events}) {
    _moveSession = InteractiveMoveSession(
      callbacks: InteractiveMoveSessionCallbacks(
        onStateChanged: callbacks.scheduleNotify,
        readSnapshot: callbacks.readSnapshot,
        readSelectedNodeIds: callbacks.readSelectedNodeIds,
        querySpatialCandidates: callbacks.querySpatialCandidates,
        resolveSpatialCandidateNode: callbacks.resolveSpatialCandidateNode,
        writeSelectionReplace: callbacks.writeSelectionReplace,
        writeSelectionClear: callbacks.writeSelectionClear,
        commitMoveSelection: callbacks.commitMoveSelection,
        emitAction: events.emitAction,
      ),
    );
    _drawCoordinator = InteractiveDrawCoordinator(
      callbacks: InteractiveDrawCoordinatorCallbacks(
        onStateChanged: callbacks.scheduleNotify,
        emitAction: events.emitAction,
        commitDrawStroke: callbacks.commitDrawStroke,
        commitDrawLineFromWorldSegment:
            callbacks.commitDrawLineFromWorldSegment,
        querySpatialCandidates: callbacks.querySpatialCandidates,
        resolveSpatialCandidateNode: callbacks.resolveSpatialCandidateNode,
        commitEraseNodes: callbacks.commitEraseNodes,
      ),
    );
  }

  final InteractiveRuntimeCallbacks callbacks;
  final InteractiveEventDispatcher events;
  late final InteractiveMoveSession _moveSession;
  late final InteractiveDrawCoordinator _drawCoordinator;
  final InteractivePointerNormalizer _pointerNormalizer =
      InteractivePointerNormalizer();
  late final InteractiveGestureRouter _gestureRouter = InteractiveGestureRouter(
    callbacks: callbacks,
    moveSession: _moveSession,
    drawCoordinator: _drawCoordinator,
  );
  late final InteractiveDoubleTapRouter _doubleTapRouter =
      InteractiveDoubleTapRouter(
        callbacks: InteractiveDoubleTapRouterCallbacks(
          readMode: callbacks.readMode,
          readSnapshot: callbacks.readSnapshot,
          hitTestTopNode: _moveSession.hitTestTopNode,
          resolveTimestampMs: events.resolveTimestampMs,
          emitEditTextRequested: events.emitEditTextRequested,
        ),
      );
  bool _handlingPointer = false;
  bool _isDisposed = false;
  VoidCallback? _debugBeforePointerDispatchHook;

  Rect? get selectionRect => _moveSession.selectionRect;
  Offset? get pendingLineStart => _drawCoordinator.pendingLineStart;
  int? get pendingLineTimestampMs => _drawCoordinator.pendingLineTimestampMs;
  bool get hasPendingLineStart => _drawCoordinator.hasPendingLineStart;
  InteractiveDrawStyle? get pendingLineStyle =>
      _drawCoordinator.pendingLineStyle;
  bool get hasActiveGesture => _gestureRouter.hasActiveGesture;
  bool get isActiveDrawGesture => _gestureRouter.isActiveDrawGesture;
  bool get hasActiveStrokePoints => _drawCoordinator.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      _drawCoordinator.activeStrokePreviewPoints;
  Offset? get activeLinePreviewStart => _drawCoordinator.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _drawCoordinator.activeLinePreviewEnd;
  InteractiveDrawStyle? get activeDrawStyle => _drawCoordinator.activeDrawStyle;

  InteractiveMoveSession get debugMoveSession => _moveSession;

  void setBeforePointerDispatchHook(VoidCallback? hook) {
    _debugBeforePointerDispatchHook = hook;
  }

  int get activeEraserPointsLength => _drawCoordinator.activeEraserPointsLength;
  int get debugEraserSpatialQueryCount =>
      _drawCoordinator.debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks =>
      _drawCoordinator.debugEraserPreciseSegmentChecks;

  void handlePublicPointer(CanvasPointerInput input) {
    _dispatchPointer(input);
  }

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    _dispatchPointerFromSession(input, token);
  }

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {
    _dispatchDoubleTap(position: position, timestampMs: timestampMs);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    _dispatchDoubleTapFromSession(position, timestampMs, token);
  }

  void _dispatchPointerFromSession(
    CanvasPointerInput input,
    PointerSessionToken token,
  ) {
    _dispatchPointer(input, sessionToken: token);
  }

  void _dispatchDoubleTapFromSession(
    Offset position,
    int? timestampMs,
    PointerSessionToken _,
  ) {
    _dispatchDoubleTap(position: position, timestampMs: timestampMs);
  }

  void _dispatchPointer(
    CanvasPointerInput input, {
    PointerSessionToken? sessionToken,
  }) {
    if (_handlingPointer) {
      throw StateError('Reentrant handlePointer(...) is not allowed.');
    }
    final resolvedSample = _pointerNormalizer.normalize(
      input,
      resolveTimestampMs: events.resolveTimestampMs,
      sessionToken: sessionToken,
    );
    if (resolvedSample == null) {
      return;
    }

    _handlingPointer = true;
    try {
      assert(() {
        _debugBeforePointerDispatchHook?.call();
        return true;
      }());
      _gestureRouter.dispatchPointerSample(
        resolvedSample,
        sessionToken: sessionToken,
      );
    } finally {
      _pointerNormalizer.release(resolvedSample, sessionToken: sessionToken);
      _handlingPointer = false;
    }
  }

  void _dispatchDoubleTap({required Offset position, int? timestampMs}) {
    _doubleTapRouter.handleDoubleTap(
      position: position,
      timestampMs: timestampMs,
    );
  }

  void interruptForInteractionConfigChange() {
    _interruptInteractiveState();
  }

  void interruptForExternalMutation() {
    _interruptInteractiveState();
  }

  void detachPointerSession(PointerSessionToken token) {
    _pointerNormalizer.detachSession(token);
    _detachInteractiveStateForSession(token);
  }

  void clearPointerNormalizationState() {
    _pointerNormalizer.clear();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _gestureRouter.interruptActiveGesture();
    _pointerNormalizer.clear();
    _moveSession.dispose();
    _drawCoordinator.dispose();
  }

  void _interruptInteractiveState() {
    final family = _gestureRouter.interruptActiveGesture();
    if (family == InteractiveGestureFamily.move) {
      _moveSession.interruptGesture();
    } else {
      _moveSession.setSelectionRect(null);
    }
    _drawCoordinator.resetOwnedState();
  }

  void _detachInteractiveStateForSession(PointerSessionToken token) {
    final didClearPendingLine = _drawCoordinator.detachPointerSession(token);
    final didChange =
        _detachOwnedStateForFamily(
          _gestureRouter.detachPointerSession(token),
        ) ||
        didClearPendingLine;
    if (didChange) {
      callbacks.scheduleNotify();
    }
  }

  bool _detachOwnedStateForFamily(InteractiveGestureFamily? family) {
    switch (family) {
      case InteractiveGestureFamily.move:
        return _moveSession.detachOwningSession();
      case InteractiveGestureFamily.draw:
        final didChange =
            _drawCoordinator.hasActiveStrokePoints ||
            _drawCoordinator.activeLinePreviewStart != null ||
            _drawCoordinator.activeLinePreviewEnd != null ||
            _drawCoordinator.activeEraserPointsLength > 0;
        _drawCoordinator.resetGestureState();
        return didChange;
      case null:
        return false;
    }
  }
}

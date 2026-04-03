import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_double_tap_router.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_gesture_router.dart';
import 'interactive_move_callbacks.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_runtime_callbacks.dart';

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
  bool get hasActiveGesture => _gestureRouter.hasActiveGesture;
  bool get isActiveDrawGesture => _gestureRouter.isActiveDrawGesture;
  bool get hasActiveStrokePoints => _drawCoordinator.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      _drawCoordinator.activeStrokePreviewPoints;
  Offset? get activeLinePreviewStart => _drawCoordinator.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _drawCoordinator.activeLinePreviewEnd;

  InteractiveMoveSession get debugMoveSession => _moveSession;

  void setBeforePointerDispatchHook(VoidCallback? hook) {
    _debugBeforePointerDispatchHook = hook;
  }

  int get activeEraserPointsLength => _drawCoordinator.activeEraserPointsLength;
  int get debugEraserSpatialQueryCount =>
      _drawCoordinator.debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks =>
      _drawCoordinator.debugEraserPreciseSegmentChecks;

  void handlePointer(CanvasPointerInput input) {
    if (_handlingPointer) {
      throw StateError('Reentrant handlePointer(...) is not allowed.');
    }
    final resolvedSample = _pointerNormalizer.normalize(
      input,
      resolveTimestampMs: events.resolveTimestampMs,
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
      _gestureRouter.dispatchPointerSample(resolvedSample);
    } finally {
      _pointerNormalizer.release(resolvedSample);
      _handlingPointer = false;
    }
  }

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    _doubleTapRouter.handleDoubleTap(
      position: position,
      timestampMs: timestampMs,
    );
  }

  void resetInteractiveState() {
    if (_gestureRouter.resetGestureWasMove()) {
      _moveSession.resetGestureState();
    }
    _moveSession.setSelectionRect(null);
    _drawCoordinator.resetOwnedState();
  }

  void clearPointerNormalizationState() {
    _pointerNormalizer.clear();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _gestureRouter.resetGestureWasMove();
    _pointerNormalizer.clear();
    _moveSession.dispose();
    _drawCoordinator.dispose();
  }
}

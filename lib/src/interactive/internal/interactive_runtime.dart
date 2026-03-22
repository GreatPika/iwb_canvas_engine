import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/geometry.dart';
import '../../core/interaction_types.dart';
import '../../core/nodes.dart' show SceneNode, TextNode;
import '../../core/pointer_input.dart';
import '../../core/scene_spatial_index.dart';
import '../../contract/canvas_pointer_input.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_draw_line_engine.dart' show InteractiveDrawStyle;
import 'interactive_event_dispatcher.dart';
import 'interactive_gesture_machine.dart';
import 'interactive_move_session.dart';

class InteractiveRuntimeCallbacks {
  const InteractiveRuntimeCallbacks({
    required this.scheduleNotify,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readMode,
    required this.readDragStartSlop,
    required this.readDrawStyle,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.writeDrawStroke,
    required this.writeDrawLineFromWorldSegment,
    required this.writeEraseNodes,
  });

  final VoidCallback scheduleNotify;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final CanvasMode Function() readMode;
  final double Function() readDragStartSlop;
  final InteractiveDrawStyle Function() readDrawStyle;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final void Function(Iterable<NodeId> nodeIds) writeSelectionReplace;
  final void Function() writeSelectionClear;
  final MoveCommitSelectionResult Function(Offset proposedDelta)
  commitMoveSelection;
  final NodeId Function({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  })
  writeDrawStroke;
  final NodeId Function({required Offset start, required Offset end})
  writeDrawLineFromWorldSegment;
  final int Function(Iterable<NodeId> ids) writeEraseNodes;
}

class InteractiveRuntime {
  InteractiveRuntime({required this.callbacks}) {
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
        emitAction: _events.emitAction,
      ),
    );
    _drawCoordinator = InteractiveDrawCoordinator(
      callbacks: InteractiveDrawCoordinatorCallbacks(
        onStateChanged: callbacks.scheduleNotify,
        emitAction: _events.emitAction,
        writeDrawStroke: callbacks.writeDrawStroke,
        writeDrawLineFromWorldSegment: callbacks.writeDrawLineFromWorldSegment,
        querySpatialCandidates: callbacks.querySpatialCandidates,
        resolveSpatialCandidateNode: callbacks.resolveSpatialCandidateNode,
        writeEraseNodes: callbacks.writeEraseNodes,
      ),
    );
  }

  final InteractiveRuntimeCallbacks callbacks;
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  final InteractiveGestureMachine _gestureMachine = InteractiveGestureMachine();
  late final InteractiveMoveSession _moveSession;
  late final InteractiveDrawCoordinator _drawCoordinator;

  int _timestampCursorMs = -1;
  final Map<int, Offset> _lastFinitePointerPositionById = <int, Offset>{};
  bool _handlingPointer = false;
  bool _isDisposed = false;
  VoidCallback? _debugBeforePointerDispatchHook;

  Stream<ActionCommitted> get actions => _events.actions;
  Stream<EditTextRequested> get editTextRequests => _events.editTextRequests;

  Rect? get selectionRect => _moveSession.selectionRect;
  Offset? get pendingLineStart => _drawCoordinator.pendingLineStart;
  int? get pendingLineTimestampMs => _drawCoordinator.pendingLineTimestampMs;
  bool get hasPendingLineStart => _drawCoordinator.hasPendingLineStart;
  bool get hasActiveGesture => _gestureMachine.hasActiveGesture;
  bool get isActiveDrawGesture => _gestureMachine.isActiveDrawGesture;
  bool get hasActiveStrokePoints => _drawCoordinator.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      _drawCoordinator.activeStrokePreviewPoints;
  Offset? get activeLinePreviewStart => _drawCoordinator.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _drawCoordinator.activeLinePreviewEnd;

  Offset movePreviewDeltaForNode(NodeId nodeId) {
    return _moveSession.movePreviewDeltaForNode(nodeId);
  }

  void setBeforePointerDispatchHook(VoidCallback? hook) {
    _debugBeforePointerDispatchHook = hook;
  }

  int get activeEraserPointsLength => _drawCoordinator.activeEraserPointsLength;
  int get debugEraserSpatialQueryCount =>
      _drawCoordinator.debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks =>
      _drawCoordinator.debugEraserPreciseSegmentChecks;

  void emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) {
    _events.emitAction(type, nodeIds, timestampMs, payload: payload);
  }

  int resolveTimestampMs(int? hintTimestampMs) {
    return _resolveTimestampMs(hintTimestampMs);
  }

  void handlePointer(CanvasPointerInput input) {
    if (_handlingPointer) {
      throw StateError('Reentrant handlePointer(...) is not allowed.');
    }
    final resolvedSample = _normalizePointerInput(input);
    if (resolvedSample == null) {
      return;
    }

    _handlingPointer = true;
    try {
      assert(() {
        _debugBeforePointerDispatchHook?.call();
        return true;
      }());
      _dispatchPointerSample(resolvedSample);
    } finally {
      _releaseNormalizedPointerState(resolvedSample);
      _handlingPointer = false;
    }
  }

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    if (!_isFiniteOffset(position) || callbacks.readMode() != CanvasMode.move) {
      return;
    }

    final scenePoint = _toScenePoint(position);
    final hit = _moveSession.hitTestTopNode(scenePoint);
    if (hit == null || hit is! TextNode) {
      return;
    }

    _events.emitEditTextRequested(
      EditTextRequested(
        nodeId: hit.id,
        timestampMs: _resolveTimestampMs(timestampMs),
        position: position,
      ),
    );
  }

  void resetInteractiveState() {
    final family = _gestureMachine.reset();
    if (family == InteractiveGestureFamily.move) {
      _moveSession.resetGestureState();
    }
    _moveSession.setSelectionRect(null);
    _drawCoordinator.resetOwnedState();
  }

  void clearPointerNormalizationState() {
    _lastFinitePointerPositionById.clear();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _gestureMachine.reset();
    _lastFinitePointerPositionById.clear();
    _moveSession.dispose();
    _drawCoordinator.dispose();
    _events.dispose();
  }

  void _dispatchPointerSample(PointerSample sample) {
    switch (sample.phase) {
      case PointerPhase.down:
        _handlePointerDown(sample);
        break;
      case PointerPhase.move:
      case PointerPhase.up:
      case PointerPhase.cancel:
        _handleOwnedPointerSample(sample);
        break;
    }
  }

  void _handlePointerDown(PointerSample sample) {
    final family = _currentGestureFamily;
    if (!_gestureMachine.tryBegin(
      pointerId: sample.pointerId,
      family: family,
      dragStartSlop: callbacks.readDragStartSlop(),
    )) {
      return;
    }
    final activeDragStartSlop = _requireActiveDragStartSlop();

    try {
      _dispatchPointerToFamily(
        sample,
        family: family,
        dragStartSlop: activeDragStartSlop,
      );
    } catch (_) {
      _gestureMachine.reset();
      rethrow;
    }
  }

  void _handleOwnedPointerSample(PointerSample sample) {
    if (!_gestureMachine.ownsPointer(sample.pointerId)) {
      return;
    }
    final family = _gestureMachine.activeFamily;
    if (family == null) {
      return;
    }
    final activeDragStartSlop = _requireActiveDragStartSlop();
    try {
      _dispatchPointerToFamily(
        sample,
        family: family,
        dragStartSlop: activeDragStartSlop,
      );
    } finally {
      if (_isTerminalPointerPhase(sample.phase)) {
        _gestureMachine.reset();
      }
    }
  }

  void _dispatchPointerToFamily(
    PointerSample sample, {
    required InteractiveGestureFamily family,
    required double dragStartSlop,
  }) {
    final scenePoint = _toScenePoint(sample.position);
    switch (family) {
      case InteractiveGestureFamily.move:
        _moveSession.handlePointer(
          sample,
          scenePoint,
          dragStartSlop: dragStartSlop,
        );
        break;
      case InteractiveGestureFamily.draw:
        _drawCoordinator.handlePointer(
          sample,
          scenePoint,
          style: callbacks.readDrawStyle(),
          dragStartSlop: dragStartSlop,
        );
        break;
    }
  }

  InteractiveGestureFamily get _currentGestureFamily {
    return callbacks.readMode() == CanvasMode.move
        ? InteractiveGestureFamily.move
        : InteractiveGestureFamily.draw;
  }

  Offset _toScenePoint(Offset viewPoint) {
    return toScene(viewPoint, callbacks.readSnapshot().camera.offset);
  }

  PointerSample? _normalizePointerInput(CanvasPointerInput input) {
    final phase = _toInternalPointerPhase(input.phase);
    final hasFinitePosition = _isFiniteOffset(input.position);
    if (!hasFinitePosition &&
        (phase == PointerPhase.down || phase == PointerPhase.move)) {
      return null;
    }
    final resolvedPosition = hasFinitePosition
        ? input.position
        : _lastFinitePointerPositionById[input.pointerId];
    if (resolvedPosition == null) {
      return null;
    }
    if (hasFinitePosition) {
      _lastFinitePointerPositionById[input.pointerId] = input.position;
    }

    return PointerSample(
      pointerId: input.pointerId,
      position: resolvedPosition,
      timestampMs: _resolveTimestampMs(input.timestampMs),
      phase: phase,
      kind: input.kind,
    );
  }

  void _releaseNormalizedPointerState(PointerSample sample) {
    if (!_isTerminalPointerPhase(sample.phase)) {
      return;
    }
    _lastFinitePointerPositionById.remove(sample.pointerId);
  }

  PointerPhase _toInternalPointerPhase(CanvasPointerPhase phase) {
    switch (phase) {
      case CanvasPointerPhase.down:
        return PointerPhase.down;
      case CanvasPointerPhase.move:
        return PointerPhase.move;
      case CanvasPointerPhase.up:
        return PointerPhase.up;
      case CanvasPointerPhase.cancel:
        return PointerPhase.cancel;
    }
  }

  int _resolveTimestampMs(int? hintTimestampMs) {
    final next = _timestampCursorMs + 1;
    final resolved = hintTimestampMs == null || hintTimestampMs < next
        ? next
        : hintTimestampMs;
    _timestampCursorMs = resolved;
    return resolved;
  }

  static bool _isFiniteOffset(Offset value) {
    return value.dx.isFinite && value.dy.isFinite;
  }

  static bool _isTerminalPointerPhase(PointerPhase phase) {
    return phase == PointerPhase.up || phase == PointerPhase.cancel;
  }

  double _requireActiveDragStartSlop() {
    final activeDragStartSlop = _gestureMachine.activeDragStartSlop;
    if (activeDragStartSlop != null) {
      return activeDragStartSlop;
    }
    throw StateError(
      'Interactive gesture machine lost dragStartSlop during active dispatch.',
    );
  }
}

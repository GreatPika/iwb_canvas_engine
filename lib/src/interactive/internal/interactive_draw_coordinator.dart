import 'dart:ui';

import '../../core/interaction_types.dart';
import '../../core/pointer_input.dart';
import 'interactive_draw_coordinator_callbacks.dart';
import 'interactive_draw_eraser_engine.dart';
import 'interactive_draw_gesture_session.dart';
import 'interactive_draw_line_engine.dart';
import 'interactive_draw_stroke_engine.dart';
import 'interactive_draw_style.dart';
import 'interactive_draw_terminal_router.dart';

export 'interactive_draw_coordinator_callbacks.dart'
    show InteractiveDrawCoordinatorCallbacks;

class InteractiveDrawCoordinator {
  InteractiveDrawCoordinator({required this.callbacks}) {
    _strokeEngine = InteractiveDrawStrokeEngine(
      callbacks: InteractiveDrawStrokeEngineCallbacks(
        onStateChanged: callbacks.onStateChanged,
        emitAction: callbacks.emitAction,
        writeDrawStroke: callbacks.writeDrawStroke,
      ),
    );
    _lineEngine = InteractiveDrawLineEngine(
      callbacks: InteractiveDrawLineEngineCallbacks(
        onStateChanged: callbacks.onStateChanged,
        emitAction: callbacks.emitAction,
        writeDrawLineFromWorldSegment: callbacks.writeDrawLineFromWorldSegment,
      ),
    );
    _eraserEngine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onStateChanged: callbacks.onStateChanged,
        querySpatialCandidates: callbacks.querySpatialCandidates,
        resolveSpatialCandidateNode: callbacks.resolveSpatialCandidateNode,
        writeEraseNodes: callbacks.writeEraseNodes,
      ),
    );
    _terminalRouter = InteractiveDrawTerminalRouter(
      gestureSession: _gestureSession,
      lineEngine: _lineEngine,
      strokeEngine: _strokeEngine,
      eraserEngine: _eraserEngine,
      emitAction: callbacks.emitAction,
    );
  }

  final InteractiveDrawCoordinatorCallbacks callbacks;

  late final InteractiveDrawStrokeEngine _strokeEngine;
  late final InteractiveDrawLineEngine _lineEngine;
  late final InteractiveDrawEraserEngine _eraserEngine;
  final InteractiveDrawGestureSession _gestureSession =
      InteractiveDrawGestureSession();
  late final InteractiveDrawTerminalRouter _terminalRouter;

  Offset? get pendingLineStart => _lineEngine.pendingLineStart;
  int? get pendingLineTimestampMs => _lineEngine.pendingLineTimestampMs;
  bool get hasPendingLineStart => _lineEngine.hasPendingLineStart;

  List<Offset> get activeStrokePreviewPoints =>
      _strokeEngine.activeStrokePreviewPoints;
  bool get hasActiveStrokePoints => _strokeEngine.hasActiveStrokePoints;

  Offset? get activeLinePreviewStart => _lineEngine.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _lineEngine.activeLinePreviewEnd;

  int get activeEraserPointsLength => _eraserEngine.activeEraserPointsLength;
  int get debugEraserSpatialQueryCount =>
      _eraserEngine.debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks =>
      _eraserEngine.debugEraserPreciseSegmentChecks;

  void handlePointer(
    PointerSample sample,
    Offset scenePoint, {
    required InteractiveDrawStyle style,
    required double dragStartSlop,
  }) {
    switch (sample.phase) {
      case PointerPhase.down:
        _handleDown(scenePoint, drawTool: style.drawTool);
        break;
      case PointerPhase.move:
        _handleMove(
          scenePoint,
          drawTool: style.drawTool,
          dragStartSlop: dragStartSlop,
        );
        break;
      case PointerPhase.up:
        _handleUp(
          sample,
          scenePoint,
          style: style,
          dragStartSlop: dragStartSlop,
        );
        break;
      case PointerPhase.cancel:
        cancelGesture();
        break;
    }
  }

  void resetGestureState() {
    _gestureSession.clear();
    _strokeEngine.resetGestureState();
    _eraserEngine.resetGestureState();
    _lineEngine.resetGestureState();
  }

  void resetOwnedState() {
    resetGestureState();
    _lineEngine.resetOwnedState();
  }

  void cancelGesture() {
    resetOwnedState();
    callbacks.onStateChanged();
  }

  void dispose() {
    _lineEngine.dispose();
  }

  void _handleDown(Offset scenePoint, {required DrawTool drawTool}) {
    _gestureSession.start(scenePoint);

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeEngine.handleDown(scenePoint);
        break;
      case DrawTool.line:
        _lineEngine.handleDown();
        break;
      case DrawTool.eraser:
        _eraserEngine.handleDown(scenePoint);
        break;
    }
  }

  void _handleMove(
    Offset scenePoint, {
    required DrawTool drawTool,
    required double dragStartSlop,
  }) {
    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeEngine.handleMove(scenePoint);
        break;
      case DrawTool.line:
        _gestureSession.markMoved(
          _lineEngine.handleMove(
            scenePoint,
            downScene: _gestureSession.downScene,
            moved: _gestureSession.moved,
            dragStartSlop: dragStartSlop,
          ),
        );
        break;
      case DrawTool.eraser:
        _eraserEngine.handleMove(scenePoint);
        break;
    }
  }

  void _handleUp(
    PointerSample sample,
    Offset scenePoint, {
    required InteractiveDrawStyle style,
    required double dragStartSlop,
  }) {
    _terminalRouter.handleUp(
      sample,
      scenePoint,
      style: style,
      dragStartSlop: dragStartSlop,
    );
  }
}

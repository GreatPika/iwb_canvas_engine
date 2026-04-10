import 'dart:ui';

import '../../contract/pointer_input.dart';
import '../../core/interaction_types.dart';
import 'interactive_draw_coordinator_callbacks.dart';
import 'interactive_draw_eraser_engine.dart';
import 'interactive_draw_gesture_session.dart';
import 'interactive_draw_line_engine.dart';
import 'interactive_draw_stroke_engine.dart';
import 'interactive_draw_style.dart';
import 'interactive_draw_terminal_router.dart';
import 'pointer_session_token.dart';

export 'interactive_draw_coordinator_callbacks.dart'
    show InteractiveDrawCoordinatorCallbacks;

class InteractiveDrawCoordinator {
  InteractiveDrawCoordinator({required this.callbacks}) {
    _strokeEngine = InteractiveDrawStrokeEngine(
      callbacks: InteractiveDrawStrokeEngineCallbacks(
        onOverlayStateChanged: callbacks.onOverlayStateChanged,
        emitAction: callbacks.emitAction,
        commitDrawStroke: callbacks.commitDrawStroke,
      ),
    );
    _lineEngine = InteractiveDrawLineEngine(
      callbacks: InteractiveDrawLineEngineCallbacks(
        onOverlayStateChanged: callbacks.onOverlayStateChanged,
        emitAction: callbacks.emitAction,
        commitDrawLineFromWorldSegment:
            callbacks.commitDrawLineFromWorldSegment,
      ),
    );
    _eraserEngine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onOverlayStateChanged: callbacks.onOverlayStateChanged,
        querySpatialCandidates: callbacks.querySpatialCandidates,
        resolveSpatialCandidateNode: callbacks.resolveSpatialCandidateNode,
        commitEraseNodes: callbacks.commitEraseNodes,
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
  InteractiveDrawStyle? get pendingLineStyle => _lineEngine.pendingLineStyle;
  InteractiveDrawStyle? get activeDrawStyle => _gestureSession.capturedStyle;

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
    required PointerSessionToken? sessionToken,
    InteractiveDrawStyle? capturedStyle,
    required double dragStartSlop,
  }) {
    switch (sample.phase) {
      case PointerPhase.down:
        _handleDown(
          scenePoint,
          capturedStyle: capturedStyle,
          sessionToken: sessionToken,
        );
        break;
      case PointerPhase.move:
        _handleMove(scenePoint, dragStartSlop: dragStartSlop);
        break;
      case PointerPhase.up:
        _handleUp(sample, scenePoint, dragStartSlop: dragStartSlop);
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
    final sessionToken = _gestureSession.sessionToken;
    resetGestureState();
    _lineEngine.clearPendingLineOwnedBy(sessionToken);
    callbacks.onOverlayStateChanged();
  }

  void dispose() {
    _lineEngine.dispose();
  }

  bool detachPointerSession(PointerSessionToken token) {
    return _lineEngine.detachPendingLine(token);
  }

  void _handleDown(
    Offset scenePoint, {
    required InteractiveDrawStyle? capturedStyle,
    required PointerSessionToken? sessionToken,
  }) {
    if (capturedStyle == null) {
      return;
    }
    _gestureSession.start(
      scenePoint,
      capturedStyle: capturedStyle,
      sessionToken: sessionToken,
    );

    switch (capturedStyle.drawTool) {
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

  void _handleMove(Offset scenePoint, {required double dragStartSlop}) {
    final capturedStyle = _gestureSession.capturedStyle;
    if (capturedStyle == null) {
      return;
    }
    switch (capturedStyle.drawTool) {
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
            sessionToken: _gestureSession.sessionToken,
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
    required double dragStartSlop,
  }) {
    _terminalRouter.handleUp(sample, scenePoint, dragStartSlop: dragStartSlop);
  }
}

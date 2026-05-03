import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/core/action_events.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/core/node_geometry.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_eraser_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_gesture_session.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_line_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_stroke_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_style.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_terminal_router.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/pointer_session_token.dart';

final _terminalFailure = StateError('terminal failed');

const InteractiveDrawStyle _penStyle = (
  drawTool: DrawTool.pen,
  drawColor: Color(0xFF111111),
  penThickness: 4,
  highlighterThickness: 12,
  lineThickness: 3,
  eraserThickness: 18,
  highlighterOpacity: 0.5,
);

const InteractiveDrawStyle _lineStyle = (
  drawTool: DrawTool.line,
  drawColor: Color(0xFF222222),
  penThickness: 4,
  highlighterThickness: 12,
  lineThickness: 3,
  eraserThickness: 18,
  highlighterOpacity: 0.5,
);

const InteractiveDrawStyle _eraserStyle = (
  drawTool: DrawTool.eraser,
  drawColor: Color(0xFF333333),
  penThickness: 4,
  highlighterThickness: 12,
  lineThickness: 3,
  eraserThickness: 30,
  highlighterOpacity: 0.5,
);

void _ignoreEmitAction(
  ActionType type,
  List<NodeId> nodeIds,
  int timestampMs, {
  Map<String, Object?>? payload,
}) {}

PointerSample _upSample({int timestampMs = 2}) {
  return PointerSample(
    pointerId: 1,
    position: Offset.zero,
    timestampMs: timestampMs,
    phase: PointerPhase.up,
    kind: PointerDeviceKind.touch,
  );
}

InteractiveDrawStrokeEngine _throwingStrokeEngine() {
  return InteractiveDrawStrokeEngine(
    callbacks: InteractiveDrawStrokeEngineCallbacks(
      onOverlayStateChanged: () {},
      emitAction: _ignoreEmitAction,
      commitDrawStroke:
          ({
            required points,
            required thickness,
            required color,
            required opacity,
          }) {
            throw _terminalFailure;
          },
    ),
  );
}

InteractiveDrawLineEngine _throwingLineEngine() {
  return InteractiveDrawLineEngine(
    callbacks: InteractiveDrawLineEngineCallbacks(
      onOverlayStateChanged: () {},
      emitAction: _ignoreEmitAction,
      commitDrawLineFromWorldSegment:
          ({
            required start,
            required end,
            required thickness,
            required color,
            required opacity,
          }) {
            throw _terminalFailure;
          },
    ),
  );
}

InteractiveDrawEraserEngine _emptyEraserEngine() {
  return InteractiveDrawEraserEngine(
    callbacks: InteractiveDrawEraserEngineCallbacks(
      onOverlayStateChanged: () {},
      queryHitTestCandidates: (_) => const <SceneHitTestSpatialCandidate>[],
      resolveSpatialCandidateSnapshot: (_) => null,
      commitEraseNodes: (_) => 0,
    ),
  );
}

InteractiveDrawEraserEngine _deletingEraserEngine({
  required void Function(Iterable<NodeId> ids) onCommitEraseNodes,
}) {
  final line = LineNodeSnapshot(
    id: 'line',
    start: const Offset(-20, 0),
    end: const Offset(20, 0),
    thickness: 2,
    color: const Color(0xFF000000),
    transform: Transform2D.translation(const Offset(120, 80)),
  );
  final candidate = SceneHitTestSpatialCandidate(
    nodeId: line.id,
    layerIndex: 0,
    nodeIndex: 0,
    structuralRevision: 0,
    hitTestBoundsWorld: nodeSnapshotBoundsWorld(line),
  );

  return InteractiveDrawEraserEngine(
    callbacks: InteractiveDrawEraserEngineCallbacks(
      onOverlayStateChanged: () {},
      queryHitTestCandidates: (_) => <SceneHitTestSpatialCandidate>[candidate],
      resolveSpatialCandidateSnapshot: (location) =>
          location.layerIndex == candidate.layerIndex &&
              location.nodeIndex == candidate.nodeIndex
          ? line
          : null,
      commitEraseNodes: (ids) {
        onCommitEraseNodes(ids);
        return ids.length;
      },
    ),
  );
}

void main() {
  group('interactive draw terminal cleanup', () {
    test(
      'router clears draw session and line preview when stroke commit throws',
      () {
        // INV:INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE
        final gestureSession = InteractiveDrawGestureSession();
        final lineEngine = _throwingLineEngine();
        final strokeEngine = _throwingStrokeEngine();
        final eraserEngine = _emptyEraserEngine();
        final router = InteractiveDrawTerminalRouter(
          gestureSession: gestureSession,
          lineEngine: lineEngine,
          strokeEngine: strokeEngine,
          eraserEngine: eraserEngine,
          emitAction: _ignoreEmitAction,
        );

        final sessionToken = PointerSessionToken();
        gestureSession.start(
          const Offset(10, 10),
          capturedStyle: _penStyle,
          sessionToken: sessionToken,
        );
        strokeEngine.handleDown(const Offset(10, 10));
        lineEngine.handleMove(
          const Offset(30, 10),
          downScene: const Offset(10, 10),
          moved: false,
          sessionToken: sessionToken,
          dragStartSlop: 1,
        );

        expect(
          () => router.handleUp(
            _upSample(),
            const Offset(40, 10),
            dragStartSlop: 1,
          ),
          throwsA(same(_terminalFailure)),
        );

        expect(gestureSession.capturedStyle, isNull);
        expect(gestureSession.downScene, isNull);
        expect(lineEngine.activeLinePreviewStart, isNull);
        expect(lineEngine.activeLinePreviewEnd, isNull);
      },
    );

    test('router clears draw session when eraser action emission throws', () {
      // INV:INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE
      final gestureSession = InteractiveDrawGestureSession();
      final lineEngine = _throwingLineEngine();
      final strokeEngine = _throwingStrokeEngine();
      final eraserEngine = _deletingEraserEngine(onCommitEraseNodes: (_) {});
      final router = InteractiveDrawTerminalRouter(
        gestureSession: gestureSession,
        lineEngine: lineEngine,
        strokeEngine: strokeEngine,
        eraserEngine: eraserEngine,
        emitAction: (type, nodeIds, timestampMs, {payload}) {
          throw _terminalFailure;
        },
      );

      gestureSession.start(
        const Offset(100, 80),
        capturedStyle: _eraserStyle,
        sessionToken: PointerSessionToken(),
      );
      eraserEngine.handleDown(const Offset(100, 80));

      expect(
        () => router.handleUp(
          _upSample(),
          const Offset(140, 80),
          dragStartSlop: 1,
        ),
        throwsA(same(_terminalFailure)),
      );

      expect(gestureSession.capturedStyle, isNull);
      expect(gestureSession.downScene, isNull);
    });

    test('stroke engine clears its path buffer when commit throws', () {
      // INV:INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE
      final strokeEngine = _throwingStrokeEngine();
      strokeEngine.handleDown(const Offset(10, 10));
      expect(strokeEngine.hasActiveStrokePoints, isTrue);

      expect(
        () =>
            strokeEngine.commitOnUp(2, const Offset(20, 20), style: _penStyle),
        throwsA(same(_terminalFailure)),
      );

      expect(strokeEngine.hasActiveStrokePoints, isFalse);
      expect(strokeEngine.activeStrokePreviewPoints, isEmpty);
    });

    test(
      'dragged line clears same-session pending line when commit throws',
      () {
        // INV:INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE
        final lineEngine = _throwingLineEngine();
        final sessionToken = PointerSessionToken();
        lineEngine.commitOnUp((
          timestampMs: 1,
          scenePoint: const Offset(10, 10),
          downScene: const Offset(10, 10),
          moved: false,
          dragStartSlop: 5,
          capturedStyle: _lineStyle,
          sessionToken: sessionToken,
        ));
        expect(lineEngine.hasPendingLineStart, isTrue);

        expect(
          () => lineEngine.commitOnUp((
            timestampMs: 2,
            scenePoint: const Offset(40, 10),
            downScene: const Offset(20, 10),
            moved: true,
            dragStartSlop: 5,
            capturedStyle: _lineStyle,
            sessionToken: sessionToken,
          )),
          throwsA(same(_terminalFailure)),
        );

        expect(lineEngine.hasPendingLineStart, isFalse);
        expect(lineEngine.pendingLineStart, isNull);
      },
    );

    test('line first tap still installs pending line without committing', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      var committed = false;
      final lineEngine = InteractiveDrawLineEngine(
        callbacks: InteractiveDrawLineEngineCallbacks(
          onOverlayStateChanged: () {},
          emitAction: _ignoreEmitAction,
          commitDrawLineFromWorldSegment:
              ({
                required start,
                required end,
                required thickness,
                required color,
                required opacity,
              }) {
                committed = true;
                return 'line';
              },
        ),
      );

      lineEngine.commitOnUp((
        timestampMs: 1,
        scenePoint: const Offset(10, 10),
        downScene: const Offset(10, 10),
        moved: false,
        dragStartSlop: 5,
        capturedStyle: _lineStyle,
        sessionToken: PointerSessionToken(),
      ));

      expect(committed, isFalse);
      expect(lineEngine.pendingLineStart, const Offset(10, 10));
      expect(lineEngine.pendingLineTimestampMs, 1);
    });

    test('eraser engine clears its path buffer when commit throws', () {
      // INV:INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE
      final eraserEngine = _deletingEraserEngine(
        onCommitEraseNodes: (_) {
          throw _terminalFailure;
        },
      );
      eraserEngine.handleDown(const Offset(100, 80));
      expect(eraserEngine.activeEraserPointsLength, greaterThan(0));

      expect(
        () =>
            eraserEngine.commitOnUp(const Offset(140, 80), eraserThickness: 30),
        throwsA(same(_terminalFailure)),
      );

      expect(eraserEngine.activeEraserPointsLength, 0);
    });
  });
}

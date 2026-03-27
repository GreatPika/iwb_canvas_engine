import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/grid_safety_limits.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_interactive_internal_access.dart';
import 'package:iwb_canvas_engine/src/model/document.dart';

double get minGridCellSize => kMinGridCellSize;
double get maxSceneCoord => sceneCoordMax;
int get interactiveStrokePointsSoftLimit => kInteractiveStrokePointsSoftLimit;
int get interactiveEraserPointsSoftLimit => kInteractiveEraserPointsSoftLimit;

NodeSnapshot nodeById(SceneSnapshot snapshot, NodeId id) {
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (node.id == id) return node;
    }
  }
  throw StateError('Node not found: $id');
}

CanvasPointerInput sampleInput({
  required int pointerId,
  required Offset position,
  required int timestampMs,
  required CanvasPointerPhase phase,
}) {
  return CanvasPointerInput(
    pointerId: pointerId,
    position: position,
    timestampMs: timestampMs,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}

SceneControllerInteractive controllerFromScene(
  Scene scene, {
  PointerInputSettings? pointerSettings,
  double? dragStartSlop,
  bool clearSelectionOnDrawModeEnter = false,
  MoveCommitDeltaResolver? moveCommitDeltaResolver,
  String? textFontFamilyByDefault,
}) {
  return SceneControllerInteractive(
    initialSnapshot: txnSceneToSnapshot(scene),
    pointerSettings: pointerSettings,
    dragStartSlop: dragStartSlop,
    clearSelectionOnDrawModeEnter: clearSelectionOnDrawModeEnter,
    moveCommitDeltaResolver: moveCommitDeltaResolver,
    textFontFamilyByDefault: textFontFamilyByDefault,
  );
}

StrokeNode horizontalStroke({
  required String id,
  required double y,
  required double length,
  required double step,
  required double thickness,
}) {
  final points = <Offset>[];
  for (var x = 0.0; x <= length; x += step) {
    points.add(Offset(x, y));
  }
  if (points.last.dx != length) {
    points.add(Offset(length, y));
  }
  return StrokeNode(
    id: id,
    points: points,
    thickness: thickness,
    color: const Color(0xFF000000),
  );
}

typedef InteractiveMutatingCall =
    void Function(SceneControllerInteractive controller);

class InteractiveControllerStableState {
  const InteractiveControllerStableState({
    required this.snapshot,
    required this.selection,
    required this.mode,
    required this.drawTool,
    required this.drawColor,
    required this.penThickness,
    required this.highlighterThickness,
    required this.lineThickness,
    required this.eraserThickness,
    required this.highlighterOpacity,
    required this.dragStartSlop,
    required this.pointerSettings,
    required this.selectionRect,
    required this.pendingLineStart,
    required this.pendingLineTimestampMs,
    required this.hasPendingLineStart,
  });

  final SceneSnapshot snapshot;
  final Set<NodeId> selection;
  final CanvasMode mode;
  final DrawTool drawTool;
  final Color drawColor;
  final double penThickness;
  final double highlighterThickness;
  final double lineThickness;
  final double eraserThickness;
  final double highlighterOpacity;
  final double dragStartSlop;
  final PointerInputSettings pointerSettings;
  final Rect? selectionRect;
  final Offset? pendingLineStart;
  final int? pendingLineTimestampMs;
  final bool hasPendingLineStart;
}

class DisposeMatrixCase {
  const DisposeMatrixCase({required this.name, required this.call});

  final String name;
  final InteractiveMutatingCall call;
}

InteractiveControllerStableState captureStableState(
  SceneControllerInteractive controller,
) {
  return InteractiveControllerStableState(
    snapshot: controller.snapshot,
    selection: controller.selectedNodeIds,
    mode: controller.mode,
    drawTool: controller.drawTool,
    drawColor: controller.drawColor,
    penThickness: controller.penThickness,
    highlighterThickness: controller.highlighterThickness,
    lineThickness: controller.lineThickness,
    eraserThickness: controller.eraserThickness,
    highlighterOpacity: controller.highlighterOpacity,
    dragStartSlop: controller.dragStartSlop,
    pointerSettings: controller.pointerSettings,
    selectionRect: controller.selectionRect,
    pendingLineStart: controller.pendingLineStart,
    pendingLineTimestampMs: controller.pendingLineTimestampMs,
    hasPendingLineStart: controller.hasPendingLineStart,
  );
}

void expectStableStateUnchanged(
  SceneControllerInteractive controller,
  InteractiveControllerStableState before,
) {
  expect(controller.snapshot, same(before.snapshot));
  expect(controller.selectedNodeIds, before.selection);
  expect(controller.mode, before.mode);
  expect(controller.drawTool, before.drawTool);
  expect(controller.drawColor, before.drawColor);
  expect(controller.penThickness, before.penThickness);
  expect(controller.highlighterThickness, before.highlighterThickness);
  expect(controller.lineThickness, before.lineThickness);
  expect(controller.eraserThickness, before.eraserThickness);
  expect(controller.highlighterOpacity, before.highlighterOpacity);
  expect(controller.dragStartSlop, before.dragStartSlop);
  expect(controller.pointerSettings, before.pointerSettings);
  expect(controller.selectionRect, before.selectionRect);
  expect(controller.pendingLineStart, before.pendingLineStart);
  expect(controller.pendingLineTimestampMs, before.pendingLineTimestampMs);
  expect(controller.hasPendingLineStart, before.hasPendingLineStart);
}

void setBeforePointerDispatchHook(
  SceneControllerInteractive controller,
  VoidCallback? hook,
) {
  sceneControllerInteractiveInternalSetBeforePointerDispatchHook(
    controller,
    hook,
  );
}

Offset runMoveCommitDeltaResolverForTest(
  SceneControllerInteractive controller, {
  required SceneSnapshot snapshot,
  required List<NodeSnapshot> movedNodes,
  required Offset proposedDelta,
}) {
  return sceneControllerInteractiveInternalRunMoveCommitDeltaResolverForTest(
    controller,
    snapshot: snapshot,
    movedNodes: movedNodes,
    proposedDelta: proposedDelta,
  );
}

void enforceGestureBufferSoftLimitForTest(
  SceneControllerInteractive controller, {
  required List<Offset> points,
  required int softLimit,
  required int trimTo,
}) {
  sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest(
    controller,
    points: points,
    softLimit: softLimit,
    trimTo: trimTo,
  );
}

int activeEraserPointsLength(SceneControllerInteractive controller) {
  return sceneControllerInteractiveInternalActiveEraserPointsLength(controller);
}

int eraserSpatialQueryCount(SceneControllerInteractive controller) {
  return sceneControllerInteractiveInternalEraserSpatialQueryCount(controller);
}

int eraserPreciseSegmentCheckCount(SceneControllerInteractive controller) {
  return sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
    controller,
  );
}

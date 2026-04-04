import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';
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

SceneController controllerFromScene(
  Scene scene, {
  PointerInputSettings? pointerSettings,
  double? dragStartSlop,
  bool clearSelectionOnDrawModeEnter = false,
  MoveCommitDeltaResolver? moveCommitDeltaResolver,
  String? textFontFamilyByDefault,
}) {
  return SceneController(
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

typedef InteractiveMutatingCall = void Function(SceneController controller);

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
  SceneController controller,
) {
  return InteractiveControllerStableState(
    snapshot: controller.snapshot,
    selection: controller.selectedNodeIds,
    mode: controller.interaction.mode,
    drawTool: controller.interaction.drawTool,
    drawColor: controller.interaction.drawColor,
    penThickness: controller.interaction.penThickness,
    highlighterThickness: controller.interaction.highlighterThickness,
    lineThickness: controller.interaction.lineThickness,
    eraserThickness: controller.interaction.eraserThickness,
    highlighterOpacity: controller.interaction.highlighterOpacity,
    dragStartSlop: controller.interaction.dragStartSlop,
    pointerSettings: controller.interaction.pointerSettings,
    selectionRect: controller.interaction.selectionRect,
    pendingLineStart: controller.interaction.pendingLineStart,
    pendingLineTimestampMs: controller.interaction.pendingLineTimestampMs,
    hasPendingLineStart: controller.interaction.hasPendingLineStart,
  );
}

void expectStableStateUnchanged(
  SceneController controller,
  InteractiveControllerStableState before,
) {
  expect(controller.snapshot, same(before.snapshot));
  expect(controller.selectedNodeIds, before.selection);
  expect(controller.interaction.mode, before.mode);
  expect(controller.interaction.drawTool, before.drawTool);
  expect(controller.interaction.drawColor, before.drawColor);
  expect(controller.interaction.penThickness, before.penThickness);
  expect(
    controller.interaction.highlighterThickness,
    before.highlighterThickness,
  );
  expect(controller.interaction.lineThickness, before.lineThickness);
  expect(controller.interaction.eraserThickness, before.eraserThickness);
  expect(controller.interaction.highlighterOpacity, before.highlighterOpacity);
  expect(controller.interaction.dragStartSlop, before.dragStartSlop);
  expect(controller.interaction.pointerSettings, before.pointerSettings);
  expect(controller.interaction.selectionRect, before.selectionRect);
  expect(controller.interaction.pendingLineStart, before.pendingLineStart);
  expect(
    controller.interaction.pendingLineTimestampMs,
    before.pendingLineTimestampMs,
  );
  expect(
    controller.interaction.hasPendingLineStart,
    before.hasPendingLineStart,
  );
}

void setBeforePointerDispatchHook(
  SceneController controller,
  VoidCallback? hook,
) {
  sceneControllerInternalSetBeforePointerDispatchHook(controller, hook);
}

Offset runMoveCommitDeltaResolverForTest(
  SceneController controller, {
  required SceneSnapshot snapshot,
  required List<NodeSnapshot> movedNodes,
  required Offset proposedDelta,
}) {
  return sceneControllerInternalRunMoveCommitDeltaResolverForTest(
    controller,
    snapshot: snapshot,
    movedNodes: movedNodes,
    proposedDelta: proposedDelta,
  );
}

void enforceGestureBufferSoftLimitForTest(
  SceneController controller, {
  required List<Offset> points,
  required int softLimit,
  required int trimTo,
}) {
  sceneControllerInternalEnforceGestureBufferSoftLimitForTest(
    controller,
    points: points,
    softLimit: softLimit,
    trimTo: trimTo,
  );
}

int activeEraserPointsLength(SceneController controller) {
  return sceneControllerInternalActiveEraserPointsLength(controller);
}

int eraserSpatialQueryCount(SceneController controller) {
  return sceneControllerInternalEraserSpatialQueryCount(controller);
}

int eraserPreciseSegmentCheckCount(SceneController controller) {
  return sceneControllerInternalEraserPreciseSegmentCheckCount(controller);
}

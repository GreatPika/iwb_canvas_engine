import 'dart:ui';

import '../../core/nodes.dart';
import '../../core/scene.dart';
import '../../core/scene_spatial_index.dart';
import '../action_events.dart';
import '../types.dart';

/// Narrow boundary contracts for input slices.
///
/// This file is intentionally `internal/` and should not import input slice
/// implementations or `scene_controller.dart` to avoid dependency cycles.
abstract class InputSliceContracts {
  // (1) Scene + coordinate transforms
  Scene get scene;
  Offset toScenePoint(Offset viewPoint);
  double get dragStartSlop;
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds);

  // (2) Selection
  Set<NodeId> get selectedNodeIds;
  bool setSelection(Iterable<NodeId> ids, {bool notify = true});
  Rect? get selectionRect;
  void setSelectionRect(Rect? rect, {bool notify = true});

  // (3) Revisions / change markers
  int get sceneRevision;
  int get selectionRevision;
  int get selectionRectRevision;
  void markSceneGeometryChanged();
  void markSceneStructuralChanged();
  void markSelectionChanged();

  // (4) Repaint / notifications
  void requestRepaintOncePerFrame();
  void notifyNow();
  bool get needsNotify;
  void notifyNowIfNeeded();

  // (5) Signals
  void emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  });
  void emitEditTextRequested(EditTextRequested req);
  int resolveTimestampMs(int? hintTimestampMs);

  // (6) ID generation
  NodeId newNodeId();

  // (7) Drawing settings (read-only)
  DrawTool get drawTool;
  Color get drawColor;
  double get penThickness;
  double get highlighterThickness;
  double get lineThickness;
  double get eraserThickness;
  double get highlighterOpacity;
}

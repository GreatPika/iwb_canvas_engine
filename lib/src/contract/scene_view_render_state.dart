import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'scene_render_state.dart';
import 'snapshot.dart';

class ScenePaintCandidateQuery {
  const ScenePaintCandidateQuery({
    required this.viewportRect,
    required this.visibilityRect,
  });

  final Rect viewportRect;
  final Rect visibilityRect;

  @override
  bool operator ==(Object other) {
    return other is ScenePaintCandidateQuery &&
        other.viewportRect == viewportRect &&
        other.visibilityRect == visibilityRect;
  }

  @override
  int get hashCode => Object.hash(viewportRect, visibilityRect);
}

class ScenePaintCandidate {
  const ScenePaintCandidate({
    required this.node,
    required this.paintBoundsWorld,
  });

  final NodeSnapshot node;
  final Rect paintBoundsWorld;
}

/// Atomic frame read captured once and reused across the scene paint pipeline.
final class SceneViewFrameRead {
  SceneViewFrameRead({
    required this.snapshot,
    required Set<NodeId> selectedNodeIds,
    required this.previewDeltaResolver,
  }) : selectedNodeIds = Set<NodeId>.unmodifiable(selectedNodeIds);

  final SceneSnapshot snapshot;
  final Set<NodeId> selectedNodeIds;
  final Offset Function(NodeId nodeId) previewDeltaResolver;

  Offset get cameraOffset => snapshot.camera.offset;
}

/// Internal read-side contract shared by the main painter and overlay painter.
abstract interface class SceneViewRenderState implements SceneRenderState {
  int get controllerEpoch;
  Listenable get overlayRepaintListenable;
  Rect? get selectionRect;
  Offset get cameraOffset;
  Offset Function(NodeId nodeId) get previewDeltaResolver;
  SceneViewFrameRead captureFrameRead();
  Iterable<ScenePaintCandidate> enumeratePaintCandidates(
    SceneViewFrameRead frameRead,
    ScenePaintCandidateQuery query,
  );

  bool get hasActiveStrokePreview;
  List<Offset> get activeStrokePreviewPoints;
  double get activeStrokePreviewThickness;
  Color get activeStrokePreviewColor;
  double get activeStrokePreviewOpacity;

  bool get hasActiveLinePreview;
  Offset? get activeLinePreviewStart;
  Offset? get activeLinePreviewEnd;
  double get activeLinePreviewThickness;
  Color get activeLinePreviewColor;
}

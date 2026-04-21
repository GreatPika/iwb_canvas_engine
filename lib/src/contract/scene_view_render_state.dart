import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'scene_render_state.dart';
import 'snapshot.dart';

final class SceneViewFramePreview {
  const SceneViewFramePreview.empty() : _nodeOffsets = const <NodeId, Offset>{};

  SceneViewFramePreview._(Map<NodeId, Offset> nodeOffsets)
    : _nodeOffsets = Map<NodeId, Offset>.unmodifiable(nodeOffsets);

  factory SceneViewFramePreview.captureNodeOffsets({
    required Iterable<NodeId> nodeIds,
    required Offset Function(NodeId nodeId) deltaForNode,
  }) {
    final nodeOffsets = <NodeId, Offset>{};
    for (final nodeId in nodeIds) {
      final delta = _sanitizeFramePreviewOffset(deltaForNode(nodeId));
      if (delta == Offset.zero) {
        continue;
      }
      nodeOffsets[nodeId] = delta;
    }
    return SceneViewFramePreview._(nodeOffsets);
  }

  factory SceneViewFramePreview.captureSnapshot({
    required SceneSnapshot snapshot,
    required Offset Function(NodeId nodeId) deltaForNode,
  }) {
    return SceneViewFramePreview.captureNodeOffsets(
      nodeIds: _snapshotNodeIds(snapshot),
      deltaForNode: deltaForNode,
    );
  }

  final Map<NodeId, Offset> _nodeOffsets;

  Offset deltaForNode(NodeId nodeId) {
    return _sanitizeFramePreviewOffset(_nodeOffsets[nodeId] ?? Offset.zero);
  }
}

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

abstract interface class ScenePreparedPaintPlan {
  int get candidateCount;
  ScenePaintCandidate candidateAt(int index);
}

final class ScenePreparedPaintCandidateList implements ScenePreparedPaintPlan {
  ScenePreparedPaintCandidateList(Iterable<ScenePaintCandidate> candidates)
    : _candidates = List<ScenePaintCandidate>.unmodifiable(candidates);

  final List<ScenePaintCandidate> _candidates;

  @override
  int get candidateCount => _candidates.length;

  @override
  ScenePaintCandidate candidateAt(int index) => _candidates[index];
}

/// Atomic frame read captured once and reused across the scene paint pipeline.
final class SceneViewFrameRead {
  SceneViewFrameRead({
    required this.snapshot,
    required Set<NodeId> selectedNodeIds,
    required this.selectionRevision,
    required this.preview,
  }) : selectedNodeIds = Set<NodeId>.unmodifiable(selectedNodeIds);

  final SceneSnapshot snapshot;
  final Set<NodeId> selectedNodeIds;
  final int selectionRevision;
  final SceneViewFramePreview preview;

  Offset get cameraOffset => snapshot.camera.offset;
}

/// Internal read-side contract shared by the main painter and overlay painter.
abstract interface class SceneViewRenderState implements SceneRenderState {
  int get controllerEpoch;
  Listenable get overlayRepaintListenable;
  Rect? get selectionRect;
  Offset get cameraOffset;
  SceneViewFrameRead captureFrameRead();
  ScenePreparedPaintPlan preparePaintPlan(
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

Iterable<NodeId> _snapshotNodeIds(SceneSnapshot snapshot) sync* {
  for (final node in snapshot.backgroundLayer.nodes) {
    yield node.id;
  }
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      yield node.id;
    }
  }
}

Offset _sanitizeFramePreviewOffset(Offset value) {
  if (!value.dx.isFinite || !value.dy.isFinite) {
    return Offset.zero;
  }
  return value;
}

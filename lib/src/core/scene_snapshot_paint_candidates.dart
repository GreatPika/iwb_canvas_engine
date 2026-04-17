import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import 'geometry.dart';
import 'node_geometry.dart';
import 'numeric_clamp.dart';

Iterable<ScenePaintCandidate> enumerateSnapshotPaintCandidates({
  required SceneSnapshot snapshot,
  required ScenePaintCandidateQuery query,
  required Set<NodeId> selectedNodeIds,
  required Offset Function(NodeId nodeId) previewDeltaResolver,
}) sync* {
  for (final node in snapshot.backgroundLayer.nodes) {
    if (_snapshotNodeOverlapsQuery(
      node: node,
      query: query,
      selectedNodeIds: selectedNodeIds,
      previewDeltaResolver: previewDeltaResolver,
    )) {
      yield ScenePaintCandidate(
        node: node,
        paintBoundsWorld: _snapshotPaintBoundsWorld(
          node: node,
          previewDeltaResolver: previewDeltaResolver,
        ),
      );
    }
  }
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (_snapshotNodeOverlapsQuery(
        node: node,
        query: query,
        selectedNodeIds: selectedNodeIds,
        previewDeltaResolver: previewDeltaResolver,
      )) {
        yield ScenePaintCandidate(
          node: node,
          paintBoundsWorld: _snapshotPaintBoundsWorld(
            node: node,
            previewDeltaResolver: previewDeltaResolver,
          ),
        );
      }
    }
  }
}

bool _snapshotNodeOverlapsQuery({
  required NodeSnapshot node,
  required ScenePaintCandidateQuery query,
  required Set<NodeId> selectedNodeIds,
  required Offset Function(NodeId nodeId) previewDeltaResolver,
}) {
  final paintBounds = _snapshotPaintBoundsWorld(
    node: node,
    previewDeltaResolver: previewDeltaResolver,
  );
  if (!isFiniteRect(paintBounds)) {
    return false;
  }
  final visibilityRect = selectedNodeIds.contains(node.id)
      ? query.visibilityRect
      : query.viewportRect;
  return visibilityRect.overlaps(paintBounds);
}

Rect _snapshotPaintBoundsWorld({
  required NodeSnapshot node,
  required Offset Function(NodeId nodeId) previewDeltaResolver,
}) {
  requireNodeSnapshotGeometrySupport(node);
  final previewDelta = sanitizeFiniteOffset(previewDeltaResolver(node.id));
  return nodeSnapshotPaintBoundsWorld(node).shift(previewDelta);
}

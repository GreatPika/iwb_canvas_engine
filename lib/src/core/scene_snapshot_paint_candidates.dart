import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import 'geometry.dart';
import 'node_geometry.dart';

Iterable<ScenePaintCandidate> enumerateSnapshotPaintCandidates({
  required SceneSnapshot snapshot,
  required ScenePaintCandidateQuery query,
  required Set<NodeId> selectedNodeIds,
  required SceneViewFramePreview preview,
}) sync* {
  for (final node in snapshot.backgroundLayer.nodes) {
    if (_snapshotNodeOverlapsQuery(
      node: node,
      query: query,
      selectedNodeIds: selectedNodeIds,
      preview: preview,
    )) {
      yield ScenePaintCandidate(
        node: node,
        paintBoundsWorld: _snapshotPaintBoundsWorld(
          node: node,
          preview: preview,
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
        preview: preview,
      )) {
        yield ScenePaintCandidate(
          node: node,
          paintBoundsWorld: _snapshotPaintBoundsWorld(
            node: node,
            preview: preview,
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
  required SceneViewFramePreview preview,
}) {
  final paintBounds = _snapshotPaintBoundsWorld(node: node, preview: preview);
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
  required SceneViewFramePreview preview,
}) {
  requireNodeSnapshotGeometrySupport(node);
  final previewDelta = preview.deltaForNode(node.id);
  return nodeSnapshotPaintBoundsWorld(node).shift(previewDelta);
}

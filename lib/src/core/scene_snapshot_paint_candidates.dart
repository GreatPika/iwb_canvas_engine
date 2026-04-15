import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import 'geometry.dart';
import 'node_geometry.dart';
import 'numeric_clamp.dart';

Iterable<NodeSnapshot> enumerateSnapshotPaintCandidates({
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
      yield node;
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
        yield node;
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
  final previewDelta = sanitizeFiniteOffset(previewDeltaResolver(node.id));
  requireNodeSnapshotGeometrySupport(node);
  final candidateBounds = nodeSnapshotGeometryCandidateBoundsWorld(
    node,
  ).shift(previewDelta);
  if (!isFiniteRect(candidateBounds)) {
    return false;
  }
  final visibilityRect = selectedNodeIds.contains(node.id)
      ? query.visibilityRect
      : query.viewportRect;
  return visibilityRect.overlaps(candidateBounds);
}

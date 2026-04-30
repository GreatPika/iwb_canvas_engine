import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import 'geometry.dart';
import 'paint_candidate_admission.dart';
import 'snapshot_paint_admission_bounds.dart';

Iterable<ScenePaintCandidate> enumerateSnapshotPaintCandidates({
  required SceneSnapshot snapshot,
  required ScenePaintCandidateQuery query,
  required Set<NodeId> selectedNodeIds,
  required SceneViewFramePreview preview,
  required SnapshotPaintAdmissionBoundsSource admissionBounds,
}) sync* {
  for (final node in snapshot.backgroundLayer.nodes) {
    final paintBoundsWorld = _snapshotPaintBoundsForQuery(
      node: node,
      query: query,
      selectedNodeIds: selectedNodeIds,
      preview: preview,
      admissionBounds: admissionBounds,
    );
    if (paintBoundsWorld != null) {
      yield ScenePaintCandidate(node: node, paintBoundsWorld: paintBoundsWorld);
    }
  }
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      final paintBoundsWorld = _snapshotPaintBoundsForQuery(
        node: node,
        query: query,
        selectedNodeIds: selectedNodeIds,
        preview: preview,
        admissionBounds: admissionBounds,
      );
      if (paintBoundsWorld != null) {
        yield ScenePaintCandidate(
          node: node,
          paintBoundsWorld: paintBoundsWorld,
        );
      }
    }
  }
}

Rect? _snapshotPaintBoundsForQuery({
  required NodeSnapshot node,
  required ScenePaintCandidateQuery query,
  required Set<NodeId> selectedNodeIds,
  required SceneViewFramePreview preview,
  required SnapshotPaintAdmissionBoundsSource admissionBounds,
}) {
  final paintBounds = admissionBounds
      .resolveBasePaintBounds(node)
      .shift(preview.deltaForNode(node.id));
  if (!isFiniteRect(paintBounds)) {
    return null;
  }
  final visibilityRect = selectedNodeIds.contains(node.id)
      ? query.visibilityRect
      : query.viewportRect;
  return admitsPaintCandidate(
        queryRect: visibilityRect,
        paintBoundsWorld: paintBounds,
      )
      ? paintBounds
      : null;
}

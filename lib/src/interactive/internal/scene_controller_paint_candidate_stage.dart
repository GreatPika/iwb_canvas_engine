import 'dart:ui';

import '../../contract/scene_view_render_state.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_store_controller.dart';
import '../../core/geometry.dart';
import '../../core/node_geometry.dart';
import '../../core/numeric_clamp.dart';
import '../../core/scene_spatial_index.dart';

typedef _OrderedPaintCandidate = ({
  ScenePaintCandidate candidate,
  int layerIndex,
  int nodeIndex,
});

final class SceneControllerPaintCandidateStage {
  const SceneControllerPaintCandidateStage({
    required SceneStoreController store,
  }) : _store = store;

  final SceneStoreController _store;

  ScenePreparedPaintPlan prepareCommittedPaintPlan({
    required ScenePaintCandidateQuery query,
    required Set<NodeId> selectedNodeIds,
    required Offset Function(NodeId nodeId) previewResolver,
  }) {
    final buffers = _PaintCandidateStageBuffers();

    _stageOrdinaryCandidates(
      buffers: buffers,
      viewportRect: query.viewportRect,
    );
    _stageSelectedSupplements(
      buffers: buffers,
      selectedNodeIds: selectedNodeIds,
      visibilityRect: query.visibilityRect,
      previewResolver: previewResolver,
    );

    buffers.orderedCandidates.sort(_compareSceneOrder);

    return ScenePreparedPaintCandidateList(
      buffers.orderedCandidates.map((candidate) => candidate.candidate),
    );
  }

  void _stageOrdinaryCandidates({
    required _PaintCandidateStageBuffers buffers,
    required Rect viewportRect,
  }) {
    for (final candidate in _store.queryPaintCandidates(
      viewportRect,
      scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
    )) {
      final resolvedNode = _store.resolveSpatialCandidateSnapshot((
        nodeId: candidate.nodeId,
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
      if (resolvedNode == null ||
          !buffers.acceptedNodeIds.add(resolvedNode.id)) {
        continue;
      }
      buffers.orderedCandidates.add((
        candidate: ScenePaintCandidate(
          node: resolvedNode,
          paintBoundsWorld: candidate.paintBoundsWorld,
        ),
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
    }
  }

  void _stageSelectedSupplements({
    required _PaintCandidateStageBuffers buffers,
    required Set<NodeId> selectedNodeIds,
    required Rect visibilityRect,
    required Offset Function(NodeId nodeId) previewResolver,
  }) {
    for (final nodeId in selectedNodeIds) {
      final resolvedNode = _store.resolveSnapshotNodeById(nodeId);
      if (resolvedNode == null || buffers.acceptedNodeIds.contains(nodeId)) {
        continue;
      }
      final paintBounds = _snapshotPaintBoundsWorld(
        node: resolvedNode.node,
        previewResolver: previewResolver,
      );
      if (!isFiniteRect(paintBounds) || !visibilityRect.overlaps(paintBounds)) {
        continue;
      }
      if (!buffers.acceptedNodeIds.add(nodeId)) {
        continue;
      }
      buffers.orderedCandidates.add((
        candidate: ScenePaintCandidate(
          node: resolvedNode.node,
          paintBoundsWorld: paintBounds,
        ),
        layerIndex: resolvedNode.layerIndex,
        nodeIndex: resolvedNode.nodeIndex,
      ));
    }
  }
}

final class _PaintCandidateStageBuffers {
  // Per-call scratch state only; do not retain across committed frames.
  final Set<NodeId> acceptedNodeIds = <NodeId>{};
  final List<_OrderedPaintCandidate> orderedCandidates =
      <_OrderedPaintCandidate>[];
}

int _compareSceneOrder(_OrderedPaintCandidate a, _OrderedPaintCandidate b) {
  final layerOrder = a.layerIndex.compareTo(b.layerIndex);
  if (layerOrder != 0) {
    return layerOrder;
  }
  return a.nodeIndex.compareTo(b.nodeIndex);
}

Rect _snapshotPaintBoundsWorld({
  required NodeSnapshot node,
  required Offset Function(NodeId nodeId) previewResolver,
}) {
  requireNodeSnapshotGeometrySupport(node);
  final previewDelta = sanitizeFiniteOffset(previewResolver(node.id));
  return nodeSnapshotPaintBoundsWorld(node).shift(previewDelta);
}

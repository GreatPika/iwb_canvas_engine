import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/scene_view_render_state.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_store_controller.dart';
import '../../core/geometry.dart';
import '../../core/node_geometry.dart';
import '../../core/scene_spatial_index.dart';
import 'scene_controller_selected_paint_order_cache.dart';

typedef _OrderedPaintCandidate = ({
  ScenePaintCandidate candidate,
  int layerIndex,
  int nodeIndex,
});

final class SceneControllerPaintCandidateStage {
  SceneControllerPaintCandidateStage({required SceneStoreController store})
    : _store = store;

  final SceneStoreController _store;
  final SceneControllerSelectedPaintOrderCache _selectedOrderCache =
      SceneControllerSelectedPaintOrderCache();
  final _PaintCandidateStageBuffers _buffers = _PaintCandidateStageBuffers();
  bool _hasUsedBuffers = false;
  int _debugStageBufferReuseCount = 0;
  int _debugCommittedFastPathGlobalSortAvoidanceCount = 0;

  @visibleForTesting
  int get debugSelectedOrderCacheRebuildCount =>
      _selectedOrderCache.debugRebuildCount;

  @visibleForTesting
  int get debugSelectedOrderCacheFastReturnCount =>
      _selectedOrderCache.debugFastReturnCount;

  @visibleForTesting
  int get debugStageBufferReuseCount => _debugStageBufferReuseCount;

  @visibleForTesting
  int get debugCommittedFastPathGlobalSortAvoidanceCount =>
      _debugCommittedFastPathGlobalSortAvoidanceCount;

  ScenePreparedPaintPlan prepareCommittedPaintPlan({
    required ScenePaintCandidateQuery query,
    required Set<NodeId> selectedNodeIds,
    required int selectionRevision,
    required SceneViewFramePreview preview,
  }) {
    final buffers = _buffers;
    if (_hasUsedBuffers) {
      _debugStageBufferReuseCount += 1;
    }
    _hasUsedBuffers = true;
    buffers.clear();

    _stageOrdinaryCandidates(
      buffers: buffers,
      viewportRect: query.viewportRect,
    );
    _stageSelectedSupplements(
      buffers: buffers,
      selectedNodeIds: selectedNodeIds,
      selectionRevision: selectionRevision,
      structuralRevision: _store.structuralRevision,
      visibilityRect: query.visibilityRect,
      preview: preview,
    );

    _mergeOrderedCandidates(buffers);
    _debugCommittedFastPathGlobalSortAvoidanceCount += 1;

    return ScenePreparedPaintCandidateList(buffers.mergedCandidates);
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
      buffers.ordinaryCandidates.add((
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
    required int selectionRevision,
    required int structuralRevision,
    required Rect visibilityRect,
    required SceneViewFramePreview preview,
  }) {
    final selectedTokens = _selectedOrderCache.orderedSelectedTokens(
      selectionRevision: selectionRevision,
      structuralRevision: structuralRevision,
      selectedNodeIds: selectedNodeIds,
      resolveOrder: (nodeId) {
        final resolvedNode = _store.resolveSnapshotNodeById(nodeId);
        if (resolvedNode == null) {
          return null;
        }
        return (
          layerIndex: resolvedNode.layerIndex,
          nodeIndex: resolvedNode.nodeIndex,
        );
      },
    );

    for (final token in selectedTokens) {
      final resolvedNode = _store.resolveSnapshotNodeById(token.nodeId);
      if (resolvedNode == null ||
          buffers.acceptedNodeIds.contains(token.nodeId)) {
        continue;
      }
      final paintBounds = _snapshotPaintBoundsWorld(
        node: resolvedNode.node,
        preview: preview,
      );
      if (!isFiniteRect(paintBounds) || !visibilityRect.overlaps(paintBounds)) {
        continue;
      }
      if (!buffers.acceptedNodeIds.add(token.nodeId)) {
        continue;
      }
      buffers.supplementCandidates.add((
        candidate: ScenePaintCandidate(
          node: resolvedNode.node,
          paintBoundsWorld: paintBounds,
        ),
        layerIndex: token.layerIndex,
        nodeIndex: token.nodeIndex,
      ));
    }
  }

  void _mergeOrderedCandidates(_PaintCandidateStageBuffers buffers) {
    var ordinaryIndex = 0;
    var supplementIndex = 0;
    while (ordinaryIndex < buffers.ordinaryCandidates.length ||
        supplementIndex < buffers.supplementCandidates.length) {
      if (ordinaryIndex >= buffers.ordinaryCandidates.length) {
        buffers.mergedCandidates.add(
          buffers.supplementCandidates[supplementIndex].candidate,
        );
        supplementIndex += 1;
        continue;
      }
      if (supplementIndex >= buffers.supplementCandidates.length) {
        buffers.mergedCandidates.add(
          buffers.ordinaryCandidates[ordinaryIndex].candidate,
        );
        ordinaryIndex += 1;
        continue;
      }

      final ordinary = buffers.ordinaryCandidates[ordinaryIndex];
      final supplement = buffers.supplementCandidates[supplementIndex];
      if (_compareSceneOrder(supplement, ordinary) < 0) {
        buffers.mergedCandidates.add(supplement.candidate);
        supplementIndex += 1;
      } else {
        buffers.mergedCandidates.add(ordinary.candidate);
        ordinaryIndex += 1;
      }
    }
  }
}

final class _PaintCandidateStageBuffers {
  // Per-call scratch state only; do not retain across committed frames.
  final Set<NodeId> acceptedNodeIds = <NodeId>{};
  final List<_OrderedPaintCandidate> ordinaryCandidates =
      <_OrderedPaintCandidate>[];
  final List<_OrderedPaintCandidate> supplementCandidates =
      <_OrderedPaintCandidate>[];
  final List<ScenePaintCandidate> mergedCandidates = <ScenePaintCandidate>[];

  void clear() {
    acceptedNodeIds.clear();
    ordinaryCandidates.clear();
    supplementCandidates.clear();
    mergedCandidates.clear();
  }
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
  required SceneViewFramePreview preview,
}) {
  requireNodeSnapshotGeometrySupport(node);
  final previewDelta = preview.deltaForNode(node.id);
  return nodeSnapshotPaintBoundsWorld(node).shift(previewDelta);
}

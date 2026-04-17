import 'dart:ui';

import '../../core/hit_test.dart';
import '../../core/node_geometry.dart';
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';
import '../interaction_eligibility_policy.dart'
    as interaction_eligibility_policy;
import 'interactive_move_callbacks.dart';
import 'interactive_move_preview_state.dart';

final class InteractiveMoveHitTestEngine {
  const InteractiveMoveHitTestEngine({
    required this.callbacks,
    required this.previewState,
  });

  final InteractiveMoveSessionCallbacks callbacks;
  final InteractiveMovePreviewState previewState;

  Set<NodeId> nodesIntersecting(Rect rect) {
    final ids = <NodeId>{};
    final candidates =
        callbacks.queryHitTestCandidates(rect).toList(growable: true)
          ..sort((left, right) {
            final byLayer = left.layerIndex.compareTo(right.layerIndex);
            if (byLayer != 0) {
              return byLayer;
            }
            return left.nodeIndex.compareTo(right.nodeIndex);
          });

    for (final candidate in candidates) {
      final node = callbacks.resolveSpatialCandidateSnapshot((
        nodeId: candidate.nodeId,
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
      if (node == null) {
        continue;
      }
      if (!interaction_eligibility_policy.canSelect(node)) {
        continue;
      }
      if (!effectiveNodeBoundsWorld(node).overlaps(rect)) {
        continue;
      }
      ids.add(node.id);
    }

    return ids;
  }

  NodeSnapshot? hitTestTopNode(Offset scenePoint) {
    final candidates = _queryHitTestCandidates(scenePoint);

    for (final candidate in candidates) {
      final node = callbacks.resolveSpatialCandidateSnapshot((
        nodeId: candidate.nodeId,
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
      if (node == null) {
        continue;
      }
      if (!interaction_eligibility_policy.canSelect(node)) {
        continue;
      }
      if (_hitTestNodeWithMovePreview(scenePoint, node)) {
        return node;
      }
    }

    return null;
  }

  Rect effectiveNodeBoundsWorld(NodeSnapshot node) {
    final delta = previewState.deltaForNode(node.id);
    return nodeSnapshotBoundsWorld(node).shift(delta);
  }

  List<SceneHitTestSpatialCandidate> _queryHitTestCandidates(
    Offset scenePoint,
  ) {
    final probe = Rect.fromLTWH(scenePoint.dx, scenePoint.dy, 0, 0);
    final byNodeId = <NodeId, SceneHitTestSpatialCandidate>{};
    for (final candidate in callbacks.queryHitTestCandidates(probe)) {
      byNodeId[candidate.nodeId] = candidate;
    }
    if (previewState.hasTranslation) {
      final shiftedProbe = Rect.fromLTWH(
        scenePoint.dx - previewState.delta.dx,
        scenePoint.dy - previewState.delta.dy,
        0,
        0,
      );
      for (final candidate in callbacks.queryHitTestCandidates(shiftedProbe)) {
        byNodeId[candidate.nodeId] = candidate;
      }
    }
    final candidates = byNodeId.values.toList(growable: true)
      ..sort((left, right) {
        final byLayer = right.layerIndex.compareTo(left.layerIndex);
        if (byLayer != 0) {
          return byLayer;
        }
        return right.nodeIndex.compareTo(left.nodeIndex);
      });
    return candidates;
  }

  bool _hitTestNodeWithMovePreview(Offset scenePoint, NodeSnapshot node) {
    final delta = previewState.deltaForNode(node.id);
    if (delta == Offset.zero) {
      return hitTestNodeSnapshot(scenePoint, node);
    }
    return hitTestNodeSnapshot(scenePoint - delta, node);
  }
}

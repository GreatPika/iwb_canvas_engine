import 'dart:ui';

import '../../core/hit_test.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/scene_spatial_index.dart';
import '../../contract/ids.dart';
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
        callbacks.querySpatialCandidates(rect).toList(growable: true)
          ..sort((left, right) {
            final byLayer = left.layerIndex.compareTo(right.layerIndex);
            if (byLayer != 0) {
              return byLayer;
            }
            return left.nodeIndex.compareTo(right.nodeIndex);
          });

    for (final candidate in candidates) {
      final node = callbacks.resolveSpatialCandidateNode(candidate);
      if (node == null) {
        continue;
      }
      if (!interaction_eligibility_policy.canSelectSceneNode(node)) {
        continue;
      }
      if (!effectiveNodeBoundsWorld(node).overlaps(rect)) {
        continue;
      }
      ids.add(node.id);
    }

    return ids;
  }

  SceneNode? hitTestTopNode(Offset scenePoint) {
    final candidates = _queryHitTestCandidates(scenePoint);

    for (final candidate in candidates) {
      final node = callbacks.resolveSpatialCandidateNode(candidate);
      if (node == null) {
        continue;
      }
      if (!interaction_eligibility_policy.canSelectSceneNode(node)) {
        continue;
      }
      if (_hitTestNodeWithMovePreview(scenePoint, node)) {
        return node;
      }
    }

    return null;
  }

  Rect effectiveNodeBoundsWorld(SceneNode node) {
    final delta = previewState.deltaForNode(node.id);
    return node.boundsWorld.shift(delta);
  }

  List<SceneSpatialCandidate> _queryHitTestCandidates(Offset scenePoint) {
    final probe = Rect.fromLTWH(scenePoint.dx, scenePoint.dy, 0, 0);
    final byNodeId = <NodeId, SceneSpatialCandidate>{};
    for (final candidate in callbacks.querySpatialCandidates(probe)) {
      byNodeId[candidate.nodeId] = candidate;
    }
    if (previewState.hasTranslation) {
      final shiftedProbe = Rect.fromLTWH(
        scenePoint.dx - previewState.delta.dx,
        scenePoint.dy - previewState.delta.dy,
        0,
        0,
      );
      for (final candidate in callbacks.querySpatialCandidates(shiftedProbe)) {
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

  bool _hitTestNodeWithMovePreview(Offset scenePoint, SceneNode node) {
    final delta = previewState.deltaForNode(node.id);
    if (delta == Offset.zero) {
      return hitTestNode(scenePoint, node);
    }
    return hitTestNode(scenePoint - delta, node);
  }
}

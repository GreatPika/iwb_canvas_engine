import 'dart:math' as math;
import 'dart:ui';

import '../../core/hit_test.dart';
import '../../core/nodes.dart' show LineNode, SceneNode, StrokeNode;
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';
import '../interaction_eligibility_policy.dart'
    as interaction_eligibility_policy;
import 'interactive_geometry.dart';

class InteractiveDrawEraserTargetsCallbacks {
  const InteractiveDrawEraserTargetsCallbacks({
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.onSpatialQuery,
  });

  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final void Function() onSpatialQuery;
}

class InteractiveDrawEraserTarget {
  const InteractiveDrawEraserTarget({
    required this.layerIndex,
    required this.nodeIndex,
    required this.node,
  });

  final int layerIndex;
  final int nodeIndex;
  final SceneNode node;
}

class InteractiveDrawEraserTargets {
  const InteractiveDrawEraserTargets({required this.callbacks});

  final InteractiveDrawEraserTargetsCallbacks callbacks;

  static const int eraserQueryBatchSegments = 64;

  List<InteractiveDrawEraserTarget> queryDeletableTargets(
    List<Offset> eraserPoints, {
    required double eraserThickness,
  }) {
    final candidates =
        _queryCandidates(eraserPoints, eraserThickness: eraserThickness)
          ..sort((left, right) {
            final byLayer = left.layerIndex.compareTo(right.layerIndex);
            if (byLayer != 0) return byLayer;
            return left.nodeIndex.compareTo(right.nodeIndex);
          });
    return candidates;
  }

  List<InteractiveDrawEraserTarget> _queryCandidates(
    List<Offset> eraserPoints, {
    required double eraserThickness,
  }) {
    final byId = <NodeId, InteractiveDrawEraserTarget>{};
    final queryPadding = eraserThickness / 2 + kHitSlop;

    if (eraserPoints.length == 1) {
      final point = eraserPoints.first;
      final probe = Rect.fromLTWH(
        point.dx,
        point.dy,
        0,
        0,
      ).inflate(queryPadding);
      for (final candidate in _querySpatialCandidates(probe)) {
        _addTargetIfDeletable(byId, candidate);
      }
      return byId.values.toList(growable: false);
    }

    final segmentCount = eraserPoints.length - 1;
    for (
      var segmentStart = 0;
      segmentStart < segmentCount;
      segmentStart += eraserQueryBatchSegments
    ) {
      final segmentEndExclusive = math.min(
        segmentStart + eraserQueryBatchSegments,
        segmentCount,
      );
      final batchBounds = segmentRangeBounds(
        eraserPoints,
        segmentStart: segmentStart,
        segmentEndExclusive: segmentEndExclusive,
      ).inflate(queryPadding);
      for (final candidate in _querySpatialCandidates(batchBounds)) {
        _addTargetIfDeletable(byId, candidate);
      }
    }

    return byId.values.toList(growable: false);
  }

  void _addTargetIfDeletable(
    Map<NodeId, InteractiveDrawEraserTarget> byId,
    SceneSpatialCandidate candidate,
  ) {
    final node = callbacks.resolveSpatialCandidateNode(candidate);
    if (node == null) return;
    if (node is! StrokeNode && node is! LineNode) return;
    if (!interaction_eligibility_policy.canDeleteSceneNode(node)) return;
    byId[node.id] = InteractiveDrawEraserTarget(
      layerIndex: candidate.layerIndex,
      nodeIndex: candidate.nodeIndex,
      node: node,
    );
  }

  List<SceneSpatialCandidate> _querySpatialCandidates(Rect bounds) {
    callbacks.onSpatialQuery();
    return callbacks.querySpatialCandidates(bounds);
  }
}

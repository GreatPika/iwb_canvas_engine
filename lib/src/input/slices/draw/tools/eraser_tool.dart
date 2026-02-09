import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../../../../core/geometry.dart';
import '../../../../core/hit_test.dart';
import '../../../../core/input_sampling.dart';
import '../../../../core/nodes.dart';
import '../../../../core/scene_spatial_index.dart';
import '../../../action_events.dart';
import '../../../internal/contracts.dart';

class EraserTool {
  EraserTool(this._contracts);

  final InputSliceContracts _contracts;
  final List<Offset> _eraserPoints = <Offset>[];

  void handleDown(Offset scenePoint) {
    _eraserPoints
      ..clear()
      ..add(scenePoint);
  }

  void handleMove(Offset scenePoint) {
    _appendPoint(scenePoint);
    _contracts.requestRepaintOncePerFrame();
  }

  /// Commits erasing only on pointer up.
  ///
  /// During move, eraser keeps trajectory for visual feedback but does not
  /// mutate scene structure yet. This keeps cancel/mode-switch paths
  /// transactional (no partial deletions left behind).
  void handleUp(int timestampMs, Offset scenePoint) {
    _appendPoint(scenePoint, forceIfDifferent: true);

    final deletedNodeIds = _eraseAnnotations(_eraserPoints);
    _eraserPoints.clear();
    if (deletedNodeIds.isEmpty) {
      return;
    }
    final deletedIdSet = deletedNodeIds.toSet();
    _contracts.setSelection(
      _contracts.selectedNodeIds.where((id) => !deletedIdSet.contains(id)),
      notify: false,
    );
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.erase,
      deletedNodeIds,
      timestampMs,
      payload: <String, Object?>{'eraserThickness': _contracts.eraserThickness},
    );
  }

  void reset() {
    _eraserPoints.clear();
  }

  static double _maxSingularValue2x2(double a, double b, double c, double d) {
    final t = a * a + b * b + c * c + d * d;
    final det = a * d - b * c;
    final discSquared = t * t - 4 * det * det;
    final disc = math.sqrt(math.max(0, discSquared));
    final lambdaMax = (t + disc) / 2;
    return math.sqrt(math.max(0, lambdaMax));
  }

  List<NodeId> _eraseAnnotations(List<Offset> eraserPoints) {
    final deleted = <NodeId>[];
    if (eraserPoints.isEmpty) return deleted;

    final candidates = _queryEraserCandidates(eraserPoints)
      ..sort((left, right) {
        final byLayer = left.layerIndex.compareTo(right.layerIndex);
        if (byLayer != 0) return byLayer;
        return left.nodeIndex.compareTo(right.nodeIndex);
      });
    final deletionsByLayer = <int, List<int>>{};
    for (final candidate in candidates) {
      final layerIndex = candidate.layerIndex;
      if (layerIndex < 0 || layerIndex >= _contracts.scene.layers.length) {
        continue;
      }
      final layer = _contracts.scene.layers[layerIndex];
      if (layer.isBackground) continue;
      final nodeIndex = candidate.nodeIndex;
      if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
        continue;
      }
      final node = layer.nodes[nodeIndex];
      if (!identical(node, candidate.node)) continue;
      if (node is! StrokeNode && node is! LineNode) continue;
      if (!node.isDeletable) continue;
      if (!_eraserHitsNode(eraserPoints, node)) continue;
      deleted.add(node.id);
      final indices = deletionsByLayer.putIfAbsent(layerIndex, () => <int>[]);
      indices.add(nodeIndex);
    }

    final layerIndices = deletionsByLayer.keys.toList(growable: false)
      ..sort((left, right) => right.compareTo(left));
    for (final layerIndex in layerIndices) {
      final indices = deletionsByLayer[layerIndex]!
        ..sort((left, right) => right.compareTo(left));
      final layer = _contracts.scene.layers[layerIndex];
      for (final nodeIndex in indices) {
        if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) continue;
        final removedNode = layer.nodes.removeAt(nodeIndex);
        _contracts.unregisterNodeId(removedNode.id);
      }
    }
    return deleted;
  }

  List<SceneSpatialCandidate> _queryEraserCandidates(
    List<Offset> eraserPoints,
  ) {
    final byId = <NodeId, SceneSpatialCandidate>{};
    final queryPadding = _contracts.eraserThickness / 2 + kHitSlop;
    if (eraserPoints.length == 1) {
      final point = eraserPoints.first;
      final probe = Rect.fromLTWH(
        point.dx,
        point.dy,
        0,
        0,
      ).inflate(queryPadding);
      for (final candidate in _contracts.querySpatialCandidates(probe)) {
        byId[candidate.node.id] = candidate;
      }
      return byId.values.toList(growable: false);
    }

    for (var i = 0; i < eraserPoints.length - 1; i++) {
      final a = eraserPoints[i];
      final b = eraserPoints[i + 1];
      final segmentBounds = Rect.fromPoints(a, b).inflate(queryPadding);
      for (final candidate in _contracts.querySpatialCandidates(
        segmentBounds,
      )) {
        byId[candidate.node.id] = candidate;
      }
    }
    return byId.values.toList(growable: false);
  }

  void _appendPoint(Offset scenePoint, {bool forceIfDifferent = false}) {
    final last = _eraserPoints.last;
    if (forceIfDifferent) {
      if (isDistanceGreaterThan(last, scenePoint, 0)) {
        _eraserPoints.add(scenePoint);
      }
      return;
    }
    if (isDistanceAtLeast(last, scenePoint, kInputDecimationMinStepScene)) {
      _eraserPoints.add(scenePoint);
    }
  }

  bool _eraserHitsNode(List<Offset> eraserPoints, SceneNode node) {
    if (node is LineNode) {
      return _eraserHitsLine(eraserPoints, node);
    }
    if (node is StrokeNode) {
      return _eraserHitsStroke(eraserPoints, node);
    }
    return false;
  }

  bool _eraserHitsLine(List<Offset> eraserPoints, LineNode line) {
    final inverse = line.transform.invert();
    if (inverse == null) return false;
    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = _maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold =
        line.thickness / 2 + (_contracts.eraserThickness / 2) * sigmaMax;
    final thresholdSquared = threshold * threshold;
    if (localEraserPoints.length == 1) {
      return distanceSquaredPointToSegment(
            localEraserPoints.first,
            line.start,
            line.end,
          ) <=
          thresholdSquared;
    }
    for (var i = 0; i < localEraserPoints.length - 1; i++) {
      final a = localEraserPoints[i];
      final b = localEraserPoints[i + 1];
      if (distanceSquaredSegmentToSegment(a, b, line.start, line.end) <=
          thresholdSquared) {
        return true;
      }
    }
    return false;
  }

  bool _eraserHitsStroke(List<Offset> eraserPoints, StrokeNode stroke) {
    final inverse = stroke.transform.invert();
    if (inverse == null) return false;
    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = _maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold =
        stroke.thickness / 2 + (_contracts.eraserThickness / 2) * sigmaMax;
    final thresholdSquared = threshold * threshold;
    if (stroke.points.isEmpty) return false;
    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      for (final eraserPoint in localEraserPoints) {
        final delta = eraserPoint - point;
        final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
        if (distanceSquared <= thresholdSquared) {
          return true;
        }
      }
      return false;
    }

    if (localEraserPoints.length == 1) {
      final eraserPoint = localEraserPoints.first;
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final a = stroke.points[i];
        final b = stroke.points[i + 1];
        if (distanceSquaredPointToSegment(eraserPoint, a, b) <=
            thresholdSquared) {
          return true;
        }
      }
      return false;
    }

    for (var i = 0; i < localEraserPoints.length - 1; i++) {
      final eraserA = localEraserPoints[i];
      final eraserB = localEraserPoints[i + 1];
      for (var j = 0; j < stroke.points.length - 1; j++) {
        final strokeA = stroke.points[j];
        final strokeB = stroke.points[j + 1];
        if (distanceSquaredSegmentToSegment(
              eraserA,
              eraserB,
              strokeA,
              strokeB,
            ) <=
            thresholdSquared) {
          return true;
        }
      }
    }
    return false;
  }
}

import 'dart:math' as math;
import 'dart:ui';

import '../../core/geometry.dart';
import '../../core/hit_test.dart';
import '../../core/input_sampling.dart';
import '../../core/nodes.dart' show LineNode, SceneNode, StrokeNode;
import '../../core/scene_limits.dart';
import '../../core/scene_spatial_index.dart';
import '../../public/snapshot.dart';
import 'interactive_geometry.dart';

class InteractiveDrawEraserEngineCallbacks {
  const InteractiveDrawEraserEngineCallbacks({
    required this.onStateChanged,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeEraseNodes,
  });

  final VoidCallback onStateChanged;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final int Function(Iterable<NodeId> ids) writeEraseNodes;
}

class InteractiveDrawEraserEngine {
  InteractiveDrawEraserEngine({required this.callbacks});

  final InteractiveDrawEraserEngineCallbacks callbacks;

  final List<Offset> _activeEraserPoints = <Offset>[];

  int _debugEraserSpatialQueryCount = 0;
  int _debugEraserPreciseSegmentChecks = 0;

  static const int _eraserQueryBatchSegments = 64;
  static const int _eraserHitBatchSegments = 64;
  static const int _strokeHitBatchSegments = 32;

  int get activeEraserPointsLength => _activeEraserPoints.length;
  int get debugEraserSpatialQueryCount => _debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks => _debugEraserPreciseSegmentChecks;

  void resetGestureState() {
    _activeEraserPoints.clear();
  }

  void handleDown(Offset scenePoint) {
    _activeEraserPoints
      ..clear()
      ..add(scenePoint);
  }

  void handleMove(Offset scenePoint) {
    if (_activeEraserPoints.isEmpty) return;
    if (!isDistanceAtLeast(
      _activeEraserPoints.last,
      scenePoint,
      kInputDecimationMinStepScene,
    )) {
      return;
    }
    _activeEraserPoints.add(scenePoint);
    enforceGestureBufferSoftLimit(
      _activeEraserPoints,
      softLimit: kInteractiveEraserPointsSoftLimit,
      trimTo: kInteractiveEraserPointsTrimTo,
    );
    callbacks.onStateChanged();
  }

  List<NodeId> commitOnUp(
    Offset scenePoint, {
    required double eraserThickness,
  }) {
    if (_activeEraserPoints.isEmpty) return const <NodeId>[];

    _debugEraserSpatialQueryCount = 0;
    _debugEraserPreciseSegmentChecks = 0;

    if (isDistanceGreaterThan(_activeEraserPoints.last, scenePoint, 0)) {
      _activeEraserPoints.add(scenePoint);
      enforceGestureBufferSoftLimit(
        _activeEraserPoints,
        softLimit: kInteractiveEraserPointsSoftLimit,
        trimTo: kInteractiveEraserPointsTrimTo,
      );
    }

    final deletedIds = _eraseAnnotations(
      _activeEraserPoints,
      eraserThickness: eraserThickness,
    );
    _activeEraserPoints.clear();
    return deletedIds;
  }

  List<NodeId> _eraseAnnotations(
    List<Offset> eraserPoints, {
    required double eraserThickness,
  }) {
    final candidates =
        _queryEraserCandidates(eraserPoints, eraserThickness: eraserThickness)
          ..sort((left, right) {
            final byLayer = left.layerIndex.compareTo(right.layerIndex);
            if (byLayer != 0) return byLayer;
            return left.nodeIndex.compareTo(right.nodeIndex);
          });

    final ids = <NodeId>[];
    for (final candidate in candidates) {
      final node = callbacks.resolveSpatialCandidateNode(candidate);
      if (node == null) continue;
      if (node is! StrokeNode && node is! LineNode) continue;
      if (!node.isDeletable) continue;
      if (!_eraserHitsNode(
        eraserPoints,
        node,
        eraserThickness: eraserThickness,
      )) {
        continue;
      }
      ids.add(node.id);
    }

    if (ids.isEmpty) return const <NodeId>[];

    final removedCount = callbacks.writeEraseNodes(ids);
    if (removedCount <= 0) return const <NodeId>[];

    return ids;
  }

  List<SceneSpatialCandidate> _queryEraserCandidates(
    List<Offset> eraserPoints, {
    required double eraserThickness,
  }) {
    final byId = <NodeId, SceneSpatialCandidate>{};
    final queryPadding = eraserThickness / 2 + kHitSlop;

    if (eraserPoints.length == 1) {
      final point = eraserPoints.first;
      final probe = Rect.fromLTWH(
        point.dx,
        point.dy,
        0,
        0,
      ).inflate(queryPadding);
      for (final candidate in _querySpatialCandidatesForEraser(probe)) {
        byId[candidate.node.id] = candidate;
      }
      return byId.values.toList(growable: false);
    }

    final segmentCount = eraserPoints.length - 1;
    for (
      var segmentStart = 0;
      segmentStart < segmentCount;
      segmentStart += _eraserQueryBatchSegments
    ) {
      final segmentEndExclusive = math.min(
        segmentStart + _eraserQueryBatchSegments,
        segmentCount,
      );
      final batchBounds = segmentRangeBounds(
        eraserPoints,
        segmentStart: segmentStart,
        segmentEndExclusive: segmentEndExclusive,
      ).inflate(queryPadding);
      for (final candidate in _querySpatialCandidatesForEraser(batchBounds)) {
        byId[candidate.node.id] = candidate;
      }
    }

    return byId.values.toList(growable: false);
  }

  bool _eraserHitsNode(
    List<Offset> eraserPoints,
    SceneNode node, {
    required double eraserThickness,
  }) {
    if (node is LineNode) {
      return _eraserHitsLine(
        eraserPoints,
        node,
        eraserThickness: eraserThickness,
      );
    }
    if (node is StrokeNode) {
      return _eraserHitsStroke(
        eraserPoints,
        node,
        eraserThickness: eraserThickness,
      );
    }
    return false;
  }

  bool _eraserHitsLine(
    List<Offset> eraserPoints,
    LineNode line, {
    required double eraserThickness,
  }) {
    final inverse = line.transform.invert();
    if (inverse == null) {
      final eraserBounds = _eraserBoundsInWorld(eraserPoints);
      return rectsCanBeWithinDistance(
        eraserBounds,
        line.boundsWorld,
        eraserThickness / 2,
      );
    }

    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold = line.thickness / 2 + (eraserThickness / 2) * sigmaMax;
    final thresholdSquared = threshold * threshold;

    if (localEraserPoints.length == 1) {
      return distanceSquaredPointToSegment(
            localEraserPoints.first,
            line.start,
            line.end,
          ) <=
          thresholdSquared;
    }

    final lineBounds = Rect.fromPoints(line.start, line.end);
    final eraserBatches = buildSegmentBatches(
      localEraserPoints,
      batchSize: _eraserHitBatchSegments,
    );
    for (final batch in eraserBatches) {
      if (!rectsCanBeWithinDistance(batch.bounds, lineBounds, threshold)) {
        continue;
      }
      for (var i = batch.startSegment; i < batch.endSegmentExclusive; i++) {
        _debugEraserPreciseSegmentChecks = _debugEraserPreciseSegmentChecks + 1;
        if (distanceSquaredSegmentToSegment(
              localEraserPoints[i],
              localEraserPoints[i + 1],
              line.start,
              line.end,
            ) <=
            thresholdSquared) {
          return true;
        }
      }
    }

    return false;
  }

  bool _eraserHitsStroke(
    List<Offset> eraserPoints,
    StrokeNode stroke, {
    required double eraserThickness,
  }) {
    final inverse = stroke.transform.invert();
    if (inverse == null) {
      final eraserBounds = _eraserBoundsInWorld(eraserPoints);
      return rectsCanBeWithinDistance(
        eraserBounds,
        stroke.boundsWorld,
        eraserThickness / 2,
      );
    }

    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold = stroke.thickness / 2 + (eraserThickness / 2) * sigmaMax;
    final thresholdSquared = threshold * threshold;

    if (stroke.points.isEmpty) return false;

    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      for (final eraserPoint in localEraserPoints) {
        final delta = eraserPoint - point;
        if (delta.dx * delta.dx + delta.dy * delta.dy <= thresholdSquared) {
          return true;
        }
      }
      return false;
    }

    if (localEraserPoints.length == 1) {
      final eraserPoint = localEraserPoints.first;
      for (var i = 0; i < stroke.points.length - 1; i++) {
        if (distanceSquaredPointToSegment(
              eraserPoint,
              stroke.points[i],
              stroke.points[i + 1],
            ) <=
            thresholdSquared) {
          return true;
        }
      }
      return false;
    }

    final eraserBatches = buildSegmentBatches(
      localEraserPoints,
      batchSize: _eraserHitBatchSegments,
    );
    final strokeBatches = buildSegmentBatches(
      stroke.points,
      batchSize: _strokeHitBatchSegments,
    );
    for (final eraserBatch in eraserBatches) {
      for (final strokeBatch in strokeBatches) {
        if (!rectsCanBeWithinDistance(
          eraserBatch.bounds,
          strokeBatch.bounds,
          threshold,
        )) {
          continue;
        }
        for (
          var i = eraserBatch.startSegment;
          i < eraserBatch.endSegmentExclusive;
          i++
        ) {
          for (
            var j = strokeBatch.startSegment;
            j < strokeBatch.endSegmentExclusive;
            j++
          ) {
            _debugEraserPreciseSegmentChecks =
                _debugEraserPreciseSegmentChecks + 1;
            if (distanceSquaredSegmentToSegment(
                  localEraserPoints[i],
                  localEraserPoints[i + 1],
                  stroke.points[j],
                  stroke.points[j + 1],
                ) <=
                thresholdSquared) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  List<SceneSpatialCandidate> _querySpatialCandidatesForEraser(Rect bounds) {
    _debugEraserSpatialQueryCount = _debugEraserSpatialQueryCount + 1;
    return callbacks.querySpatialCandidates(bounds);
  }

  Rect _eraserBoundsInWorld(List<Offset> eraserPoints) {
    if (eraserPoints.length == 1) {
      return Rect.fromPoints(eraserPoints.first, eraserPoints.first);
    }
    return segmentRangeBounds(
      eraserPoints,
      segmentStart: 0,
      segmentEndExclusive: eraserPoints.length - 1,
    );
  }
}

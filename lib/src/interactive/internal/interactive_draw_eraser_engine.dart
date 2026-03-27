import 'dart:ui';

import '../../core/geometry.dart';
import '../../core/nodes.dart' show LineNode, SceneNode, StrokeNode;
import '../../core/scene_limits.dart';
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';
import '../../contract/transform2d.dart';
import 'interactive_draw_eraser_targets.dart';
import 'interactive_draw_path_buffer.dart';
import 'interactive_geometry.dart';

typedef _ProjectedEraser = ({
  List<Offset> points,
  double threshold,
  double thresholdSquared,
});

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
  final InteractiveDrawPathBuffer _pathBuffer = InteractiveDrawPathBuffer(
    softLimit: kInteractiveEraserPointsSoftLimit,
    trimTo: kInteractiveEraserPointsTrimTo,
  );
  late final InteractiveDrawEraserTargets _targets =
      InteractiveDrawEraserTargets(
        callbacks: InteractiveDrawEraserTargetsCallbacks(
          querySpatialCandidates: callbacks.querySpatialCandidates,
          resolveSpatialCandidateNode: callbacks.resolveSpatialCandidateNode,
          onSpatialQuery: _incrementSpatialQueryCount,
        ),
      );

  int _debugEraserSpatialQueryCount = 0;
  int _debugEraserPreciseSegmentChecks = 0;

  static const int _eraserHitBatchSegments = 64;
  static const int _strokeHitBatchSegments = 32;

  int get activeEraserPointsLength => _pathBuffer.length;
  int get debugEraserSpatialQueryCount => _debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks => _debugEraserPreciseSegmentChecks;

  void resetGestureState() {
    _pathBuffer.clear();
  }

  void handleDown(Offset scenePoint) {
    _pathBuffer.start(scenePoint);
  }

  void handleMove(Offset scenePoint) {
    if (!_pathBuffer.appendMovePoint(scenePoint)) return;
    callbacks.onStateChanged();
  }

  List<NodeId> commitOnUp(
    Offset scenePoint, {
    required double eraserThickness,
  }) {
    if (_pathBuffer.isEmpty) return const <NodeId>[];

    _debugEraserSpatialQueryCount = 0;
    _debugEraserPreciseSegmentChecks = 0;

    _pathBuffer.appendTerminalPoint(scenePoint, enforceSoftLimit: true);

    final deletedIds = _eraseAnnotations(
      _pathBuffer.points,
      eraserThickness: eraserThickness,
    );
    _pathBuffer.clear();
    return deletedIds;
  }

  List<NodeId> _eraseAnnotations(
    List<Offset> eraserPoints, {
    required double eraserThickness,
  }) {
    final candidates = _targets.queryDeletableTargets(
      eraserPoints,
      eraserThickness: eraserThickness,
    );
    final ids = <NodeId>[];
    for (final candidate in candidates) {
      final node = candidate.node;
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
    final projected = _projectEraserToLocal(
      eraserPoints,
      transform: line.transform,
      nodeThickness: line.thickness,
      eraserThickness: eraserThickness,
    );
    if (projected == null) {
      return _fallbackWorldBoundsHit(
        eraserPoints,
        boundsWorld: line.boundsWorld,
        eraserThickness: eraserThickness,
      );
    }
    if (_singleLocalPointHitsLine(projected, line)) return true;
    return _localEraserSegmentsHitLine(projected, line);
  }

  bool _singleLocalPointHitsLine(_ProjectedEraser projected, LineNode line) {
    if (projected.points.length != 1) return false;
    return distanceSquaredPointToSegment(
          projected.points.first,
          line.start,
          line.end,
        ) <=
        projected.thresholdSquared;
  }

  bool _localEraserSegmentsHitLine(_ProjectedEraser projected, LineNode line) {
    final lineBounds = Rect.fromPoints(line.start, line.end);
    final eraserBatches = buildSegmentBatches(
      projected.points,
      batchSize: _eraserHitBatchSegments,
    );
    for (final batch in eraserBatches) {
      if (!rectsCanBeWithinDistance(
        batch.bounds,
        lineBounds,
        projected.threshold,
      )) {
        continue;
      }
      for (var i = batch.startSegment; i < batch.endSegmentExclusive; i++) {
        _debugEraserPreciseSegmentChecks = _debugEraserPreciseSegmentChecks + 1;
        if (distanceSquaredSegmentToSegment(
              projected.points[i],
              projected.points[i + 1],
              line.start,
              line.end,
            ) <=
            projected.thresholdSquared) {
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
    final projected = _projectEraserToLocal(
      eraserPoints,
      transform: stroke.transform,
      nodeThickness: stroke.thickness,
      eraserThickness: eraserThickness,
    );
    if (projected == null) {
      return _fallbackWorldBoundsHit(
        eraserPoints,
        boundsWorld: stroke.boundsWorld,
        eraserThickness: eraserThickness,
      );
    }
    if (stroke.points.isEmpty) return false;
    if (_strokeSinglePointHit(projected, stroke)) return true;
    if (_singleEraserPointHitsStroke(projected, stroke)) return true;
    return _eraserSegmentsHitStroke(projected, stroke);
  }

  bool _strokeSinglePointHit(_ProjectedEraser projected, StrokeNode stroke) {
    if (stroke.points.length != 1) return false;
    final point = stroke.points.first;
    for (final eraserPoint in projected.points) {
      final delta = eraserPoint - point;
      if (delta.dx * delta.dx + delta.dy * delta.dy <=
          projected.thresholdSquared) {
        return true;
      }
    }
    return false;
  }

  bool _singleEraserPointHitsStroke(
    _ProjectedEraser projected,
    StrokeNode stroke,
  ) {
    if (projected.points.length != 1) return false;
    final eraserPoint = projected.points.first;
    for (var i = 0; i < stroke.points.length - 1; i++) {
      if (distanceSquaredPointToSegment(
            eraserPoint,
            stroke.points[i],
            stroke.points[i + 1],
          ) <=
          projected.thresholdSquared) {
        return true;
      }
    }
    return false;
  }

  bool _eraserSegmentsHitStroke(_ProjectedEraser projected, StrokeNode stroke) {
    final eraserBatches = buildSegmentBatches(
      projected.points,
      batchSize: _eraserHitBatchSegments,
    );
    final strokeBatches = buildSegmentBatches(
      stroke.points,
      batchSize: _strokeHitBatchSegments,
    );
    for (final eraserBatch in eraserBatches) {
      if (_eraserBatchHitsStrokeBatches(
        projected,
        stroke,
        eraserBatch,
        strokeBatches,
      )) {
        return true;
      }
    }

    return false;
  }

  bool _eraserBatchHitsStrokeBatches(
    _ProjectedEraser projected,
    StrokeNode stroke,
    SegmentBatch eraserBatch,
    List<SegmentBatch> strokeBatches,
  ) {
    for (final strokeBatch in strokeBatches) {
      if (!rectsCanBeWithinDistance(
        eraserBatch.bounds,
        strokeBatch.bounds,
        projected.threshold,
      )) {
        continue;
      }
      if (_segmentBatchPairHitsStroke(
        projected,
        stroke,
        eraserBatch,
        strokeBatch,
      )) {
        return true;
      }
    }
    return false;
  }

  bool _segmentBatchPairHitsStroke(
    _ProjectedEraser projected,
    StrokeNode stroke,
    SegmentBatch eraserBatch,
    SegmentBatch strokeBatch,
  ) {
    for (
      var i = eraserBatch.startSegment;
      i < eraserBatch.endSegmentExclusive;
      i++
    ) {
      if (_eraserSegmentHitsStrokeBatch(projected, stroke, i, strokeBatch)) {
        return true;
      }
    }
    return false;
  }

  bool _eraserSegmentHitsStrokeBatch(
    _ProjectedEraser projected,
    StrokeNode stroke,
    int eraserSegmentIndex,
    SegmentBatch strokeBatch,
  ) {
    for (
      var j = strokeBatch.startSegment;
      j < strokeBatch.endSegmentExclusive;
      j++
    ) {
      _debugEraserPreciseSegmentChecks = _debugEraserPreciseSegmentChecks + 1;
      if (distanceSquaredSegmentToSegment(
            projected.points[eraserSegmentIndex],
            projected.points[eraserSegmentIndex + 1],
            stroke.points[j],
            stroke.points[j + 1],
          ) <=
          projected.thresholdSquared) {
        return true;
      }
    }
    return false;
  }

  _ProjectedEraser? _projectEraserToLocal(
    List<Offset> eraserPoints, {
    required Transform2D transform,
    required double nodeThickness,
    required double eraserThickness,
  }) {
    final inverse = transform.invert();
    if (inverse == null) return null;

    final points = eraserPoints
        .map<Offset>(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold = nodeThickness / 2 + (eraserThickness / 2) * sigmaMax;
    return (
      points: points,
      threshold: threshold,
      thresholdSquared: threshold * threshold,
    );
  }

  bool _fallbackWorldBoundsHit(
    List<Offset> eraserPoints, {
    required Rect boundsWorld,
    required double eraserThickness,
  }) {
    return rectsCanBeWithinDistance(
      _eraserBoundsInWorld(eraserPoints),
      boundsWorld,
      eraserThickness / 2,
    );
  }

  void _incrementSpatialQueryCount() {
    _debugEraserSpatialQueryCount = _debugEraserSpatialQueryCount + 1;
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

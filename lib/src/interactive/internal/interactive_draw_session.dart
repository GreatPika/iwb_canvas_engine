import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/geometry.dart';
import '../../core/hit_test.dart';
import '../../core/input_sampling.dart';
import '../../core/interaction_types.dart';
import '../../core/nodes.dart' show LineNode, SceneNode, StrokeNode;
import '../../core/pointer_input.dart';
import '../../core/scene_limits.dart';
import '../../core/scene_spatial_index.dart';
import '../../public/snapshot.dart';
import 'interactive_geometry.dart';

class InteractiveDrawSessionCallbacks {
  const InteractiveDrawSessionCallbacks({
    required this.onStateChanged,
    required this.emitAction,
    required this.writeDrawStroke,
    required this.writeDrawLineFromWorldSegment,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeEraseNodes,
  });

  final VoidCallback onStateChanged;
  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;
  final NodeId Function({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  })
  writeDrawStroke;
  final NodeId Function({required Offset start, required Offset end})
  writeDrawLineFromWorldSegment;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final int Function(Iterable<NodeId> ids) writeEraseNodes;
}

class InteractiveDrawSession {
  InteractiveDrawSession({required this.callbacks});

  final InteractiveDrawSessionCallbacks callbacks;

  int? _activePointerId;
  Offset? _downScene;
  bool _moved = false;

  final List<Offset> _activeStrokePoints = <Offset>[];
  late final UnmodifiableListView<Offset> _activeStrokePointsView =
      UnmodifiableListView<Offset>(_activeStrokePoints);

  final List<Offset> _activeEraserPoints = <Offset>[];

  Offset? _activeLinePreviewStart;
  Offset? _activeLinePreviewEnd;

  Offset? _pendingLineStart;
  int? _pendingLineTimestampMs;
  Timer? _pendingLineTimer;

  int _debugEraserSpatialQueryCount = 0;
  int _debugEraserPreciseSegmentChecks = 0;

  static const Duration _pendingLineTimeout = Duration(seconds: 10);
  static const int _eraserQueryBatchSegments = 64;
  static const int _eraserHitBatchSegments = 64;
  static const int _strokeHitBatchSegments = 32;

  bool get hasActivePointer => _activePointerId != null;

  Offset? get pendingLineStart => _pendingLineStart;
  int? get pendingLineTimestampMs => _pendingLineTimestampMs;
  bool get hasPendingLineStart => _pendingLineStart != null;

  List<Offset> get activeStrokePreviewPoints => _activeStrokePointsView;
  bool get hasActiveStrokePoints => _activeStrokePoints.isNotEmpty;

  Offset? get activeLinePreviewStart => _activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _activeLinePreviewEnd;

  int get activeEraserPointsLength => _activeEraserPoints.length;
  int get debugEraserSpatialQueryCount => _debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks => _debugEraserPreciseSegmentChecks;

  void handlePointer(
    PointerSample sample,
    Offset scenePoint, {
    required DrawTool drawTool,
    required Color drawColor,
    required double penThickness,
    required double highlighterThickness,
    required double lineThickness,
    required double eraserThickness,
    required double highlighterOpacity,
    required double dragStartSlop,
  }) {
    if (_activePointerId != null && _activePointerId != sample.pointerId) {
      return;
    }

    switch (sample.phase) {
      case PointerPhase.down:
        _handleDown(sample.pointerId, scenePoint, drawTool: drawTool);
        break;
      case PointerPhase.move:
        _handleMove(
          sample.pointerId,
          scenePoint,
          drawTool: drawTool,
          dragStartSlop: dragStartSlop,
        );
        break;
      case PointerPhase.up:
        _handleUp(
          sample.pointerId,
          sample.timestampMs,
          scenePoint,
          drawTool: drawTool,
          drawColor: drawColor,
          penThickness: penThickness,
          highlighterThickness: highlighterThickness,
          lineThickness: lineThickness,
          eraserThickness: eraserThickness,
          highlighterOpacity: highlighterOpacity,
          dragStartSlop: dragStartSlop,
        );
        break;
      case PointerPhase.cancel:
        clearPendingLine();
        resetGestureState();
        callbacks.onStateChanged();
        break;
    }
  }

  void resetGestureState() {
    _activePointerId = null;
    _downScene = null;
    _moved = false;
    _activeStrokePoints.clear();
    _activeEraserPoints.clear();
    _setActiveLinePreview(null, null);
  }

  void clearPendingLine() {
    _setPendingLineStart(null, null);
  }

  void dispose() {
    _pendingLineTimer?.cancel();
    _pendingLineTimer = null;
  }

  void _handleDown(
    int pointerId,
    Offset scenePoint, {
    required DrawTool drawTool,
  }) {
    _activePointerId = pointerId;
    _downScene = scenePoint;
    _moved = false;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _activeStrokePoints
          ..clear()
          ..add(scenePoint);
        break;
      case DrawTool.line:
        _setActiveLinePreview(null, null);
        break;
      case DrawTool.eraser:
        _activeEraserPoints
          ..clear()
          ..add(scenePoint);
        break;
    }
  }

  void _handleMove(
    int pointerId,
    Offset scenePoint, {
    required DrawTool drawTool,
    required double dragStartSlop,
  }) {
    if (_activePointerId != pointerId) return;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        if (_activeStrokePoints.isNotEmpty &&
            isDistanceAtLeast(
              _activeStrokePoints.last,
              scenePoint,
              kInputDecimationMinStepScene,
            )) {
          _activeStrokePoints.add(scenePoint);
          enforceGestureBufferSoftLimit(
            _activeStrokePoints,
            softLimit: kInteractiveStrokePointsSoftLimit,
            trimTo: kInteractiveStrokePointsTrimTo,
          );
          callbacks.onStateChanged();
        }
        break;
      case DrawTool.line:
        if (_downScene == null) return;
        if (!_moved &&
            isDistanceAtMost(_downScene!, scenePoint, dragStartSlop)) {
          return;
        }
        _moved = true;
        if (_pendingLineStart != null) {
          clearPendingLine();
        }
        _setActiveLinePreview(_downScene, scenePoint);
        callbacks.onStateChanged();
        break;
      case DrawTool.eraser:
        if (_activeEraserPoints.isEmpty) return;
        if (isDistanceAtLeast(
          _activeEraserPoints.last,
          scenePoint,
          kInputDecimationMinStepScene,
        )) {
          _activeEraserPoints.add(scenePoint);
          enforceGestureBufferSoftLimit(
            _activeEraserPoints,
            softLimit: kInteractiveEraserPointsSoftLimit,
            trimTo: kInteractiveEraserPointsTrimTo,
          );
          callbacks.onStateChanged();
        }
        break;
    }
  }

  void _handleUp(
    int pointerId,
    int timestampMs,
    Offset scenePoint, {
    required DrawTool drawTool,
    required Color drawColor,
    required double penThickness,
    required double highlighterThickness,
    required double lineThickness,
    required double eraserThickness,
    required double highlighterOpacity,
    required double dragStartSlop,
  }) {
    if (_activePointerId != pointerId) return;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _commitStroke(
          timestampMs,
          scenePoint,
          drawTool: drawTool,
          drawColor: drawColor,
          penThickness: penThickness,
          highlighterThickness: highlighterThickness,
          highlighterOpacity: highlighterOpacity,
        );
        break;
      case DrawTool.line:
        _commitLine(
          timestampMs,
          scenePoint,
          drawTool: drawTool,
          drawColor: drawColor,
          lineThickness: lineThickness,
          dragStartSlop: dragStartSlop,
        );
        break;
      case DrawTool.eraser:
        _commitEraser(
          timestampMs,
          scenePoint,
          eraserThickness: eraserThickness,
        );
        break;
    }

    _activePointerId = null;
    _downScene = null;
    _moved = false;
    _setActiveLinePreview(null, null);
  }

  void _commitStroke(
    int timestampMs,
    Offset scenePoint, {
    required DrawTool drawTool,
    required Color drawColor,
    required double penThickness,
    required double highlighterThickness,
    required double highlighterOpacity,
  }) {
    if (_activeStrokePoints.isEmpty) return;
    if (isDistanceGreaterThan(_activeStrokePoints.last, scenePoint, 0)) {
      _activeStrokePoints.add(scenePoint);
    }

    final committedPoints = resamplePointsToLimit(
      _activeStrokePoints,
      limit: kMaxStrokePointsPerNode,
    );
    final strokeId = callbacks.writeDrawStroke(
      points: committedPoints,
      thickness: drawTool == DrawTool.highlighter
          ? highlighterThickness
          : penThickness,
      color: drawColor,
      opacity: drawTool == DrawTool.highlighter ? highlighterOpacity : 1,
    );

    callbacks.emitAction(
      drawTool == DrawTool.highlighter
          ? ActionType.drawHighlighter
          : ActionType.drawStroke,
      <NodeId>[strokeId],
      timestampMs,
      payload: <String, Object?>{
        'tool': drawTool.name,
        'color': drawColor.toARGB32(),
        'thickness': drawTool == DrawTool.highlighter
            ? highlighterThickness
            : penThickness,
      },
    );

    _activeStrokePoints.clear();
  }

  void _commitLine(
    int timestampMs,
    Offset scenePoint, {
    required DrawTool drawTool,
    required Color drawColor,
    required double lineThickness,
    required double dragStartSlop,
  }) {
    final down = _downScene;
    if (down == null) return;

    final isTap = isDistanceAtMost(down, scenePoint, dragStartSlop);
    if (!isTap || _moved) {
      final lineId = callbacks.writeDrawLineFromWorldSegment(
        start: down,
        end: scenePoint,
      );
      callbacks.emitAction(
        ActionType.drawLine,
        <NodeId>[lineId],
        timestampMs,
        payload: <String, Object?>{
          'tool': drawTool.name,
          'color': drawColor.toARGB32(),
          'thickness': lineThickness,
        },
      );
      clearPendingLine();
      return;
    }

    if (_pendingLineStart == null) {
      _setPendingLineStart(scenePoint, timestampMs);
      return;
    }

    final start = _pendingLineStart!;
    clearPendingLine();
    final lineId = callbacks.writeDrawLineFromWorldSegment(
      start: start,
      end: scenePoint,
    );
    callbacks.emitAction(
      ActionType.drawLine,
      <NodeId>[lineId],
      timestampMs,
      payload: <String, Object?>{
        'tool': drawTool.name,
        'color': drawColor.toARGB32(),
        'thickness': lineThickness,
      },
    );
  }

  void _commitEraser(
    int timestampMs,
    Offset scenePoint, {
    required double eraserThickness,
  }) {
    if (_activeEraserPoints.isEmpty) return;

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

    if (deletedIds.isEmpty) return;

    callbacks.emitAction(
      ActionType.erase,
      deletedIds,
      timestampMs,
      payload: <String, Object?>{'eraserThickness': eraserThickness},
    );
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
    if (inverse == null) return false;

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
    if (inverse == null) return false;

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

  void _setActiveLinePreview(Offset? start, Offset? end) {
    if (_activeLinePreviewStart == start && _activeLinePreviewEnd == end) {
      return;
    }
    _activeLinePreviewStart = start;
    _activeLinePreviewEnd = end;
    callbacks.onStateChanged();
  }

  void _setPendingLineStart(Offset? start, int? timestampMs) {
    if (_pendingLineStart == start && _pendingLineTimestampMs == timestampMs) {
      return;
    }
    _pendingLineTimer?.cancel();
    _pendingLineTimer = null;
    _pendingLineStart = start;
    _pendingLineTimestampMs = timestampMs;
    if (_pendingLineStart != null) {
      _pendingLineTimer = Timer(_pendingLineTimeout, clearPendingLine);
    }
    callbacks.onStateChanged();
  }
}

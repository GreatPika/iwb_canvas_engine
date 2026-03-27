import '../../core/geometry.dart';
import '../../core/nodes.dart' show StrokeNode;
import 'interactive_draw_eraser_projection.dart';
import 'interactive_geometry.dart';

class InteractiveDrawEraserStrokeHit {
  const InteractiveDrawEraserStrokeHit({required this.onPreciseSegmentCheck});

  final void Function() onPreciseSegmentCheck;

  static const int _eraserHitBatchSegments = 64;
  static const int _strokeHitBatchSegments = 32;

  bool hitsProjectedStroke(
    InteractiveDrawProjectedEraser projected,
    StrokeNode stroke,
  ) {
    if (stroke.points.isEmpty) return false;
    if (_strokeSinglePointHit(projected, stroke)) return true;
    if (_singleEraserPointHitsStroke(projected, stroke)) return true;
    return _eraserSegmentsHitStroke(projected, stroke);
  }

  bool _strokeSinglePointHit(
    InteractiveDrawProjectedEraser projected,
    StrokeNode stroke,
  ) {
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
    InteractiveDrawProjectedEraser projected,
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

  bool _eraserSegmentsHitStroke(
    InteractiveDrawProjectedEraser projected,
    StrokeNode stroke,
  ) {
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
    InteractiveDrawProjectedEraser projected,
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
    InteractiveDrawProjectedEraser projected,
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
    InteractiveDrawProjectedEraser projected,
    StrokeNode stroke,
    int eraserSegmentIndex,
    SegmentBatch strokeBatch,
  ) {
    for (
      var j = strokeBatch.startSegment;
      j < strokeBatch.endSegmentExclusive;
      j++
    ) {
      onPreciseSegmentCheck();
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
}

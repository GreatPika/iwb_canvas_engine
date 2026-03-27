import 'dart:ui';

import '../../core/geometry.dart';
import '../../core/nodes.dart' show LineNode;
import 'interactive_draw_eraser_projection.dart';
import 'interactive_geometry.dart';

class InteractiveDrawEraserLineHit {
  const InteractiveDrawEraserLineHit({required this.onPreciseSegmentCheck});

  final void Function() onPreciseSegmentCheck;

  static const int _eraserHitBatchSegments = 64;

  bool hitsProjectedLine(
    InteractiveDrawProjectedEraser projected,
    LineNode line,
  ) {
    if (_singleLocalPointHitsLine(projected, line)) return true;
    return _localEraserSegmentsHitLine(projected, line);
  }

  bool _singleLocalPointHitsLine(
    InteractiveDrawProjectedEraser projected,
    LineNode line,
  ) {
    if (projected.points.length != 1) return false;
    return distanceSquaredPointToSegment(
          projected.points.first,
          line.start,
          line.end,
        ) <=
        projected.thresholdSquared;
  }

  bool _localEraserSegmentsHitLine(
    InteractiveDrawProjectedEraser projected,
    LineNode line,
  ) {
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
        onPreciseSegmentCheck();
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
}

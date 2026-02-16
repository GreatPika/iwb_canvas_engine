import 'dart:math' as math;
import 'dart:ui';

class SegmentBatch {
  const SegmentBatch({
    required this.startSegment,
    required this.endSegmentExclusive,
    required this.bounds,
  });

  final int startSegment;
  final int endSegmentExclusive;
  final Rect bounds;
}

List<Offset> resamplePointsToLimit(List<Offset> points, {required int limit}) {
  if (points.length <= limit) {
    return points;
  }
  final sourceCount = points.length;
  return List<Offset>.generate(limit, (i) {
    final sourceIndex = (i * (sourceCount - 1)) ~/ (limit - 1);
    return points[sourceIndex];
  }, growable: false);
}

// Active gesture buffers are intentionally separate from committed scene state
// because they drive live preview and final commit geometry.
void enforceGestureBufferSoftLimit(
  List<Offset> points, {
  required int softLimit,
  required int trimTo,
}) {
  if (softLimit < 2) {
    throw ArgumentError.value(
      softLimit,
      'softLimit',
      'Must be >= 2 for endpoint-preserving resample.',
    );
  }
  if (trimTo < 2) {
    throw ArgumentError.value(
      trimTo,
      'trimTo',
      'Must be >= 2 for endpoint-preserving resample.',
    );
  }
  if (trimTo >= softLimit) {
    throw ArgumentError.value(
      trimTo,
      'trimTo',
      'Must be < softLimit to preserve hysteresis.',
    );
  }
  assert(
    softLimit >= 2,
    'softLimit must be >= 2 for endpoint-preserving resample.',
  );
  assert(trimTo >= 2, 'trimTo must be >= 2 for endpoint-preserving resample.');
  assert(
    trimTo < softLimit,
    'trimTo must be < softLimit to preserve hysteresis.',
  );
  if (points.length <= softLimit) {
    return;
  }
  final trimmed = resamplePointsToLimit(points, limit: trimTo);
  points
    ..clear()
    ..addAll(trimmed);
}

List<SegmentBatch> buildSegmentBatches(
  List<Offset> points, {
  required int batchSize,
}) {
  if (points.length <= 1) return const <SegmentBatch>[];
  final batches = <SegmentBatch>[];
  final segmentCount = points.length - 1;
  for (
    var segmentStart = 0;
    segmentStart < segmentCount;
    segmentStart += batchSize
  ) {
    final segmentEndExclusive = math.min(
      segmentStart + batchSize,
      segmentCount,
    );
    batches.add(
      SegmentBatch(
        startSegment: segmentStart,
        endSegmentExclusive: segmentEndExclusive,
        bounds: segmentRangeBounds(
          points,
          segmentStart: segmentStart,
          segmentEndExclusive: segmentEndExclusive,
        ),
      ),
    );
  }
  return batches;
}

Rect segmentRangeBounds(
  List<Offset> points, {
  required int segmentStart,
  required int segmentEndExclusive,
}) {
  assert(points.length >= 2);
  assert(segmentStart >= 0);
  assert(segmentEndExclusive > segmentStart);
  assert(segmentEndExclusive <= points.length - 1);
  var minX = points[segmentStart].dx;
  var minY = points[segmentStart].dy;
  var maxX = minX;
  var maxY = minY;
  for (var i = segmentStart; i < segmentEndExclusive; i++) {
    final a = points[i];
    final b = points[i + 1];
    minX = math.min(minX, math.min(a.dx, b.dx));
    minY = math.min(minY, math.min(a.dy, b.dy));
    maxX = math.max(maxX, math.max(a.dx, b.dx));
    maxY = math.max(maxY, math.max(a.dy, b.dy));
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

bool rectsCanBeWithinDistance(Rect left, Rect right, double distance) {
  final safeDistance = distance.isFinite ? math.max(0, distance) : 0.0;
  final dx = left.right < right.left
      ? right.left - left.right
      : right.right < left.left
      ? left.left - right.right
      : 0.0;
  final dy = left.bottom < right.top
      ? right.top - left.bottom
      : right.bottom < left.top
      ? left.top - right.bottom
      : 0.0;
  return dx * dx + dy * dy <= safeDistance * safeDistance;
}

double maxSingularValue2x2(double a, double b, double c, double d) {
  final t = a * a + b * b + c * c + d * d;
  final det = a * d - b * c;
  final discSquared = t * t - 4 * det * det;
  final disc = math.sqrt(math.max(0, discSquared));
  final lambdaMax = (t + disc) / 2;
  return math.sqrt(math.max(0, lambdaMax));
}

import 'dart:math' as math;
import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import 'geometry_policy.dart';

typedef FrameElementResolver =
    FrameElementFacts? Function(FrameElementHandle handle);

final class HitTestResult {
  const HitTestResult({required this.id, required this.orderToken});

  final CanvasElementId id;
  final int orderToken;
}

// Point, marquee, eraser, and context hit checks stay in one geometry policy so
// every interaction path shares the same eligibility and exact-hit rules.
// ignore: weighted-methods-per-class
final class HitTestPolicy {
  const HitTestPolicy({this.geometryPolicy = const GeometryPolicy()});

  final GeometryPolicy geometryPolicy;

  CanvasElementId? topmostHit({
    required Offset point,
    required Iterable<FrameElementHandle> candidates,
    required FrameElementResolver resolve,
  }) {
    return topmostHitResult(
      point: point,
      candidates: candidates,
      resolve: resolve,
    )?.id;
  }

  HitTestResult? topmostHitResult({
    required Offset point,
    required Iterable<FrameElementHandle> candidates,
    required FrameElementResolver resolve,
  }) {
    final ordered = candidates.toList(growable: false)
      ..sort((left, right) => right.orderToken.compareTo(left.orderToken));
    for (final handle in ordered) {
      final facts = resolve(handle);
      if (facts == null ||
          facts.locationKind == FrameElementLocationKind.background ||
          !exactHit(point: point, facts: facts)) {
        continue;
      }

      return HitTestResult(id: facts.id, orderToken: handle.orderToken);
    }

    return null;
  }

  CanvasElementId? topmostContextHit({
    required Offset point,
    required Iterable<FrameElementHandle> candidates,
    required FrameElementResolver resolve,
  }) {
    final ordered = candidates.toList(growable: false)
      ..sort((left, right) => right.orderToken.compareTo(left.orderToken));
    for (final handle in ordered) {
      final facts = resolve(handle);
      if (facts == null ||
          facts.locationKind == FrameElementLocationKind.background ||
          !exactContextHit(point: point, facts: facts)) {
        continue;
      }

      return facts.id;
    }

    return null;
  }

  bool exactHit({required Offset point, required FrameElementFacts facts}) {
    if (!geometryPolicy.isHitEligible(facts, point) ||
        _needsInverseHit(facts.kind) && !facts.transform.isInvertible) {
      return false;
    }
    final bounds = geometryPolicy.boundsFor(facts).hitBoundsWorld;
    if (!_rectContainsPointInclusive(bounds, point)) {
      return false;
    }

    return switch (facts.kind) {
      CanvasElementKind.image ||
      CanvasElementKind.rect ||
      CanvasElementKind.text => _hitBox(point, facts),
      CanvasElementKind.line => _hitLine(point, facts),
      CanvasElementKind.stroke => _hitStroke(point, facts),
      CanvasElementKind.path => _hitPath(point, facts),
    };
  }

  // Context hit eligibility intentionally differs from selectable hit testing:
  // context requests may target non-selectable visible content, but not
  // background; keeping the exact geometry switch here prevents drift.
  // ignore: cyclomatic-complexity
  bool exactContextHit({
    required Offset point,
    required FrameElementFacts facts,
  }) {
    if (!isFiniteOffset(point) ||
        !facts.isVisible ||
        facts.locationKind != FrameElementLocationKind.content ||
        !isFiniteTransform(facts.transform) ||
        _needsInverseHit(facts.kind) && !facts.transform.isInvertible) {
      return false;
    }
    final bounds = geometryPolicy.boundsFor(facts).hitBoundsWorld;
    if (!_rectContainsPointInclusive(bounds, point)) {
      return false;
    }

    return switch (facts.kind) {
      CanvasElementKind.image ||
      CanvasElementKind.rect ||
      CanvasElementKind.text => _hitBox(point, facts),
      CanvasElementKind.line => _hitLine(point, facts),
      CanvasElementKind.stroke => _hitStroke(point, facts),
      CanvasElementKind.path => _hitPath(point, facts),
    };
  }

  bool exactMarquee({required Rect marquee, required FrameElementFacts facts}) {
    if (!geometryPolicy.isMarqueeCandidate(facts, marquee)) {
      return false;
    }
    final normalized = _normalizeRect(marquee);

    return switch (facts.kind) {
      CanvasElementKind.image ||
      CanvasElementKind.rect ||
      CanvasElementKind.text => _boxIntersectsRect(
        facts,
        normalized,
        geometryPolicy,
      ),
      CanvasElementKind.line => _lineIntersectsRect(facts, normalized),
      CanvasElementKind.stroke => _strokeIntersectsRect(facts, normalized),
      CanvasElementKind.path => _pathIntersectsRect(facts, normalized),
    };
  }

  bool exactEraserHit({
    required EraserCorridor corridor,
    required FrameElementFacts facts,
  }) {
    if (!_isEraserEligible(corridor, facts, geometryPolicy)) {
      return false;
    }

    return switch (facts.kind) {
      CanvasElementKind.image ||
      CanvasElementKind.rect ||
      CanvasElementKind.text => _eraserHitsBox(corridor, facts, geometryPolicy),
      CanvasElementKind.line => _eraserHitsLine(corridor, facts),
      CanvasElementKind.stroke => _eraserHitsStroke(corridor, facts),
      CanvasElementKind.path => _eraserHitsPath(corridor, facts),
    };
  }
}

bool _needsInverseHit(CanvasElementKind kind) {
  return switch (kind) {
    CanvasElementKind.image ||
    CanvasElementKind.rect ||
    CanvasElementKind.text ||
    CanvasElementKind.path => true,
    CanvasElementKind.line || CanvasElementKind.stroke => false,
  };
}

bool _hitBox(Offset point, FrameElementFacts facts) {
  final inverse = facts.transform.invert();
  if (inverse == null) {
    return false;
  }
  final localPoint = inverse.applyToPoint(point);
  final localBounds = const GeometryPolicy().boundsFor(facts).localBounds;

  final inflated = _inflateLocalBoundsForScenePadding(
    localBounds,
    inverse,
    _scenePadding(facts.hitPadding),
  );

  return _rectContainsPointInclusive(inflated, localPoint);
}

bool _isEraserEligible(
  EraserCorridor corridor,
  FrameElementFacts facts,
  GeometryPolicy geometryPolicy,
) {
  if (corridor.points.isEmpty ||
      corridor.envelopeWorld == Rect.zero ||
      !facts.isVisible ||
      !facts.isDeletable ||
      facts.locationKind == FrameElementLocationKind.background ||
      !isFiniteTransform(facts.transform) ||
      _needsInverseHit(facts.kind) && !facts.transform.isInvertible) {
    return false;
  }

  return _rectsOverlapInclusive(
    geometryPolicy.boundsFor(facts).paintBoundsWorld,
    corridor.envelopeWorld,
  );
}

bool _eraserHitsBox(
  EraserCorridor corridor,
  FrameElementFacts facts,
  GeometryPolicy geometryPolicy,
) {
  final bounds = geometryPolicy.boundsFor(facts).localBounds;
  if (bounds == Rect.zero) {
    return false;
  }

  return _corridorIntersectsQuad(
    corridor,
    _transformedRectCorners(facts.transform, bounds),
  );
}

bool _corridorIntersectsQuad(EraserCorridor corridor, List<Offset> quad) {
  return corridor.points.any(
        (point) => _convexQuadContainsPoint(quad, point),
      ) ||
      _singlePointCorridorTouchesQuad(corridor, quad) ||
      quad.any(
        (point) => _pointTouchesCorridor(point, corridor, extraRadius: 0),
      ) ||
      _corridorSegmentsTouchQuad(
        corridor.points,
        quad,
        radius: corridor.exactRadiusWorld,
      );
}

bool _singlePointCorridorTouchesQuad(
  EraserCorridor corridor,
  List<Offset> quad,
) {
  if (corridor.points.length != 1) {
    return false;
  }
  final point = corridor.points.first;
  final radiusSquared = corridor.exactRadiusWorld * corridor.exactRadiusWorld;
  for (var index = 0; index < quad.length; index += 1) {
    if (distanceSquaredPointToSegment(
          point,
          quad[index],
          quad[(index + 1) % quad.length],
        ) <=
        radiusSquared) {
      return true;
    }
  }

  return false;
}

bool _corridorSegmentsTouchQuad(
  List<Offset> points,
  List<Offset> quad, {
  required double radius,
}) {
  if (points.length < 2) {
    return false;
  }
  for (var pointIndex = 0; pointIndex < points.length - 1; pointIndex += 1) {
    for (var quadIndex = 0; quadIndex < quad.length; quadIndex += 1) {
      if (_segmentsTouch(
        _Segment(points[pointIndex], points[pointIndex + 1]),
        _Segment(quad[quadIndex], quad[(quadIndex + 1) % quad.length]),
        radius: radius,
      )) {
        return true;
      }
    }
  }

  return false;
}

bool _boxIntersectsRect(
  FrameElementFacts facts,
  Rect rect,
  GeometryPolicy geometryPolicy,
) {
  final bounds = geometryPolicy.boundsFor(facts).localBounds;
  if (bounds == Rect.zero) {
    return false;
  }
  final quad = _transformedRectCorners(facts.transform, bounds);

  return quad.any(rect.contains) ||
      _rectCorners(
        rect,
      ).any((point) => _convexQuadContainsPoint(quad, point)) ||
      _quadEdgesIntersectRect(quad, rect);
}

List<Offset> _transformedRectCorners(CanvasTransform transform, Rect rect) {
  return [
    transform.applyToPoint(rect.topLeft),
    transform.applyToPoint(rect.topRight),
    transform.applyToPoint(rect.bottomRight),
    transform.applyToPoint(rect.bottomLeft),
  ];
}

List<Offset> _rectCorners(Rect rect) {
  return [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft];
}

bool _convexQuadContainsPoint(List<Offset> quad, Offset point) {
  var hasNegative = false;
  var hasPositive = false;
  for (var index = 0; index < quad.length; index += 1) {
    final start = quad[index];
    final end = quad[(index + 1) % quad.length];
    final orientation = _orientation(start, end, point);
    hasNegative = hasNegative || orientation < 0;
    hasPositive = hasPositive || orientation > 0;
    if (hasNegative && hasPositive) {
      return false;
    }
  }

  return true;
}

bool _quadEdgesIntersectRect(List<Offset> quad, Rect rect) {
  for (var index = 0; index < quad.length; index += 1) {
    if (_segmentIntersectsInflatedRect(
      quad[index],
      quad[(index + 1) % quad.length],
      rect,
    )) {
      return true;
    }
  }

  return false;
}

bool _eraserHitsLine(EraserCorridor corridor, FrameElementFacts facts) {
  final start = facts.start;
  final end = facts.end;
  if (start == null ||
      end == null ||
      !isFiniteOffset(start) ||
      !isFiniteOffset(end)) {
    return false;
  }

  return _segmentTouchesCorridor(
    facts.transform.applyToPoint(start),
    facts.transform.applyToPoint(end),
    corridor,
    extraRadius: _worldPaintStrokeRadius(facts),
  );
}

bool _eraserHitsStroke(EraserCorridor corridor, FrameElementFacts facts) {
  if (facts.points.isEmpty ||
      facts.points.any((point) => !isFiniteOffset(point))) {
    return false;
  }
  final radius = _worldPaintStrokeRadius(facts);
  if (facts.points.length == 1) {
    return _pointTouchesCorridor(
      facts.transform.applyToPoint(facts.points.first),
      corridor,
      extraRadius: radius,
    );
  }
  for (var index = 0; index < facts.points.length - 1; index += 1) {
    if (_segmentTouchesCorridor(
      facts.transform.applyToPoint(facts.points[index]),
      facts.transform.applyToPoint(facts.points[index + 1]),
      corridor,
      extraRadius: radius,
    )) {
      return true;
    }
  }

  return false;
}

bool _hitLine(Offset point, FrameElementFacts facts) {
  final start = facts.start;
  final end = facts.end;
  if (start == null ||
      end == null ||
      !isFiniteOffset(start) ||
      !isFiniteOffset(end)) {
    return false;
  }
  final worldStart = facts.transform.applyToPoint(start);
  final worldEnd = facts.transform.applyToPoint(end);
  final radius = _worldStrokeRadius(facts);

  return distanceSquaredPointToSegment(point, worldStart, worldEnd) <=
      radius * radius;
}

bool _hitStroke(Offset point, FrameElementFacts facts) {
  if (facts.points.isEmpty ||
      facts.points.any((point) => !isFiniteOffset(point))) {
    return false;
  }
  final radius = _worldStrokeRadius(facts);
  if (facts.points.length == 1) {
    final worldPoint = facts.transform.applyToPoint(facts.points.first);
    final delta = point - worldPoint;

    return delta.dx * delta.dx + delta.dy * delta.dy <= radius * radius;
  }
  for (var index = 0; index < facts.points.length - 1; index += 1) {
    final start = facts.transform.applyToPoint(facts.points[index]);
    final end = facts.transform.applyToPoint(facts.points[index + 1]);
    if (distanceSquaredPointToSegment(point, start, end) <= radius * radius) {
      return true;
    }
  }

  return false;
}

bool _eraserHitsPath(EraserCorridor corridor, FrameElementFacts facts) {
  final parsed = ParsedSvgPath.parse(
    facts.svgPathData ?? '',
    fillRule: facts.fillRule ?? CanvasPathFillRule.nonZero,
  );
  final inverse = facts.transform.invert();
  if (parsed == null || inverse == null) {
    return false;
  }
  final localPoints = corridor.points
      .map(inverse.applyToPoint)
      .toList(growable: false);
  final radius = _sceneScalarToLocalMax(inverse, corridor.exactRadiusWorld);

  return _eraserHitsPathFill(parsed.path, localPoints, radius, facts) ||
      _eraserHitsPathStroke(parsed.path, localPoints, radius, facts);
}

bool _eraserHitsPathFill(
  Path path,
  List<Offset> points,
  double radius,
  FrameElementFacts facts,
) {
  if (facts.fillColor == null) {
    return false;
  }

  return points.any(path.contains) ||
      _pathMetricsTouchPolyline(path, points, radius, forceClosed: true);
}

bool _eraserHitsPathStroke(
  Path path,
  List<Offset> points,
  double radius,
  FrameElementFacts facts,
) {
  final strokeWidth = facts.strokeWidth ?? 0;
  if (facts.strokeColor == null || strokeWidth <= 0) {
    return false;
  }

  return _pathMetricsTouchPolyline(
    path,
    points,
    radius + strokeWidth / 2,
    forceClosed: false,
  );
}

bool _hitPath(Offset point, FrameElementFacts facts) {
  final parsed = ParsedSvgPath.parse(
    facts.svgPathData ?? '',
    fillRule: facts.fillRule ?? CanvasPathFillRule.nonZero,
  );
  final inverse = facts.transform.invert();
  if (parsed == null || inverse == null) {
    return false;
  }
  final localPoint = inverse.applyToPoint(point);
  return _hitPathFill(parsed.path, localPoint, facts) ||
      _hitPathStrokePaint(parsed.path, localPoint, inverse, facts);
}

bool _hitPathFill(Path path, Offset localPoint, FrameElementFacts facts) {
  if (facts.fillColor == null) {
    return false;
  }
  if (path.contains(localPoint)) {
    return true;
  }
  final inverse = facts.transform.invert();
  if (inverse == null) {
    return false;
  }
  final paddingRadius = _sceneScalarToLocalMax(
    inverse,
    _scenePadding(facts.hitPadding),
  );

  return _hitPathStroke(path, localPoint, paddingRadius, forceClosed: true);
}

bool _hitPathStrokePaint(
  Path path,
  Offset localPoint,
  CanvasTransform inverse,
  FrameElementFacts facts,
) {
  final strokeWidth = facts.strokeWidth ?? 0;
  if (facts.strokeColor == null || strokeWidth <= 0) {
    return false;
  }
  final radius =
      strokeWidth / 2 +
      _sceneScalarToLocalMax(inverse, _scenePadding(facts.hitPadding));

  return _hitPathStroke(path, localPoint, radius, forceClosed: false);
}

bool _hitPathStroke(
  Path path,
  Offset point,
  double radius, {
  required bool forceClosed,
}) {
  final radiusSquared = radius * radius;
  for (final metric in path.computeMetrics(forceClosed: forceClosed)) {
    final sampleCount = math.min(
      kCanvasMaxPathHitSamplesPerMetric,
      math.max(1, (metric.length / math.max(0.5, radius * 0.5)).ceil()),
    );
    var previous = metric.getTangentForOffset(0)?.position;
    for (var sample = 1; sample <= sampleCount; sample += 1) {
      final offset = metric.length * sample / sampleCount;
      final current = metric.getTangentForOffset(offset)?.position;
      if (previous != null &&
          current != null &&
          distanceSquaredPointToSegment(point, previous, current) <=
              radiusSquared) {
        return true;
      }
      previous = current;
    }
  }

  return false;
}

bool _pathMetricsTouchPolyline(
  Path path,
  List<Offset> points,
  double radius, {
  required bool forceClosed,
}) {
  for (final metric in path.computeMetrics(forceClosed: forceClosed)) {
    if (_metricTouchesPolyline(metric, points, radius)) {
      return true;
    }
  }

  return false;
}

bool _metricTouchesPolyline(
  PathMetric metric,
  List<Offset> points,
  double radius,
) {
  final sampleCount = math.min(
    kCanvasMaxPathHitSamplesPerMetric,
    math.max(1, (metric.length / math.max(0.5, radius * 0.5)).ceil()),
  );
  var previous = metric.getTangentForOffset(0)?.position;
  for (var sample = 1; sample <= sampleCount; sample += 1) {
    final current = metric
        .getTangentForOffset(metric.length * sample / sampleCount)
        ?.position;
    if (previous != null &&
        current != null &&
        _segmentTouchesPolyline(previous, current, points, radius)) {
      return true;
    }
    previous = current;
  }

  return false;
}

bool _segmentTouchesPolyline(
  Offset start,
  Offset end,
  List<Offset> points,
  double radius,
) {
  if (points.length == 1) {
    return distanceSquaredPointToSegment(points.first, start, end) <=
        radius * radius;
  }
  for (var index = 0; index < points.length - 1; index += 1) {
    if (_segmentsTouch(
      _Segment(start, end),
      _Segment(points[index], points[index + 1]),
      radius: radius,
    )) {
      return true;
    }
  }

  return false;
}

bool _lineIntersectsRect(FrameElementFacts facts, Rect rect) {
  final start = facts.start;
  final end = facts.end;
  if (start == null ||
      end == null ||
      !isFiniteOffset(start) ||
      !isFiniteOffset(end)) {
    return false;
  }

  return _segmentTouchesRect(
    facts.transform.applyToPoint(start),
    facts.transform.applyToPoint(end),
    rect,
    radius: _worldStrokeRadius(facts),
  );
}

bool _strokeIntersectsRect(FrameElementFacts facts, Rect rect) {
  if (facts.points.isEmpty ||
      facts.points.any((point) => !isFiniteOffset(point))) {
    return false;
  }
  final radius = _worldStrokeRadius(facts);
  if (facts.points.length == 1) {
    return _pointDistanceSquaredToRect(
          facts.transform.applyToPoint(facts.points.first),
          rect,
        ) <=
        radius * radius;
  }
  for (var index = 0; index < facts.points.length - 1; index += 1) {
    if (_segmentTouchesRect(
      facts.transform.applyToPoint(facts.points[index]),
      facts.transform.applyToPoint(facts.points[index + 1]),
      rect,
      radius: radius,
    )) {
      return true;
    }
  }

  return false;
}

bool _pathIntersectsRect(FrameElementFacts facts, Rect rect) {
  final parsed = ParsedSvgPath.parse(
    facts.svgPathData ?? '',
    fillRule: facts.fillRule ?? CanvasPathFillRule.nonZero,
  );
  if (parsed == null) {
    return false;
  }
  final worldPath = parsed.path.transform(facts.transform.toCanvasTransform());

  return _pathFillIntersectsRect(worldPath, rect, facts) ||
      _pathStrokeIntersectsRect(worldPath, rect, facts);
}

bool _pathFillIntersectsRect(Path path, Rect rect, FrameElementFacts facts) {
  if (facts.fillColor == null) {
    return false;
  }
  if (_pathContainsAnyRectProbe(path, rect)) {
    return true;
  }
  return _pathMetricsIntersectRect(
    path,
    rect,
    radius: _scenePadding(facts.hitPadding),
    forceClosed: true,
  );
}

bool _pathStrokeIntersectsRect(Path path, Rect rect, FrameElementFacts facts) {
  final strokeWidth = facts.strokeWidth ?? 0;
  if (facts.strokeColor == null || strokeWidth <= 0) {
    return false;
  }
  return _pathMetricsIntersectRect(
    path,
    rect,
    radius:
        maxScale(facts.transform) * strokeWidth / 2 +
        _scenePadding(facts.hitPadding),
    forceClosed: false,
  );
}

bool _pathContainsAnyRectProbe(Path path, Rect rect) {
  return path.contains(rect.center) ||
      path.contains(rect.topLeft) ||
      path.contains(rect.topRight) ||
      path.contains(rect.bottomLeft) ||
      path.contains(rect.bottomRight);
}

bool _pathMetricsIntersectRect(
  Path path,
  Rect rect, {
  required double radius,
  required bool forceClosed,
}) {
  for (final metric in path.computeMetrics(forceClosed: forceClosed)) {
    if (_metricIntersectsRect(metric, rect, radius)) {
      return true;
    }
  }

  return false;
}

bool _metricIntersectsRect(PathMetric metric, Rect rect, double radius) {
  final sampleCount = math.min(
    kCanvasMaxPathHitSamplesPerMetric,
    math.max(1, (metric.length / 1.0).ceil()),
  );
  var previous = metric.getTangentForOffset(0)?.position;
  for (var sample = 1; sample <= sampleCount; sample += 1) {
    final current = metric
        .getTangentForOffset(metric.length * sample / sampleCount)
        ?.position;
    if (previous != null &&
        current != null &&
        _segmentTouchesRect(previous, current, rect, radius: radius)) {
      return true;
    }
    previous = current;
  }

  return false;
}

bool _segmentIntersectsInflatedRect(Offset start, Offset end, Rect rect) {
  return rect.contains(start) ||
      rect.contains(end) ||
      _segmentsIntersect(start, end, rect.topLeft, rect.topRight) ||
      _segmentsIntersect(start, end, rect.topRight, rect.bottomRight) ||
      _segmentsIntersect(start, end, rect.bottomRight, rect.bottomLeft) ||
      _segmentsIntersect(start, end, rect.bottomLeft, rect.topLeft);
}

bool _segmentTouchesRect(
  Offset start,
  Offset end,
  Rect rect, {
  required double radius,
}) {
  return _segmentIntersectsRectInclusive(start, end, rect) ||
      _segmentDistanceSquaredToRect(start, end, rect) <= radius * radius;
}

bool _segmentIntersectsRectInclusive(Offset start, Offset end, Rect rect) {
  return _rectContainsPointInclusive(rect, start) ||
      _rectContainsPointInclusive(rect, end) ||
      _segmentsIntersect(start, end, rect.topLeft, rect.topRight) ||
      _segmentsIntersect(start, end, rect.topRight, rect.bottomRight) ||
      _segmentsIntersect(start, end, rect.bottomRight, rect.bottomLeft) ||
      _segmentsIntersect(start, end, rect.bottomLeft, rect.topLeft);
}

double _segmentDistanceSquaredToRect(Offset start, Offset end, Rect rect) {
  return [
    _pointDistanceSquaredToRect(start, rect),
    _pointDistanceSquaredToRect(end, rect),
    distanceSquaredPointToSegment(rect.topLeft, start, end),
    distanceSquaredPointToSegment(rect.topRight, start, end),
    distanceSquaredPointToSegment(rect.bottomRight, start, end),
    distanceSquaredPointToSegment(rect.bottomLeft, start, end),
  ].reduce(math.min);
}

double _pointDistanceSquaredToRect(Offset point, Rect rect) {
  final dx = point.dx < rect.left
      ? rect.left - point.dx
      : point.dx > rect.right
      ? point.dx - rect.right
      : 0.0;
  final dy = point.dy < rect.top
      ? rect.top - point.dy
      : point.dy > rect.bottom
      ? point.dy - rect.bottom
      : 0.0;

  return dx * dx + dy * dy;
}

bool _rectContainsPointInclusive(Rect rect, Offset point) {
  return point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
}

bool _rectsOverlapInclusive(Rect left, Rect right) {
  return left.left <= right.right &&
      left.right >= right.left &&
      left.top <= right.bottom &&
      left.bottom >= right.top;
}

bool _pointTouchesCorridor(
  Offset point,
  EraserCorridor corridor, {
  required double extraRadius,
}) {
  final radius = corridor.exactRadiusWorld + extraRadius;
  if (corridor.points.length == 1) {
    final delta = point - corridor.points.first;

    return delta.dx * delta.dx + delta.dy * delta.dy <= radius * radius;
  }
  for (var index = 0; index < corridor.points.length - 1; index += 1) {
    if (distanceSquaredPointToSegment(
          point,
          corridor.points[index],
          corridor.points[index + 1],
        ) <=
        radius * radius) {
      return true;
    }
  }

  return false;
}

bool _segmentTouchesCorridor(
  Offset start,
  Offset end,
  EraserCorridor corridor, {
  required double extraRadius,
}) {
  final radius = corridor.exactRadiusWorld + extraRadius;
  if (corridor.points.length == 1) {
    return distanceSquaredPointToSegment(corridor.points.first, start, end) <=
        radius * radius;
  }
  for (var index = 0; index < corridor.points.length - 1; index += 1) {
    if (_segmentsTouch(
      _Segment(start, end),
      _Segment(corridor.points[index], corridor.points[index + 1]),
      radius: radius,
    )) {
      return true;
    }
  }

  return false;
}

bool _segmentsTouch(_Segment left, _Segment right, {required double radius}) {
  return _segmentsIntersect(left.start, left.end, right.start, right.end) ||
      _segmentDistanceSquared(left, right) <= radius * radius;
}

double _segmentDistanceSquared(_Segment left, _Segment right) {
  return [
    distanceSquaredPointToSegment(left.start, right.start, right.end),
    distanceSquaredPointToSegment(left.end, right.start, right.end),
    distanceSquaredPointToSegment(right.start, left.start, left.end),
    distanceSquaredPointToSegment(right.end, left.start, left.end),
  ].reduce(math.min);
}

final class _Segment {
  const _Segment(this.start, this.end);

  final Offset start;
  final Offset end;
}

bool _segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
  final d1 = _orientation(a1, a2, b1);
  final d2 = _orientation(a1, a2, b2);
  final d3 = _orientation(b1, b2, a1);
  final d4 = _orientation(b1, b2, a2);

  if (d1 == 0 && _onSegment(a1, b1, a2)) {
    return true;
  }
  if (d2 == 0 && _onSegment(a1, b2, a2)) {
    return true;
  }
  if (d3 == 0 && _onSegment(b1, a1, b2)) {
    return true;
  }
  if (d4 == 0 && _onSegment(b1, a2, b2)) {
    return true;
  }

  return d1 * d2 < 0 && d3 * d4 < 0;
}

double _orientation(Offset a, Offset b, Offset c) {
  return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
}

bool _onSegment(Offset start, Offset point, Offset end) {
  return point.dx >= math.min(start.dx, end.dx) &&
      point.dx <= math.max(start.dx, end.dx) &&
      point.dy >= math.min(start.dy, end.dy) &&
      point.dy <= math.max(start.dy, end.dy);
}

Rect _inflateLocalBoundsForScenePadding(
  Rect bounds,
  CanvasTransform inverse,
  double paddingScene,
) {
  final paddingX =
      paddingScene * math.sqrt(inverse.a * inverse.a + inverse.c * inverse.c);
  final paddingY =
      paddingScene * math.sqrt(inverse.b * inverse.b + inverse.d * inverse.d);

  return Rect.fromLTRB(
    bounds.left - paddingX,
    bounds.top - paddingY,
    bounds.right + paddingX,
    bounds.bottom + paddingY,
  );
}

double _worldStrokeRadius(FrameElementFacts facts) {
  return maxScale(facts.transform) * (facts.thickness ?? 0) / 2 +
      _scenePadding(facts.hitPadding);
}

double _worldPaintStrokeRadius(FrameElementFacts facts) {
  return maxScale(facts.transform) * (facts.thickness ?? 0) / 2;
}

double _sceneScalarToLocalMax(CanvasTransform inverse, double scenePadding) {
  return scenePadding * maxScale(inverse);
}

double _scenePadding(double hitPadding) {
  return clampNonNegativeFinite(hitPadding) + kCanvasGeometryHitSlop;
}

Rect _normalizeRect(Rect rect) {
  return Rect.fromLTRB(
    math.min(rect.left, rect.right),
    math.min(rect.top, rect.bottom),
    math.max(rect.left, rect.right),
    math.max(rect.top, rect.bottom),
  );
}

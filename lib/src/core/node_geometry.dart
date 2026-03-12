import 'dart:math' as math;
import 'dart:ui';

import '../contract/transform2d.dart';
import 'geometry.dart';
import 'nodes.dart';
import 'numeric_clamp.dart';

const double kNodeGeometryHitSlop = 4.0;
const int kMaxStrokeHitSamplesPerMetric = 2048;

Rect nodeGeometryCandidateBoundsWorld(
  SceneNode node, {
  double additionalScenePadding = 0,
}) {
  final bounds = node.boundsWorld;
  if (!isFiniteRect(bounds)) return Rect.zero;
  final padding = _nodeScenePadding(
    node: node,
    additionalScenePadding: additionalScenePadding,
  );
  return padding <= 0 ? bounds : bounds.inflate(padding);
}

bool nodeGeometryHitTest(Offset point, SceneNode node) {
  if (!_isNodeHitTestEligible(point, node)) {
    return false;
  }
  return switch (node.type) {
    NodeType.image ||
    NodeType.text ||
    NodeType.rect => _hitTestBoxNode(point, node),
    NodeType.path => _hitTestPathNode(point, node as PathNode),
    NodeType.line => _hitTestLineNode(point, node as LineNode),
    NodeType.stroke => _hitTestStrokeNode(point, node as StrokeNode),
  };
}

bool _isNodeHitTestEligible(Offset point, SceneNode node) {
  return point.dx.isFinite &&
      point.dy.isFinite &&
      node.isVisible &&
      node.isSelectable &&
      node.transform.isFinite;
}

double _nodeScenePadding({
  required SceneNode node,
  double additionalScenePadding = 0,
}) {
  final baseHitPadding = clampNonNegativeFinite(node.hitPadding);
  final extraPadding = clampNonNegativeFinite(additionalScenePadding);
  return baseHitPadding + kNodeGeometryHitSlop + extraPadding;
}

bool _hitTestBoxNode(Offset point, SceneNode node) {
  final inverse = node.transform.invert();
  if (inverse == null) {
    return nodeGeometryCandidateBoundsWorld(node).contains(point);
  }
  final localPoint = inverse.applyToPoint(point);
  final paddingScene = _nodeScenePadding(node: node);
  final bounds = _inflateLocalBoundsForScenePadding(
    node.localBounds,
    inverse,
    paddingScene,
  );
  return bounds.contains(localPoint);
}

Rect _inflateLocalBoundsForScenePadding(
  Rect bounds,
  Transform2D inverse,
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

bool _hitTestPathNode(Offset point, PathNode node) {
  final localPath = node.buildLocalPath();
  if (localPath == null) return false;

  final candidateBounds = nodeGeometryCandidateBoundsWorld(node);
  if (!candidateBounds.contains(point)) return false;

  final inverse = node.transform.invert();
  if (inverse == null) {
    return true;
  }

  final localPoint = inverse.applyToPoint(point);
  if (_pathContainsFill(node, localPath, localPoint)) {
    return true;
  }

  final strokeRadiusLocal = _pathStrokeRadiusLocal(node, inverse);
  if (strokeRadiusLocal <= 0) {
    return false;
  }
  return _hitTestPathStrokePrecise(localPath, localPoint, strokeRadiusLocal);
}

bool _pathContainsFill(PathNode node, Path localPath, Offset localPoint) {
  return node.fillColor != null && localPath.contains(localPoint);
}

double _pathStrokeRadiusLocal(PathNode node, Transform2D inverse) {
  if (node.strokeColor == null) {
    return 0;
  }
  final baseStrokeWidth = clampNonNegativeFinite(node.strokeWidth);
  if (baseStrokeWidth <= 0) {
    return 0;
  }
  final paddingLocal = _sceneScalarToLocalMax(
    inverse,
    _nodeScenePadding(node: node),
  );
  return baseStrokeWidth / 2 + paddingLocal;
}

bool _hitTestLineNode(Offset point, LineNode node) {
  final inverse = node.transform.invert();
  if (inverse == null) {
    return nodeGeometryCandidateBoundsWorld(node).contains(point);
  }
  final worldRadius = _worldStrokeRadius(
    transform: node.transform,
    baseThickness: node.thickness,
    scenePadding: _nodeScenePadding(node: node),
  );
  return _hitTestWorldSegment(
    point,
    _worldSegment(node.transform, node.start, node.end),
    worldRadius,
  );
}

bool _hitTestStrokeNode(Offset point, StrokeNode node) {
  final inverse = node.transform.invert();
  if (inverse == null) {
    return nodeGeometryCandidateBoundsWorld(node).contains(point);
  }
  final worldRadius = _worldStrokeRadius(
    transform: node.transform,
    baseThickness: node.thickness,
    scenePadding: _nodeScenePadding(node: node),
  );
  return _hitTestTransformedPolyline(
    point: point,
    transform: node.transform,
    points: node.points,
    worldRadius: worldRadius,
  );
}

double _worldStrokeRadius({
  required Transform2D transform,
  required double baseThickness,
  required double scenePadding,
}) {
  final halfThickness = clampNonNegativeFinite(baseThickness) / 2;
  return _localScalarToSceneMax(transform, halfThickness) + scenePadding;
}

({Offset start, Offset end}) _worldSegment(
  Transform2D transform,
  Offset start,
  Offset end,
) {
  return (
    start: transform.applyToPoint(start),
    end: transform.applyToPoint(end),
  );
}

bool _hitTestWorldSegment(
  Offset point,
  ({Offset start, Offset end}) segment,
  double worldRadius,
) {
  return distanceSquaredPointToSegment(point, segment.start, segment.end) <=
      worldRadius * worldRadius;
}

bool _hitTestTransformedPolyline({
  required Offset point,
  required Transform2D transform,
  required List<Offset> points,
  required double worldRadius,
}) {
  if (points.isEmpty) return false;
  if (points.length == 1) {
    return _hitTestSingleWorldPoint(
      point: point,
      worldPoint: transform.applyToPoint(points.first),
      radius: worldRadius,
    );
  }
  for (var i = 0; i < points.length - 1; i++) {
    if (_hitTestWorldSegment(
      point,
      _worldSegment(transform, points[i], points[i + 1]),
      worldRadius,
    )) {
      return true;
    }
  }
  return false;
}

bool _hitTestSingleWorldPoint({
  required Offset point,
  required Offset worldPoint,
  required double radius,
}) {
  final delta = point - worldPoint;
  final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
  return distanceSquared <= radius * radius;
}

double _sceneScalarToLocalMax(Transform2D inverse, double valueScene) {
  final scaleX = math.sqrt(inverse.a * inverse.a + inverse.c * inverse.c);
  final scaleY = math.sqrt(inverse.b * inverse.b + inverse.d * inverse.d);
  return clampNonNegativeFinite(valueScene * math.max(scaleX, scaleY));
}

double _localScalarToSceneMax(Transform2D transform, double valueLocal) {
  final clampedLocal = clampNonNegativeFinite(valueLocal);
  if (clampedLocal <= 0) return 0;
  if (!transform.isFinite) return clampedLocal;
  final localToScene = _maxSingularValue2x2(
    transform.a,
    transform.b,
    transform.c,
    transform.d,
  );
  return clampNonNegativeFinite(clampedLocal * localToScene);
}

double _maxSingularValue2x2(double a, double b, double c, double d) {
  final t = a * a + b * b + c * c + d * d;
  final det = a * d - b * c;
  final discSquared = t * t - 4 * det * det;
  final disc = math.sqrt(math.max(0, discSquared));
  final lambdaMax = (t + disc) / 2;
  return math.sqrt(math.max(0, lambdaMax));
}

bool _hitTestPathStrokePrecise(
  Path localPath,
  Offset localPoint,
  double strokeRadiusLocal,
) {
  final radius = clampNonNegativeFinite(strokeRadiusLocal);
  if (radius <= 0) return false;
  final radiusSquared = radius * radius;
  return _hitTestPathMetrics(
    localPath.computeMetrics(),
    localPoint: localPoint,
    radius: radius,
    radiusSquared: radiusSquared,
  );
}

bool _hitTestPathMetrics(
  PathMetrics metrics, {
  required Offset localPoint,
  required double radius,
  required double radiusSquared,
}) {
  for (final metric in metrics) {
    if (_hitTestMetricStroke(
      metric,
      localPoint: localPoint,
      radius: radius,
      radiusSquared: radiusSquared,
    )) {
      return true;
    }
  }
  return false;
}

bool _hitTestMetricStroke(
  PathMetric metric, {
  required Offset localPoint,
  required double radius,
  required double radiusSquared,
}) {
  if (metric.length <= 0) return false;
  final start = metric.getTangentForOffset(0);
  if (start == null) return false;
  Offset? previous = start.position;
  if (_hitTestSingleWorldPoint(
    point: localPoint,
    worldPoint: previous,
    radius: radius,
  )) {
    return true;
  }
  final step = _pathMetricStep(metric.length, radius);
  previous = _traceMetricInterior(
    metric,
    localPoint: localPoint,
    step: step,
    previous: previous,
    radiusSquared: radiusSquared,
  );
  if (previous == null) {
    return true;
  }
  return _hitTestMetricEnd(metric, localPoint, previous, radiusSquared);
}

Offset? _traceMetricInterior(
  PathMetric metric, {
  required Offset localPoint,
  required double step,
  required Offset previous,
  required double radiusSquared,
}) {
  var currentPrevious = previous;
  for (var offset = step; offset < metric.length; offset += step) {
    final currentTangent = metric.getTangentForOffset(offset);
    if (currentTangent == null) continue;
    final current = currentTangent.position;
    if (distanceSquaredPointToSegment(localPoint, currentPrevious, current) <=
        radiusSquared) {
      return null;
    }
    currentPrevious = current;
  }
  return currentPrevious;
}

bool _hitTestMetricEnd(
  PathMetric metric,
  Offset localPoint,
  Offset previous,
  double radiusSquared,
) {
  final end = metric.getTangentForOffset(metric.length);
  return end != null &&
      distanceSquaredPointToSegment(localPoint, previous, end.position) <=
          radiusSquared;
}

double _pathMetricStep(double metricLength, double strokeRadiusLocal) {
  final radius = clampNonNegativeFinite(strokeRadiusLocal);
  var step = math.max(0.5, radius * 0.5);
  if (metricLength / step > kMaxStrokeHitSamplesPerMetric) {
    step = metricLength / kMaxStrokeHitSamplesPerMetric;
  }
  return step;
}

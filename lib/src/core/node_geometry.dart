import 'dart:math' as math;
import 'dart:ui';

import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'geometry.dart';
import 'local_bounds_policy.dart'
    show
        centeredRectLocalBounds,
        strokeAwareCenteredRectLocalBounds,
        strokeAwareLocalBounds;
import 'nodes.dart';
import 'numeric_clamp.dart';
import 'text_layout.dart';

const double kNodeGeometryHitSlop = 4.0;
const int kMaxStrokeHitSamplesPerMetric = 2048;

typedef _MetricTraceState = ({
  Offset localPoint,
  Offset previous,
  double radiusSquared,
  double step,
});

Rect nodeGeometryCandidateBoundsWorld(
  SceneNode node, {
  double additionalScenePadding = 0,
}) {
  final bounds = node.boundsWorld;
  if (!isFiniteRect(bounds)) return Rect.zero;
  final padding = _geometryScenePadding(
    hitPadding: node.hitPadding,
    additionalScenePadding: additionalScenePadding,
  );
  return padding <= 0 ? bounds : bounds.inflate(padding);
}

Rect nodePaintBoundsWorld(SceneNode node) {
  final bounds = node.boundsWorld;
  return isFiniteRect(bounds) ? bounds : Rect.zero;
}

Rect nodeSnapshotGeometryCandidateBoundsWorld(
  NodeSnapshot node, {
  double additionalScenePadding = 0,
}) {
  final bounds = _snapshotBoundsWorld(node);
  if (!isFiniteRect(bounds)) return Rect.zero;
  final padding = _geometryScenePadding(
    hitPadding: node.hitPadding,
    additionalScenePadding: additionalScenePadding,
  );
  return padding <= 0 ? bounds : bounds.inflate(padding);
}

Rect nodeSnapshotPaintBoundsWorld(NodeSnapshot node) {
  final bounds = _snapshotBoundsWorld(node);
  return isFiniteRect(bounds) ? bounds : Rect.zero;
}

Rect nodeSnapshotBoundsWorld(NodeSnapshot node) {
  final bounds = _snapshotBoundsWorld(node);
  return isFiniteRect(bounds) ? bounds : Rect.zero;
}

void requireNodeSnapshotGeometrySupport(NodeSnapshot node) {
  switch (node) {
    case ImageNodeSnapshot():
    case TextNodeSnapshot():
    case RectNodeSnapshot():
    case LineNodeSnapshot():
    case StrokeNodeSnapshot():
    case PathNodeSnapshot():
      return;
    default:
      throw StateError('Unsupported snapshot node type: ${node.runtimeType}');
  }
}

bool nodeGeometryHitTest(Offset point, SceneNode node) {
  if (!_isHitTestEligible(
    point,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    transform: node.transform,
  )) {
    return false;
  }
  return switch (node.type) {
    NodeType.image || NodeType.text || NodeType.rect => _hitTestBoxGeometry(
      point: point,
      transform: node.transform,
      localBounds: node.localBounds,
      candidateBoundsWorld: nodeGeometryCandidateBoundsWorld(node),
      scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
    ),
    NodeType.path => _hitTestPathGeometry(
      point: point,
      transform: node.transform,
      localPath: (node as PathNode).buildLocalPath(),
      candidateBoundsWorld: nodeGeometryCandidateBoundsWorld(node),
      hasFill: node.fillColor != null,
      strokeRadiusLocal: _pathStrokeRadiusLocal(
        strokeColor: node.strokeColor,
        strokeWidth: node.strokeWidth,
        inverse: node.transform.invert(),
        scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
      ),
    ),
    NodeType.line => _hitTestWorldStrokeGeometry(
      point: point,
      transform: (node as LineNode).transform,
      baseThickness: node.thickness,
      candidateBoundsWorld: nodeGeometryCandidateBoundsWorld(node),
      scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
      hitTest: (worldRadius) => _hitTestWorldSegment(
        point,
        _worldSegment(node.transform, node.start, node.end),
        worldRadius,
      ),
    ),
    NodeType.stroke => _hitTestWorldStrokeGeometry(
      point: point,
      transform: (node as StrokeNode).transform,
      baseThickness: node.thickness,
      candidateBoundsWorld: nodeGeometryCandidateBoundsWorld(node),
      scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
      hitTest: (worldRadius) => _hitTestTransformedPolyline(
        point: point,
        transform: node.transform,
        points: node.points,
        worldRadius: worldRadius,
      ),
    ),
  };
}

bool nodeSnapshotGeometryHitTest(Offset point, NodeSnapshot node) {
  if (!_isHitTestEligible(
    point,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    transform: node.transform,
  )) {
    return false;
  }
  return switch (node) {
    ImageNodeSnapshot() ||
    TextNodeSnapshot() ||
    RectNodeSnapshot() => _hitTestBoxGeometry(
      point: point,
      transform: node.transform,
      localBounds: _snapshotLocalBounds(node),
      candidateBoundsWorld: nodeSnapshotGeometryCandidateBoundsWorld(node),
      scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
    ),
    PathNodeSnapshot() => _hitTestPathGeometry(
      point: point,
      transform: node.transform,
      localPath: _snapshotLocalPath(node),
      candidateBoundsWorld: nodeSnapshotGeometryCandidateBoundsWorld(node),
      hasFill: node.fillColor != null,
      strokeRadiusLocal: _pathStrokeRadiusLocal(
        strokeColor: node.strokeColor,
        strokeWidth: node.strokeWidth,
        inverse: node.transform.invert(),
        scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
      ),
    ),
    LineNodeSnapshot() => _hitTestWorldStrokeGeometry(
      point: point,
      transform: node.transform,
      baseThickness: node.thickness,
      candidateBoundsWorld: nodeSnapshotGeometryCandidateBoundsWorld(node),
      scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
      hitTest: (worldRadius) => _hitTestWorldSegment(
        point,
        _worldSegment(node.transform, node.start, node.end),
        worldRadius,
      ),
    ),
    StrokeNodeSnapshot() => _hitTestWorldStrokeGeometry(
      point: point,
      transform: node.transform,
      baseThickness: node.thickness,
      candidateBoundsWorld: nodeSnapshotGeometryCandidateBoundsWorld(node),
      scenePadding: _geometryScenePadding(hitPadding: node.hitPadding),
      hitTest: (worldRadius) => _hitTestTransformedPolyline(
        point: point,
        transform: node.transform,
        points: node.points,
        worldRadius: worldRadius,
      ),
    ),
    _ => false,
  };
}

bool _isHitTestEligible(
  Offset point, {
  required bool isVisible,
  required bool isSelectable,
  required Transform2D transform,
}) {
  return point.dx.isFinite &&
      point.dy.isFinite &&
      isVisible &&
      isSelectable &&
      transform.isFinite;
}

double _geometryScenePadding({
  required double hitPadding,
  double additionalScenePadding = 0,
}) {
  final baseHitPadding = clampNonNegativeFinite(hitPadding);
  final extraPadding = clampNonNegativeFinite(additionalScenePadding);
  return baseHitPadding + kNodeGeometryHitSlop + extraPadding;
}

bool _hitTestBoxGeometry({
  required Offset point,
  required Transform2D transform,
  required Rect localBounds,
  required Rect candidateBoundsWorld,
  required double scenePadding,
}) {
  final inverse = transform.invert();
  if (inverse == null) {
    return candidateBoundsWorld.contains(point);
  }
  final localPoint = inverse.applyToPoint(point);
  final bounds = _inflateLocalBoundsForScenePadding(
    localBounds,
    inverse,
    scenePadding,
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

bool _hitTestPathGeometry({
  required Offset point,
  required Transform2D transform,
  required Path? localPath,
  required Rect candidateBoundsWorld,
  required bool hasFill,
  required double strokeRadiusLocal,
}) {
  if (localPath == null) return false;
  if (!candidateBoundsWorld.contains(point)) return false;
  final inverse = transform.invert();
  if (inverse == null) {
    return true;
  }
  final localPoint = inverse.applyToPoint(point);
  if (hasFill && localPath.contains(localPoint)) {
    return true;
  }
  if (strokeRadiusLocal <= 0) {
    return false;
  }
  return _hitTestPathStrokePrecise(localPath, localPoint, strokeRadiusLocal);
}

double _pathStrokeRadiusLocal({
  required Color? strokeColor,
  required double strokeWidth,
  required Transform2D? inverse,
  required double scenePadding,
}) {
  if (strokeColor == null || inverse == null) {
    return 0;
  }
  final baseStrokeWidth = clampNonNegativeFinite(strokeWidth);
  if (baseStrokeWidth <= 0) {
    return 0;
  }
  final paddingLocal = _sceneScalarToLocalMax(inverse, scenePadding);
  return baseStrokeWidth / 2 + paddingLocal;
}

bool _hitTestWorldStrokeGeometry({
  required Offset point,
  required Transform2D transform,
  required double baseThickness,
  required Rect candidateBoundsWorld,
  required double scenePadding,
  required bool Function(double worldRadius) hitTest,
}) {
  if (transform.invert() == null) {
    return candidateBoundsWorld.contains(point);
  }
  return hitTest(
    _worldStrokeRadius(
      transform: transform,
      baseThickness: baseThickness,
      scenePadding: scenePadding,
    ),
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
  return maxSingularValue2x2(a, b, c, d);
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

Rect _snapshotBoundsWorld(NodeSnapshot node) {
  return node.transform.applyToRect(_snapshotLocalBounds(node));
}

Rect _snapshotLocalBounds(NodeSnapshot node) {
  return switch (node) {
    ImageNodeSnapshot(:final size) => centeredRectLocalBounds(size),
    TextNodeSnapshot() => centeredRectLocalBounds(
      TextLayoutRequest.forSnapshot(node).measure(),
    ),
    RectNodeSnapshot(:final size, :final strokeColor, :final strokeWidth) =>
      strokeAwareCenteredRectLocalBounds(
        size: size,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      ),
    StrokeNodeSnapshot(:final points, :final thickness) => strokeLocalBounds(
      points: points,
      thickness: thickness,
    ),
    LineNodeSnapshot(:final start, :final end, :final thickness) =>
      lineLocalBounds(start: start, end: end, thickness: thickness),
    PathNodeSnapshot(
      :final svgPathData,
      :final fillRule,
      :final strokeColor,
      :final strokeWidth,
    ) =>
      strokeAwareLocalBounds(
        baseBounds:
            buildCenteredSvgPathGeometry(
              svgPathData,
              fillType: fillRule == PathFillRule.evenOdd
                  ? PathFillType.evenOdd
                  : PathFillType.nonZero,
            )?.localBounds ??
            Rect.zero,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      ),
    _ => Rect.zero,
  };
}

Path? _snapshotLocalPath(PathNodeSnapshot node) {
  return buildCenteredSvgPathGeometry(
    node.svgPathData,
    fillType: node.fillRule == PathFillRule.evenOdd
        ? PathFillType.evenOdd
        : PathFillType.nonZero,
  )?.localPath;
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
  previous = _traceMetricInterior(metric, (
    localPoint: localPoint,
    step: step,
    previous: previous,
    radiusSquared: radiusSquared,
  ));
  if (previous == null) {
    return true;
  }
  return _hitTestMetricEnd(metric, localPoint, previous, radiusSquared);
}

Offset? _traceMetricInterior(PathMetric metric, _MetricTraceState state) {
  var currentPrevious = state.previous;
  for (var offset = state.step; offset < metric.length; offset += state.step) {
    final currentTangent = metric.getTangentForOffset(offset);
    if (currentTangent == null) continue;
    final current = currentTangent.position;
    if (distanceSquaredPointToSegment(
          state.localPoint,
          currentPrevious,
          current,
        ) <=
        state.radiusSquared) {
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

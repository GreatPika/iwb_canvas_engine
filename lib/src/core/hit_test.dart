import 'dart:ui';
import 'dart:math' as math;

import 'geometry.dart';
import 'nodes.dart';
import 'scene.dart';
import 'numeric_clamp.dart';
import 'transform2d.dart';

/// Extra hit-test tolerance applied by this package, in scene units.
///
/// This constant is used in addition to node-specific thickness and
/// [SceneNode.hitPadding] to make selection easier on touch devices.
const double kHitSlop = 4.0;
const int kMaxStrokeHitSamplesPerMetric = 2048;

/// Returns coarse world bounds used to prefilter node hit-test candidates.
///
/// The returned rectangle includes node geometry bounds plus
/// `hitPadding + kHitSlop`, and optionally [additionalScenePadding].
Rect nodeHitTestCandidateBoundsWorld(
  SceneNode node, {
  double additionalScenePadding = 0,
}) {
  final bounds = node.boundsWorld;
  if (!_isFiniteRect(bounds)) return Rect.zero;
  final baseHitPadding = clampNonNegativeFinite(node.hitPadding);
  final extraPadding = clampNonNegativeFinite(additionalScenePadding);
  final padding = baseHitPadding + kHitSlop + extraPadding;
  if (padding <= 0) return bounds;
  return bounds.inflate(padding);
}

/// Returns true if [point] lies inside [rect].
bool hitTestRect(Offset point, Rect rect) {
  return rect.contains(point);
}

/// Returns true if [point] is within [thickness] of the segment [start]-[end].
bool hitTestLine(Offset point, Offset start, Offset end, double thickness) {
  final baseThickness = clampNonNegativeFinite(thickness);
  final radius = baseThickness / 2;
  return distanceSquaredPointToSegment(point, start, end) <= radius * radius;
}

/// Returns true if [point] hits the polyline [points] with [thickness].
bool hitTestStroke(
  Offset point,
  List<Offset> points,
  double thickness, {
  double hitPadding = 0,
  double hitSlop = kHitSlop,
}) {
  final baseThickness = clampNonNegativeFinite(thickness);
  final baseHitPadding = clampNonNegativeFinite(hitPadding);
  final baseHitSlop = clampNonNegativeFinite(hitSlop, fallback: kHitSlop);
  if (points.isEmpty) return false;
  if (points.length == 1) {
    final radius = baseThickness / 2 + baseHitPadding + baseHitSlop;
    final delta = point - points.first;
    final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    return distanceSquared <= radius * radius;
  }
  final effectiveThickness = baseThickness + 2 * (baseHitPadding + baseHitSlop);
  for (var i = 0; i < points.length - 1; i++) {
    if (hitTestLine(point, points[i], points[i + 1], effectiveThickness)) {
      return true;
    }
  }
  return false;
}

double _sceneScalarToLocalMax(Transform2D inverse, double valueScene) {
  final scaleX = math.sqrt(inverse.a * inverse.a + inverse.c * inverse.c);
  final scaleY = math.sqrt(inverse.b * inverse.b + inverse.d * inverse.d);
  final scale = math.max(scaleX, scaleY);
  return clampNonNegativeFinite(valueScene * scale);
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

double _pathMetricStep(double strokeRadiusLocal) {
  final radius = clampNonNegativeFinite(strokeRadiusLocal);
  return math.max(0.5, radius * 0.5);
}

bool _hitTestPathStrokePrecise(
  Path localPath,
  Offset localPoint,
  double strokeRadiusLocal,
) {
  final radius = clampNonNegativeFinite(strokeRadiusLocal);
  if (radius <= 0) return false;
  final radiusSquared = radius * radius;

  for (final metric in localPath.computeMetrics()) {
    if (metric.length <= 0) continue;
    final start = metric.getTangentForOffset(0);
    if (start == null) continue;
    var previous = start.position;
    final startDelta = localPoint - previous;
    final startDistanceSquared =
        startDelta.dx * startDelta.dx + startDelta.dy * startDelta.dy;
    if (startDistanceSquared <= radiusSquared) {
      return true;
    }
    var step = _pathMetricStep(radius);
    if (metric.length / step > kMaxStrokeHitSamplesPerMetric) {
      step = metric.length / kMaxStrokeHitSamplesPerMetric;
    }
    for (var offset = step; offset < metric.length; offset += step) {
      final currentTangent = metric.getTangentForOffset(offset);
      if (currentTangent == null) continue;
      final current = currentTangent.position;
      if (distanceSquaredPointToSegment(localPoint, previous, current) <=
          radiusSquared) {
        return true;
      }
      previous = current;
    }
    final end = metric.getTangentForOffset(metric.length);
    if (end != null &&
        distanceSquaredPointToSegment(localPoint, previous, end.position) <=
            radiusSquared) {
      return true;
    }
  }
  return false;
}

/// Returns true if [point] hits [node] in scene coordinates.
bool hitTestNode(Offset point, SceneNode node) {
  if (!point.dx.isFinite || !point.dy.isFinite) return false;
  if (!node.isVisible || !node.isSelectable) return false;
  if (!node.transform.isFinite) return false;

  switch (node.type) {
    case NodeType.image:
    case NodeType.text:
    case NodeType.rect:
      final inverse = node.transform.invert();
      final baseHitPadding = clampNonNegativeFinite(node.hitPadding);
      if (inverse == null) {
        final paddingScene = baseHitPadding + kHitSlop;
        return node.boundsWorld.inflate(paddingScene).contains(point);
      }
      final localPoint = inverse.applyToPoint(point);
      final paddingScene = baseHitPadding + kHitSlop;
      final paddingX =
          paddingScene *
          math.sqrt(inverse.a * inverse.a + inverse.c * inverse.c);
      final paddingY =
          paddingScene *
          math.sqrt(inverse.b * inverse.b + inverse.d * inverse.d);
      final bounds = node.localBounds;
      return Rect.fromLTRB(
        bounds.left - paddingX,
        bounds.top - paddingY,
        bounds.right + paddingX,
        bounds.bottom + paddingY,
      ).contains(localPoint);
    case NodeType.path:
      final pathNode = node as PathNode;
      final baseHitPadding = clampNonNegativeFinite(pathNode.hitPadding);
      final localPath = pathNode.buildLocalPath(copy: false);
      // Invalid/unbuildable path data is non-interactive at runtime.
      if (localPath == null) return false;
      final candidateBounds = nodeHitTestCandidateBoundsWorld(pathNode);
      if (!candidateBounds.contains(point)) return false;

      final inverse = pathNode.transform.invert();
      if (pathNode.fillColor != null && inverse != null) {
        final localPoint = inverse.applyToPoint(point);
        if (localPath.contains(localPoint)) return true;
      }

      if (pathNode.strokeColor == null) return false;
      final baseStrokeWidth = clampNonNegativeFinite(pathNode.strokeWidth);
      if (baseStrokeWidth <= 0) return false;
      if (inverse == null) {
        // Stroke precision requires local-space distance checks.
        return false;
      }

      final localPoint = inverse.applyToPoint(point);
      final paddingScene = baseHitPadding + kHitSlop;
      final paddingLocal = _sceneScalarToLocalMax(inverse, paddingScene);
      final strokeRadiusLocal = baseStrokeWidth / 2 + paddingLocal;
      return _hitTestPathStrokePrecise(
        localPath,
        localPoint,
        strokeRadiusLocal,
      );
    case NodeType.line:
      final line = node as LineNode;
      final inverse = line.transform.invert();
      final baseHitPadding = clampNonNegativeFinite(line.hitPadding);
      if (inverse == null) {
        final paddingScene = baseHitPadding + kHitSlop;
        return line.boundsWorld.inflate(paddingScene).contains(point);
      }
      final baseThickness = clampNonNegativeFinite(line.thickness);
      final paddingScene = baseHitPadding + kHitSlop;
      final worldStart = line.transform.applyToPoint(line.start);
      final worldEnd = line.transform.applyToPoint(line.end);
      final worldRadius =
          _localScalarToSceneMax(line.transform, baseThickness / 2) +
          paddingScene;
      return distanceSquaredPointToSegment(point, worldStart, worldEnd) <=
          worldRadius * worldRadius;
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      final inverse = stroke.transform.invert();
      final baseHitPadding = clampNonNegativeFinite(stroke.hitPadding);
      if (inverse == null) {
        final paddingScene = baseHitPadding + kHitSlop;
        return stroke.boundsWorld.inflate(paddingScene).contains(point);
      }
      final baseThickness = clampNonNegativeFinite(stroke.thickness);
      final paddingScene = baseHitPadding + kHitSlop;
      final worldRadius =
          _localScalarToSceneMax(stroke.transform, baseThickness / 2) +
          paddingScene;
      if (stroke.points.isEmpty) return false;
      if (stroke.points.length == 1) {
        final worldPoint = stroke.transform.applyToPoint(stroke.points.first);
        final delta = point - worldPoint;
        final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
        return distanceSquared <= worldRadius * worldRadius;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final start = stroke.transform.applyToPoint(stroke.points[i]);
        final end = stroke.transform.applyToPoint(stroke.points[i + 1]);
        if (distanceSquaredPointToSegment(point, start, end) <=
            worldRadius * worldRadius) {
          return true;
        }
      }
      return false;
  }
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

/// Returns the top-most node hit by [point], or null.
SceneNode? hitTestTopNode(Scene scene, Offset point) {
  for (
    var layerIndex = scene.layers.length - 1;
    layerIndex >= 0;
    layerIndex--
  ) {
    final layer = scene.layers[layerIndex];
    if (layer.isBackground) continue;
    for (var nodeIndex = layer.nodes.length - 1; nodeIndex >= 0; nodeIndex--) {
      final node = layer.nodes[nodeIndex];
      if (hitTestNode(point, node)) {
        return node;
      }
    }
  }
  return null;
}

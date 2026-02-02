import 'dart:ui';
import 'dart:math' as math;

import 'geometry.dart';
import 'nodes.dart';
import 'scene.dart';
import 'transform2d.dart';

const double kHitSlop = 4.0;

/// Returns true if [point] lies inside [rect].
bool hitTestRect(Offset point, Rect rect) {
  return rect.contains(point);
}

/// Returns true if [point] is within [thickness] of the segment [start]-[end].
bool hitTestLine(Offset point, Offset start, Offset end, double thickness) {
  final distance = distancePointToSegment(point, start, end);
  return distance <= thickness / 2;
}

/// Returns true if [point] hits the polyline [points] with [thickness].
bool hitTestStroke(
  Offset point,
  List<Offset> points,
  double thickness, {
  double hitPadding = 0,
}) {
  if (points.isEmpty) return false;
  if (points.length == 1) {
    final baseThickness = thickness < 0 ? 0 : thickness;
    final radius = baseThickness / 2 + hitPadding + kHitSlop;
    return (point - points.first).distance <= radius;
  }
  final baseThickness = thickness < 0 ? 0 : thickness;
  final effectiveThickness = baseThickness + 2 * (hitPadding + kHitSlop);
  for (var i = 0; i < points.length - 1; i++) {
    if (hitTestLine(point, points[i], points[i + 1], effectiveThickness)) {
      return true;
    }
  }
  return false;
}

/// Returns true if [point] hits [node] in scene coordinates.
bool hitTestNode(Offset point, SceneNode node) {
  if (!node.isVisible || !node.isSelectable) return false;

  switch (node.type) {
    case NodeType.image:
    case NodeType.text:
    case NodeType.rect:
      return hitTestRect(point, node.boundsWorld);
    case NodeType.path:
      final pathNode = node as PathNode;
      if (pathNode.fillColor != null) {
        final padding = pathNode.hitPadding + kHitSlop;
        if (!pathNode.boundsWorld.inflate(padding).contains(point)) {
          return false;
        }
        final localPath = pathNode.buildLocalPath();
        if (localPath == null) return false;
        final inverse = pathNode.transform.invert();
        if (inverse == null) return false;
        final localPoint = inverse.applyToPoint(point);
        return localPath.contains(localPoint);
      }
      if (pathNode.strokeColor != null) {
        final effectiveStrokeWidth =
            pathNode.strokeWidth * _maxAxisScaleAbs(pathNode.transform);
        final padding =
            effectiveStrokeWidth / 2 + pathNode.hitPadding + kHitSlop;
        return pathNode.boundsWorld.inflate(padding).contains(point);
      }
      return false;
    case NodeType.line:
      final line = node as LineNode;
      final inverse = line.transform.invert();
      if (inverse == null) return false;
      final localPoint = inverse.applyToPoint(point);
      return hitTestLine(localPoint, line.start, line.end, line.thickness);
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      final inverse = stroke.transform.invert();
      if (inverse == null) return false;
      final localPoint = inverse.applyToPoint(point);
      return hitTestStroke(
        localPoint,
        stroke.points,
        stroke.thickness,
        hitPadding: stroke.hitPadding,
      );
  }
}

/// Returns the top-most node hit by [point], or null.
SceneNode? hitTestTopNode(Scene scene, Offset point) {
  for (
    var layerIndex = scene.layers.length - 1;
    layerIndex >= 0;
    layerIndex--
  ) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = layer.nodes.length - 1; nodeIndex >= 0; nodeIndex--) {
      final node = layer.nodes[nodeIndex];
      if (hitTestNode(point, node)) {
        return node;
      }
    }
  }
  return null;
}

double _maxAxisScaleAbs(Transform2D t) {
  final sx = math.sqrt(t.a * t.a + t.b * t.b);
  final sy = math.sqrt(t.c * t.c + t.d * t.d);
  final safeSx = sx.isFinite && sx > 0 ? sx : 1.0;
  final safeSy = sy.isFinite && sy > 0 ? sy : 1.0;
  return math.max(safeSx, safeSy);
}

import 'dart:ui';
import 'dart:math' as math;

import 'geometry.dart';
import 'nodes.dart';
import 'scene.dart';

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
      return hitTestRect(point, node.aabb);
    case NodeType.path:
      final pathNode = node as PathNode;
      if (pathNode.fillColor != null) {
        final padding = pathNode.hitPadding + kHitSlop;
        if (!pathNode.aabb.inflate(padding).contains(point)) return false;
        final localPath = pathNode.buildLocalPath();
        if (localPath == null) return false;
        final localPoint = _toLocalPathPoint(point, pathNode);
        return localPath.contains(localPoint);
      }
      if (pathNode.strokeColor != null) {
        final scaleX = pathNode.scaleX.abs();
        final scaleY = pathNode.scaleY.abs();
        final scaleFactor = math.max(
          scaleX.isFinite ? scaleX : 1,
          scaleY.isFinite ? scaleY : 1,
        );
        final effectiveStrokeWidth = pathNode.strokeWidth * scaleFactor;
        final padding =
            effectiveStrokeWidth / 2 + pathNode.hitPadding + kHitSlop;
        return pathNode.aabb.inflate(padding).contains(point);
      }
      return false;
    case NodeType.line:
      final line = node as LineNode;
      return hitTestLine(point, line.start, line.end, line.thickness);
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      return hitTestStroke(
        point,
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

Offset _toLocalPathPoint(Offset point, PathNode node) {
  var local = point - node.position;
  if (node.rotationDeg != 0) {
    local = rotatePoint(local, Offset.zero, -node.rotationDeg);
  }
  if (node.scaleX != 1 || node.scaleY != 1) {
    final scaleX = node.scaleX == 0 ? 1 : node.scaleX;
    final scaleY = node.scaleY == 0 ? 1 : node.scaleY;
    local = Offset(local.dx / scaleX, local.dy / scaleY);
  }
  return local;
}

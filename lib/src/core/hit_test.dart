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

/// Returns true if [point] lies inside [rect].
bool hitTestRect(Offset point, Rect rect) {
  return rect.contains(point);
}

/// Returns true if [point] is within [thickness] of the segment [start]-[end].
bool hitTestLine(Offset point, Offset start, Offset end, double thickness) {
  final baseThickness = clampNonNegativeFinite(thickness);
  final distance = distancePointToSegment(point, start, end);
  return distance <= baseThickness / 2;
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
    return (point - points.first).distance <= radius;
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
      if (pathNode.fillColor != null) {
        final padding = baseHitPadding + kHitSlop;
        if (!pathNode.boundsWorld.inflate(padding).contains(point)) {
          return false;
        }
        final inverse = pathNode.transform.invert();
        if (inverse == null) return true;
        final localPoint = inverse.applyToPoint(point);
        if (localPath.contains(localPoint)) return true;

        // Union semantics: when a path has both fill and stroke, allow hits on
        // the stroke even if the point lies outside the filled interior.
        //
        // Stage A (coarse): use an inflated AABB check for the stroke area.
        if (pathNode.strokeColor != null) {
          final baseStrokeWidth = clampNonNegativeFinite(pathNode.strokeWidth);
          if (baseStrokeWidth > 0) {
            // Note: boundsWorld already includes stroke thickness via
            // PathNode.localBounds; only apply selection tolerances here.
            final strokePadding = baseHitPadding + kHitSlop;
            return pathNode.boundsWorld.inflate(strokePadding).contains(point);
          }
        }
        return false;
      }
      if (pathNode.strokeColor != null) {
        final baseStrokeWidth = clampNonNegativeFinite(pathNode.strokeWidth);
        if (baseStrokeWidth <= 0) return false;
        // Note: boundsWorld already includes stroke thickness via
        // PathNode.localBounds; only apply selection tolerances here.
        final padding = baseHitPadding + kHitSlop;
        return pathNode.boundsWorld.inflate(padding).contains(point);
      }
      return false;
    case NodeType.line:
      final line = node as LineNode;
      final inverse = line.transform.invert();
      final baseHitPadding = clampNonNegativeFinite(line.hitPadding);
      if (inverse == null) {
        final paddingScene = baseHitPadding + kHitSlop;
        return line.boundsWorld.inflate(paddingScene).contains(point);
      }
      final localPoint = inverse.applyToPoint(point);
      final baseThickness = clampNonNegativeFinite(line.thickness);
      final paddingScene = baseHitPadding + kHitSlop;
      final paddingLocal = _sceneScalarToLocalMax(inverse, paddingScene);
      final effectiveThickness = baseThickness + 2 * paddingLocal;
      return hitTestLine(localPoint, line.start, line.end, effectiveThickness);
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      final inverse = stroke.transform.invert();
      final baseHitPadding = clampNonNegativeFinite(stroke.hitPadding);
      if (inverse == null) {
        final paddingScene = baseHitPadding + kHitSlop;
        return stroke.boundsWorld.inflate(paddingScene).contains(point);
      }
      final localPoint = inverse.applyToPoint(point);
      final hitPaddingLocal = _sceneScalarToLocalMax(inverse, baseHitPadding);
      final hitSlopLocal = _sceneScalarToLocalMax(inverse, kHitSlop);
      return hitTestStroke(
        localPoint,
        stroke.points,
        stroke.thickness,
        hitPadding: hitPaddingLocal,
        hitSlop: hitSlopLocal,
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

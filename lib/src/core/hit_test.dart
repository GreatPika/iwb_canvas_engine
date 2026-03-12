import 'dart:ui';

import 'geometry.dart';
import 'node_geometry.dart';
import 'nodes.dart';
import 'scene.dart';
import 'numeric_clamp.dart';

/// Extra hit-test tolerance applied by this package, in scene units.
///
/// This constant is used in addition to node-specific thickness and
/// [SceneNode.hitPadding] to make selection easier on touch devices.
const double kHitSlop = kNodeGeometryHitSlop;

/// Returns coarse world bounds used to prefilter node hit-test candidates.
///
/// The returned rectangle includes node geometry bounds plus
/// `hitPadding + kHitSlop`, and optionally [additionalScenePadding].
Rect nodeHitTestCandidateBoundsWorld(
  SceneNode node, {
  double additionalScenePadding = 0,
}) {
  return nodeGeometryCandidateBoundsWorld(
    node,
    additionalScenePadding: additionalScenePadding,
  );
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

class StrokeHitOptions {
  const StrokeHitOptions({this.hitPadding = 0, this.hitSlop = kHitSlop});

  final double hitPadding;
  final double hitSlop;
}

/// Returns true if [point] hits the polyline [points] with [thickness].
bool hitTestStroke(
  Offset point,
  List<Offset> points,
  double thickness, {
  StrokeHitOptions options = const StrokeHitOptions(),
}) {
  final baseThickness = clampNonNegativeFinite(thickness);
  final baseHitPadding = clampNonNegativeFinite(options.hitPadding);
  final baseHitSlop = clampNonNegativeFinite(
    options.hitSlop,
    fallback: kHitSlop,
  );
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

/// Returns true if [point] hits [node] in scene coordinates.
bool hitTestNode(Offset point, SceneNode node) {
  return nodeGeometryHitTest(point, node);
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

import 'dart:math' as math;
import 'dart:ui';

import 'numeric_tolerance.dart';

/// Converts a point from view/screen coordinates to scene coordinates.
Offset toScene(Offset viewPoint, Offset cameraOffset) {
  return viewPoint + cameraOffset;
}

/// Converts a point from scene coordinates to view/screen coordinates.
Offset toView(Offset scenePoint, Offset cameraOffset) {
  return scenePoint - cameraOffset;
}

/// Rotates [point] around [center] by [degrees].
Offset rotatePoint(Offset point, Offset center, double degrees) {
  final radians = degrees * math.pi / 180.0;
  final cosA = math.cos(radians);
  final sinA = math.sin(radians);
  final translated = point - center;
  final rotated = Offset(
    translated.dx * cosA - translated.dy * sinA,
    translated.dx * sinA + translated.dy * cosA,
  );
  return rotated + center;
}

/// Mirrors [point] across the vertical axis that passes through [axisX].
Offset reflectPointVertical(Offset point, double axisX) {
  final dx = axisX + (axisX - point.dx);
  return Offset(dx, point.dy);
}

/// Mirrors [point] across the horizontal axis that passes through [axisY].
Offset reflectPointHorizontal(Offset point, double axisY) {
  final dy = axisY + (axisY - point.dy);
  return Offset(point.dx, dy);
}

/// Returns the axis-aligned bounding box for [points].
Rect aabbFromPoints(Iterable<Offset> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) {
    return Rect.zero;
  }
  var minX = iterator.current.dx;
  var maxX = iterator.current.dx;
  var minY = iterator.current.dy;
  var maxY = iterator.current.dy;
  while (iterator.moveNext()) {
    final p = iterator.current;
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Computes an axis-aligned bounding box for a transformed rectangle.
///
/// [localRect] is specified in the node's local space around the origin.
/// Transform is applied in the order: scale -> rotate -> translate.
Rect aabbForTransformedRect({
  required Rect localRect,
  required Offset position,
  required double rotationDeg,
  required double scaleX,
  required double scaleY,
}) {
  final corners = <Offset>[
    Offset(localRect.left, localRect.top),
    Offset(localRect.right, localRect.top),
    Offset(localRect.right, localRect.bottom),
    Offset(localRect.left, localRect.bottom),
  ];

  final scaled = corners
      .map((c) => Offset(c.dx * scaleX, c.dy * scaleY))
      .toList(growable: false);

  final rotated = nearZero(rotationDeg)
      ? scaled
      : scaled
            .map((c) => rotatePoint(c, Offset.zero, rotationDeg))
            .toList(growable: false);

  final translated = rotated.map((c) => c + position).toList(growable: false);

  return aabbFromPoints(translated);
}

/// Returns the shortest distance from [point] to the segment [a]-[b].
double distancePointToSegment(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final ap = point - a;
  final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (abLen2 <= kEpsilonSquared) {
    return (point - a).distance;
  }
  var t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (point - projection).distance;
}

/// Returns true if segments [a1]-[a2] and [b1]-[b2] intersect.
bool segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
  // Scale epsilon with coordinate magnitude to keep orientation/on-segment
  // checks stable across tiny and large coordinate ranges.
  final deltaA = a2 - a1;
  final deltaB = b2 - b1;
  var maxScale = 1.0;

  void consider(double value) {
    final absValue = value.abs();
    if (absValue > maxScale) maxScale = absValue;
  }

  consider(a1.dx);
  consider(a1.dy);
  consider(a2.dx);
  consider(a2.dy);
  consider(b1.dx);
  consider(b1.dy);
  consider(b2.dx);
  consider(b2.dy);
  consider(deltaA.dx);
  consider(deltaA.dy);
  consider(deltaB.dx);
  consider(deltaB.dy);

  final orientationEpsilon = kEpsilon * maxScale * maxScale;
  final coordinateEpsilon = kEpsilon * maxScale;

  int orientationEps(Offset p, Offset q, Offset r) {
    final val = (q.dy - p.dy) * (r.dx - q.dx) - (q.dx - p.dx) * (r.dy - q.dy);
    if (val.abs() <= orientationEpsilon) return 0;
    return val > 0 ? 1 : 2;
  }

  bool onSegmentEps(Offset p, Offset q, Offset r) {
    return q.dx <= math.max(p.dx, r.dx) + coordinateEpsilon &&
        q.dx >= math.min(p.dx, r.dx) - coordinateEpsilon &&
        q.dy <= math.max(p.dy, r.dy) + coordinateEpsilon &&
        q.dy >= math.min(p.dy, r.dy) - coordinateEpsilon;
  }

  final o1 = orientationEps(a1, a2, b1);
  final o2 = orientationEps(a1, a2, b2);
  final o3 = orientationEps(b1, b2, a1);
  final o4 = orientationEps(b1, b2, a2);

  if (o1 != o2 && o3 != o4) return true;

  if (o1 == 0 && onSegmentEps(a1, b1, a2)) return true;
  if (o2 == 0 && onSegmentEps(a1, b2, a2)) return true;
  if (o3 == 0 && onSegmentEps(b1, a1, b2)) return true;
  if (o4 == 0 && onSegmentEps(b1, a2, b2)) return true;

  return false;
}

/// Returns the shortest distance between two line segments.
double distanceSegmentToSegment(Offset a1, Offset a2, Offset b1, Offset b2) {
  if (segmentsIntersect(a1, a2, b1, b2)) {
    return 0;
  }
  final d1 = distancePointToSegment(a1, b1, b2);
  final d2 = distancePointToSegment(a2, b1, b2);
  final d3 = distancePointToSegment(b1, a1, a2);
  final d4 = distancePointToSegment(b2, a1, a2);
  return math.min(math.min(d1, d2), math.min(d3, d4));
}

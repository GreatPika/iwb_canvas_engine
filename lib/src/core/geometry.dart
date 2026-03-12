import 'dart:math' as math;
import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../contract/transform_tolerance.dart' show kEpsilon;
import 'numeric_tolerance.dart' show kEpsilonSquared, nearZero;

class CenteredPathGeometry {
  const CenteredPathGeometry({
    required this.localPath,
    required this.localBounds,
  });

  final Path localPath;
  final Rect localBounds;
}

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
class RectTransformGeometry {
  const RectTransformGeometry({
    required this.position,
    required this.rotationDeg,
    required this.scaleX,
    required this.scaleY,
  });

  final Offset position;
  final double rotationDeg;
  final double scaleX;
  final double scaleY;
}

Rect aabbForTransformedRect({
  required Rect localRect,
  required RectTransformGeometry transform,
}) {
  final corners = <Offset>[
    Offset(localRect.left, localRect.top),
    Offset(localRect.right, localRect.top),
    Offset(localRect.right, localRect.bottom),
    Offset(localRect.left, localRect.bottom),
  ];

  final scaled = corners
      .map((c) => Offset(c.dx * transform.scaleX, c.dy * transform.scaleY))
      .toList(growable: false);

  final rotated = nearZero(transform.rotationDeg)
      ? scaled
      : scaled
            .map((c) => rotatePoint(c, Offset.zero, transform.rotationDeg))
            .toList(growable: false);

  final translated = rotated
      .map((c) => c + transform.position)
      .toList(growable: false);

  return aabbFromPoints(translated);
}

bool isFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}

bool areFiniteOffsets(Iterable<Offset> offsets) {
  for (final offset in offsets) {
    if (!isFiniteOffset(offset)) {
      return false;
    }
  }
  return true;
}

bool isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

Rect sanitizeFiniteRect(Rect rect) {
  return isFiniteRect(rect) ? rect : Rect.zero;
}

Rect lineLocalBounds({
  required Offset start,
  required Offset end,
  required double thickness,
}) {
  if (!isFiniteOffset(start) || !isFiniteOffset(end)) {
    return Rect.zero;
  }
  final safeThickness = thickness.isFinite && thickness > 0 ? thickness : 0;
  return sanitizeFiniteRect(
    Rect.fromPoints(start, end).inflate(safeThickness / 2),
  );
}

Rect strokeLocalBounds({
  required List<Offset> points,
  required double thickness,
}) {
  if (points.isEmpty || !areFiniteOffsets(points)) {
    return Rect.zero;
  }
  final safeThickness = thickness.isFinite && thickness > 0 ? thickness : 0;
  return sanitizeFiniteRect(aabbFromPoints(points).inflate(safeThickness / 2));
}

bool hasDrawablePathMetric(Path path) {
  for (final metric in path.computeMetrics()) {
    if (metric.length > 0) {
      return true;
    }
  }
  return false;
}

CenteredPathGeometry? buildCenteredSvgPathGeometry(
  String svgPathData, {
  required PathFillType fillType,
}) {
  if (svgPathData.trim().isEmpty) {
    return null;
  }
  try {
    final path = parseSvgPathDataOrThrow(svgPathData);
    if (!hasDrawablePathMetric(path)) {
      return null;
    }
    return centerPathGeometry(path, fillType: fillType);
  } catch (_) {
    return null;
  }
}

Path parseSvgPathDataOrThrow(String svgPathData) {
  return parseSvgPathData(svgPathData);
}

CenteredPathGeometry centerPathGeometry(
  Path path, {
  required PathFillType fillType,
}) {
  final bounds = path.getBounds();
  final centered = path.shift(-bounds.center);
  centered.fillType = fillType;
  final centeredBounds = sanitizeFiniteRect(centered.getBounds());
  return CenteredPathGeometry(localPath: centered, localBounds: centeredBounds);
}

/// Returns the shortest distance from [point] to the segment [a]-[b].
double distancePointToSegment(Offset point, Offset a, Offset b) {
  return math.sqrt(distanceSquaredPointToSegment(point, a, b));
}

/// Returns squared shortest distance from [point] to segment [a]-[b].
double distanceSquaredPointToSegment(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final ap = point - a;
  final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (abLen2 <= kEpsilonSquared) {
    final delta = point - a;
    return delta.dx * delta.dx + delta.dy * delta.dy;
  }
  var t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  final delta = point - projection;
  return delta.dx * delta.dx + delta.dy * delta.dy;
}

/// Returns true if segments [a1]-[a2] and [b1]-[b2] intersect.
bool segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
  final frame = _buildSegmentIntersectionFrame(a1, a2, b1, b2);
  if (frame == null) {
    return false;
  }
  final tolerance = _buildSegmentIntersectionTolerance(frame);
  final orientations = _segmentOrientations(frame, tolerance);
  if (_hasProperSegmentIntersection(orientations)) {
    return true;
  }
  return _hasCollinearSegmentIntersection(frame, tolerance, orientations);
}

/// Returns the shortest distance between two line segments.
double distanceSegmentToSegment(Offset a1, Offset a2, Offset b1, Offset b2) {
  return math.sqrt(distanceSquaredSegmentToSegment(a1, a2, b1, b2));
}

/// Returns squared shortest distance between line segments [a1]-[a2] and [b1]-[b2].
double distanceSquaredSegmentToSegment(
  Offset a1,
  Offset a2,
  Offset b1,
  Offset b2,
) {
  if (segmentsIntersect(a1, a2, b1, b2)) {
    return 0;
  }
  final d1 = distanceSquaredPointToSegment(a1, b1, b2);
  final d2 = distanceSquaredPointToSegment(a2, b1, b2);
  final d3 = distanceSquaredPointToSegment(b1, a1, a2);
  final d4 = distanceSquaredPointToSegment(b2, a1, a2);
  return math.min(math.min(d1, d2), math.min(d3, d4));
}

class _SegmentIntersectionFrame {
  const _SegmentIntersectionFrame({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
    required this.localScale,
    required this.absoluteScale,
  });

  final Offset p1;
  final Offset p2;
  final Offset p3;
  final Offset p4;
  final double localScale;
  final double absoluteScale;
}

class _SegmentIntersectionTolerance {
  const _SegmentIntersectionTolerance({
    required this.orientationEpsilon,
    required this.coordinateEpsilon,
  });

  final double orientationEpsilon;
  final double coordinateEpsilon;
}

_SegmentIntersectionFrame? _buildSegmentIntersectionFrame(
  Offset a1,
  Offset a2,
  Offset b1,
  Offset b2,
) {
  final p1 = Offset.zero;
  final p2 = a2 - a1;
  final p3 = b1 - a1;
  final p4 = b2 - a1;
  if (!isFiniteOffset(p2) || !isFiniteOffset(p3) || !isFiniteOffset(p4)) {
    return null;
  }
  return _SegmentIntersectionFrame(
    p1: p1,
    p2: p2,
    p3: p3,
    p4: p4,
    localScale: _maxOffsetMagnitude(<Offset>[p2, p3, p4]),
    absoluteScale: _maxOffsetMagnitude(<Offset>[a1, a2, b1, b2]),
  );
}

double _maxOffsetMagnitude(Iterable<Offset> offsets) {
  var scale = 1.0;
  for (final offset in offsets) {
    final dx = offset.dx.abs();
    final dy = offset.dy.abs();
    if (dx > scale) scale = dx;
    if (dy > scale) scale = dy;
  }
  return scale;
}

_SegmentIntersectionTolerance _buildSegmentIntersectionTolerance(
  _SegmentIntersectionFrame frame,
) {
  final localScaleSafe = frame.localScale < 1.0 ? 1.0 : frame.localScale;
  final precisionFactorRaw = frame.absoluteScale / localScaleSafe;
  final precisionFactor = precisionFactorRaw.isFinite
      ? precisionFactorRaw.clamp(1.0, 1e6).toDouble()
      : 1e6;
  return _SegmentIntersectionTolerance(
    orientationEpsilon:
        kEpsilon * localScaleSafe * localScaleSafe * precisionFactor,
    coordinateEpsilon: kEpsilon * localScaleSafe * precisionFactor,
  );
}

int _orientationWithTolerance(
  Offset p,
  Offset q,
  Offset r,
  _SegmentIntersectionTolerance tolerance,
) {
  final value = (q.dy - p.dy) * (r.dx - q.dx) - (q.dx - p.dx) * (r.dy - q.dy);
  if (!value.isFinite) return 0;
  if (value.abs() <= tolerance.orientationEpsilon) return 0;
  return value > 0 ? 1 : 2;
}

bool _pointOnSegmentWithinTolerance(
  Offset p,
  Offset q,
  Offset r,
  _SegmentIntersectionTolerance tolerance,
) {
  return q.dx <= math.max(p.dx, r.dx) + tolerance.coordinateEpsilon &&
      q.dx >= math.min(p.dx, r.dx) - tolerance.coordinateEpsilon &&
      q.dy <= math.max(p.dy, r.dy) + tolerance.coordinateEpsilon &&
      q.dy >= math.min(p.dy, r.dy) - tolerance.coordinateEpsilon;
}

bool _hasCollinearSegmentIntersection(
  _SegmentIntersectionFrame frame,
  _SegmentIntersectionTolerance tolerance,
  ({int o1, int o2, int o3, int o4}) orientations,
) {
  return (orientations.o1 == 0 &&
          _pointOnSegmentWithinTolerance(
            frame.p1,
            frame.p3,
            frame.p2,
            tolerance,
          )) ||
      (orientations.o2 == 0 &&
          _pointOnSegmentWithinTolerance(
            frame.p1,
            frame.p4,
            frame.p2,
            tolerance,
          )) ||
      (orientations.o3 == 0 &&
          _pointOnSegmentWithinTolerance(
            frame.p3,
            frame.p1,
            frame.p4,
            tolerance,
          )) ||
      (orientations.o4 == 0 &&
          _pointOnSegmentWithinTolerance(
            frame.p3,
            frame.p2,
            frame.p4,
            tolerance,
          ));
}

({int o1, int o2, int o3, int o4}) _segmentOrientations(
  _SegmentIntersectionFrame frame,
  _SegmentIntersectionTolerance tolerance,
) {
  return (
    o1: _orientationWithTolerance(frame.p1, frame.p2, frame.p3, tolerance),
    o2: _orientationWithTolerance(frame.p1, frame.p2, frame.p4, tolerance),
    o3: _orientationWithTolerance(frame.p3, frame.p4, frame.p1, tolerance),
    o4: _orientationWithTolerance(frame.p3, frame.p4, frame.p2, tolerance),
  );
}

bool _hasProperSegmentIntersection(
  ({int o1, int o2, int o3, int o4}) orientations,
) {
  return orientations.o1 != orientations.o2 &&
      orientations.o3 != orientations.o4;
}

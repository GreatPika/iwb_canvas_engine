import 'dart:math' as math;
import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';

const double kCanvasGeometryHitSlop = 4.0;
const int kCanvasMaxPathHitSamplesPerMetric = 2048;
const int kCanvasSpatialCellSize = 256;
const int kCanvasMaxCellsPerElement = 1024;
const int kCanvasMaxQueryCells = 50000;

const int kMaxEraserPreviewCandidatesPerSample = 512;
const int kMaxEraserPreviewExactChecksPerSample = 4096;
const int kMaxEraserTerminalCandidates = 4096;
const int kMaxEraserTerminalExactChecks = 32768;

final class GeometryPolicy {
  const GeometryPolicy();

  GeometryBounds boundsFor(FrameElementFacts facts) {
    final local = _localGeometryMetricsFor(facts);
    if (_isEmptyLocalBounds(local.paintBounds) ||
        !isFiniteTransform(facts.transform)) {
      return GeometryBounds.empty(facts.id);
    }

    return _geometryBoundsFor(facts, local);
  }

  bool isHitEligible(FrameElementFacts facts, Offset point) {
    return isFiniteOffset(point) &&
        facts.isVisible &&
        facts.isSelectable &&
        facts.locationKind == FrameElementLocationKind.content &&
        isFiniteTransform(facts.transform);
  }

  bool admitsPaintCandidate(FrameElementFacts facts, Rect queryRect) {
    if (!facts.isVisible || !isFiniteRect(queryRect)) {
      return false;
    }

    return queryRect.overlaps(boundsFor(facts).paintBoundsWorld);
  }

  bool isMarqueeCandidate(FrameElementFacts facts, Rect marqueeRect) {
    if (!isHitEligible(facts, marqueeRect.center) ||
        !isFiniteRect(marqueeRect)) {
      return false;
    }

    return boundsFor(
      facts,
    ).hitBoundsWorld.overlaps(_normalizeRect(marqueeRect));
  }

  EraserCorridor corridorEnvelope({
    required List<Offset> points,
    required double eraserThickness,
    required double hitPadding,
  }) {
    final hasOnlyFinitePoints = points.every(isFiniteOffset);
    final finitePoints = hasOnlyFinitePoints
        ? List<Offset>.unmodifiable(points)
        : const <Offset>[];
    final radius =
        clampNonNegativeFinite(eraserThickness) / 2 +
        clampNonNegativeFinite(hitPadding) +
        kCanvasGeometryHitSlop;
    final exactRadius = clampNonNegativeFinite(eraserThickness) / 2;

    return EraserCorridor(
      points: finitePoints,
      envelopeWorld: finitePoints.isEmpty
          ? Rect.zero
          : sanitizeFiniteRect(aabbFromPoints(finitePoints).inflate(radius)),
      radiusWorld: radius,
      exactRadiusWorld: exactRadius,
    );
  }

  EraserExactBudgetInputs eraserPreviewBudgetInputs(int sampleCount) {
    return EraserExactBudgetInputs(
      candidateLimit: kMaxEraserPreviewCandidatesPerSample * sampleCount,
      exactCheckLimit: kMaxEraserPreviewExactChecksPerSample * sampleCount,
    );
  }

  EraserExactBudgetInputs eraserTerminalBudgetInputs() {
    return const EraserExactBudgetInputs(
      candidateLimit: kMaxEraserTerminalCandidates,
      exactCheckLimit: kMaxEraserTerminalExactChecks,
    );
  }
}

Rect _hitBoundsWorld(FrameElementFacts facts, Rect localBounds) {
  final padding = _scenePadding(facts.hitPadding);
  if (facts.kind == CanvasElementKind.line ||
      facts.kind == CanvasElementKind.stroke) {
    return _lineFamilyHitBoundsWorld(facts, padding);
  }

  return facts.transform.applyToRect(localBounds).inflate(padding);
}

GeometryBounds _geometryBoundsFor(
  FrameElementFacts facts,
  _LocalGeometryMetrics local,
) {
  final paintBounds = facts.transform.applyToRect(local.paintBounds);
  final selectionBounds = facts.transform.applyToRect(local.selectionBounds);
  final editBounds = facts.transform.applyToRect(local.editBounds);
  final hitBounds =
      _requiresInvertibleHitBounds(facts.kind) && !facts.transform.isInvertible
      ? Rect.zero
      : _hitBoundsWorld(facts, local.hitBounds);

  return GeometryBounds(
    id: facts.id,
    localBounds: sanitizeFiniteRect(local.paintBounds),
    hitBoundsLocal: sanitizeFiniteRect(local.hitBounds),
    selectionBoundsLocal: sanitizeFiniteRect(local.selectionBounds),
    editBoundsLocal: sanitizeFiniteRect(local.editBounds),
    hitBoundsWorld: sanitizeFiniteRect(hitBounds),
    paintBoundsWorld: facts.isVisible
        ? sanitizeFiniteRect(paintBounds)
        : Rect.zero,
    selectionBoundsWorld: facts.isVisible
        ? sanitizeFiniteRect(selectionBounds)
        : Rect.zero,
    editBoundsWorld: facts.isVisible
        ? sanitizeFiniteRect(editBounds)
        : Rect.zero,
  );
}

_LocalGeometryMetrics _localGeometryMetricsFor(FrameElementFacts facts) {
  final paintBounds = _localBoundsFor(facts);

  return _LocalGeometryMetrics(
    paintBounds: paintBounds,
    hitBounds: _hitBoundsLocalFor(facts, fallback: paintBounds),
    selectionBounds: _selectionBoundsLocalFor(facts, fallback: paintBounds),
    editBounds: _editBoundsLocalFor(facts, fallback: paintBounds),
  );
}

Rect _localBoundsFor(FrameElementFacts facts) {
  return switch (facts.kind) {
    CanvasElementKind.image => _sizedBounds(facts.size),
    CanvasElementKind.rect => _rectBounds(facts),
    CanvasElementKind.text => _textBounds(facts),
    CanvasElementKind.line => _lineBounds(facts),
    CanvasElementKind.stroke => _strokeBounds(facts),
    CanvasElementKind.path => _pathBounds(facts),
  };
}

bool _isEmptyLocalBounds(Rect bounds) {
  return bounds == Rect.zero && bounds.width == 0 && bounds.height == 0;
}

bool _requiresInvertibleHitBounds(CanvasElementKind kind) {
  return switch (kind) {
    CanvasElementKind.image ||
    CanvasElementKind.rect ||
    CanvasElementKind.text => true,
    CanvasElementKind.line ||
    CanvasElementKind.stroke ||
    CanvasElementKind.path => false,
  };
}

final class GeometryBounds {
  const GeometryBounds({
    required this.id,
    required this.localBounds,
    required this.hitBoundsLocal,
    required this.selectionBoundsLocal,
    required this.editBoundsLocal,
    required this.hitBoundsWorld,
    required this.paintBoundsWorld,
    required this.selectionBoundsWorld,
    required this.editBoundsWorld,
  });

  const GeometryBounds.empty(this.id)
    : localBounds = Rect.zero,
      hitBoundsLocal = Rect.zero,
      selectionBoundsLocal = Rect.zero,
      editBoundsLocal = Rect.zero,
      hitBoundsWorld = Rect.zero,
      paintBoundsWorld = Rect.zero,
      selectionBoundsWorld = Rect.zero,
      editBoundsWorld = Rect.zero;

  final CanvasElementId id;
  final Rect localBounds;
  final Rect hitBoundsLocal;
  final Rect selectionBoundsLocal;
  final Rect editBoundsLocal;
  final Rect hitBoundsWorld;
  final Rect paintBoundsWorld;
  final Rect selectionBoundsWorld;
  final Rect editBoundsWorld;
}

final class _LocalGeometryMetrics {
  const _LocalGeometryMetrics({
    required this.paintBounds,
    required this.hitBounds,
    required this.selectionBounds,
    required this.editBounds,
  });

  final Rect paintBounds;
  final Rect hitBounds;
  final Rect selectionBounds;
  final Rect editBounds;
}

final class EraserCorridor {
  const EraserCorridor({
    required this.points,
    required this.envelopeWorld,
    required this.radiusWorld,
    required this.exactRadiusWorld,
  });

  final List<Offset> points;
  final Rect envelopeWorld;
  final double radiusWorld;
  final double exactRadiusWorld;
}

final class EraserExactBudgetInputs {
  const EraserExactBudgetInputs({
    required this.candidateLimit,
    required this.exactCheckLimit,
  });

  final int candidateLimit;
  final int exactCheckLimit;
}

bool isFiniteOffset(Offset offset) => offset.dx.isFinite && offset.dy.isFinite;

bool isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool isFiniteTransform(CanvasTransform transform) {
  return transform.a.isFinite &&
      transform.b.isFinite &&
      transform.c.isFinite &&
      transform.d.isFinite &&
      transform.tx.isFinite &&
      transform.ty.isFinite;
}

Rect sanitizeFiniteRect(Rect rect) => isFiniteRect(rect) ? rect : Rect.zero;

Rect aabbFromPoints(Iterable<Offset> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) {
    return Rect.zero;
  }
  var minX = iterator.current.dx;
  var minY = iterator.current.dy;
  var maxX = iterator.current.dx;
  var maxY = iterator.current.dy;
  while (iterator.moveNext()) {
    minX = math.min(minX, iterator.current.dx);
    minY = math.min(minY, iterator.current.dy);
    maxX = math.max(maxX, iterator.current.dx);
    maxY = math.max(maxY, iterator.current.dy);
  }

  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

double clampNonNegativeFinite(double value) {
  if (!value.isFinite || value < 0) {
    return 0;
  }

  return value;
}

double distanceSquaredPointToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final pointVector = point - start;
  final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
  if (lengthSquared <= 1e-24) {
    final delta = point - start;

    return delta.dx * delta.dx + delta.dy * delta.dy;
  }
  final rawT =
      (pointVector.dx * segment.dx + pointVector.dy * segment.dy) /
      lengthSquared;
  final t = rawT.clamp(0, 1).toDouble();
  final projection = Offset(
    start.dx + segment.dx * t,
    start.dy + segment.dy * t,
  );
  final delta = point - projection;

  return delta.dx * delta.dx + delta.dy * delta.dy;
}

double maxScale(CanvasTransform transform) {
  final trace =
      transform.a * transform.a +
      transform.b * transform.b +
      transform.c * transform.c +
      transform.d * transform.d;
  final determinant = transform.a * transform.d - transform.b * transform.c;
  final discriminant = math.max(
    0,
    trace * trace - 4 * determinant * determinant,
  );

  return math.sqrt(math.max(0, (trace + math.sqrt(discriminant)) / 2));
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

Rect _sizedBounds(Size? size) {
  final safe = Size(
    clampNonNegativeFinite(size?.width ?? 0),
    clampNonNegativeFinite(size?.height ?? 0),
  );

  return Rect.fromCenter(
    center: Offset.zero,
    width: safe.width,
    height: safe.height,
  );
}

Rect _rectBounds(FrameElementFacts facts) {
  return _strokeAwareBounds(
    baseBounds: _sizedBounds(facts.size),
    strokeColor: facts.strokeColor,
    strokeWidth: facts.strokeWidth ?? 0,
  );
}

Rect _strokeAwareBounds({
  required Rect baseBounds,
  required Color? strokeColor,
  required double strokeWidth,
}) {
  if (strokeColor == null) {
    return baseBounds;
  }
  final effectiveWidth = clampNonNegativeFinite(strokeWidth);
  if (effectiveWidth <= 0) {
    return baseBounds;
  }

  return baseBounds.inflate(effectiveWidth / 2);
}

Rect _textBounds(FrameElementFacts facts) {
  return facts.measuredTextLayout?.paintBoundsLocal ?? Rect.zero;
}

Rect _hitBoundsLocalFor(FrameElementFacts facts, {required Rect fallback}) {
  if (facts.kind == CanvasElementKind.text) {
    return facts.measuredTextLayout?.hitBoundsLocal ?? Rect.zero;
  }

  return fallback;
}

Rect _selectionBoundsLocalFor(
  FrameElementFacts facts, {
  required Rect fallback,
}) {
  if (facts.kind == CanvasElementKind.text) {
    return facts.measuredTextLayout?.selectionBoundsLocal ?? Rect.zero;
  }

  return fallback;
}

Rect _editBoundsLocalFor(FrameElementFacts facts, {required Rect fallback}) {
  if (facts.kind == CanvasElementKind.text) {
    return facts.measuredTextLayout?.editBoundsLocal ?? Rect.zero;
  }

  return fallback;
}

Rect _lineBounds(FrameElementFacts facts) {
  final start = facts.start;
  final end = facts.end;
  if (start == null ||
      end == null ||
      !isFiniteOffset(start) ||
      !isFiniteOffset(end)) {
    return Rect.zero;
  }
  final thickness = clampNonNegativeFinite(facts.thickness ?? 0);
  final minHalfThickness = start == end ? 0.5 : 0.0;

  return Rect.fromPoints(
    start,
    end,
  ).inflate(math.max(thickness / 2, minHalfThickness));
}

Rect _strokeBounds(FrameElementFacts facts) {
  if (facts.points.isEmpty ||
      facts.points.any((point) => !isFiniteOffset(point))) {
    return Rect.zero;
  }
  final thickness = clampNonNegativeFinite(facts.thickness ?? 0);
  final minHalfThickness = facts.points.length == 1 ? 0.5 : 0.0;

  return aabbFromPoints(
    facts.points,
  ).inflate(math.max(thickness / 2, minHalfThickness));
}

Rect _lineFamilyHitBoundsWorld(FrameElementFacts facts, double padding) {
  final points = switch (facts.kind) {
    CanvasElementKind.line => _linePoints(facts),
    CanvasElementKind.stroke => facts.points,
    _ => const <Offset>[],
  };
  if (points.isEmpty || points.any((point) => !isFiniteOffset(point))) {
    return Rect.zero;
  }
  final worldPoints = points
      .map(facts.transform.applyToPoint)
      .toList(growable: false);
  final radius =
      maxScale(facts.transform) *
          clampNonNegativeFinite(facts.thickness ?? 0) /
          2 +
      padding;

  return aabbFromPoints(worldPoints).inflate(radius);
}

List<Offset> _linePoints(FrameElementFacts facts) {
  final start = facts.start;
  final end = facts.end;
  if (start == null || end == null) {
    return const [];
  }

  return [start, end];
}

Rect _pathBounds(FrameElementFacts facts) {
  final path = ParsedSvgPath.parse(
    facts.svgPathData ?? '',
    fillRule: facts.fillRule ?? CanvasPathFillRule.nonZero,
  );
  if (path == null) {
    return Rect.zero;
  }
  final strokeWidth = facts.strokeColor == null
      ? 0.0
      : clampNonNegativeFinite(facts.strokeWidth ?? 0);

  return path.bounds.inflate(strokeWidth / 2);
}

final class ParsedSvgPath {
  const ParsedSvgPath({required this.path, required this.bounds});

  static ParsedSvgPath? parse(
    String source, {
    required CanvasPathFillRule fillRule,
  }) {
    if (source.trim().isEmpty) {
      return null;
    }
    try {
      final parsed = parseSvgPathData(source);
      final bounds = sanitizeFiniteRect(parsed.getBounds());
      if (bounds == Rect.zero || !_hasDrawableMetric(parsed)) {
        return null;
      }
      final centered = parsed.shift(-bounds.center)
        ..fillType = switch (fillRule) {
          CanvasPathFillRule.nonZero => PathFillType.nonZero,
          CanvasPathFillRule.evenOdd => PathFillType.evenOdd,
        };

      return ParsedSvgPath(
        path: centered,
        bounds: sanitizeFiniteRect(centered.getBounds()),
      );
    } catch (error) {
      if (!_isSvgPathParseFailure(error)) {
        rethrow;
      }

      return null;
    }
  }

  final Path path;
  final Rect bounds;
}

Path? normalizedSvgPathForPaint(
  String source, {
  required CanvasPathFillRule fillRule,
}) {
  return ParsedSvgPath.parse(source, fillRule: fillRule)?.path;
}

bool _isSvgPathParseFailure(Object error) {
  return error is Exception || error is StateError || error is ArgumentError;
}

bool _hasDrawableMetric(Path path) {
  for (final metric in path.computeMetrics()) {
    if (metric.length > 0) {
      return true;
    }
  }

  return false;
}

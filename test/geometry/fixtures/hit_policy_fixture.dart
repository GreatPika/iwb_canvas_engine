import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/measured_text_layout.dart';
import 'package:iwb_canvas_engine/src/frame/frame_text_layout_measurer.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/hit_test_policy.dart';

void main() {
  _testConstants();
  _testBounds();
  _testCorruptedBounds();
  _testFamilyHits();
  _testNearSingularInternalHitInverse();
  _testTopmostResolution();
  _testPaintAdmission();
  _testMarqueeExactInclusion();
  _testCorruptedRowsMissWithoutMutation();
  _testCorruptedLineStrokeRowsMiss();
}

void _testConstants() {
  test('constants follow the geometry contract', () {
    expect(kCanvasGeometryHitSlop, 4);
    expect(kCanvasMaxPathHitSamplesPerMetric, 2048);
    expect(kCanvasSpatialCellSize, 256);
    expect(kCanvasMaxCellsPerElement, 1024);
    expect(kCanvasMaxQueryCells, 50000);
  });
}

void _testBounds() {
  test('bounds follow the geometry contract', () {
    final bounds = const GeometryPolicy().boundsFor(
      _rect('rect', const _RectSpec(size: Size(20, 10), hitPadding: 2)),
    );
    final stroked = const GeometryPolicy().boundsFor(_strokedRect());

    expect(bounds.localBounds, const Rect.fromLTRB(-10, -5, 10, 5));
    expect(bounds.hitBoundsWorld, const Rect.fromLTRB(-16, -11, 16, 11));
    expect(bounds.paintBoundsWorld, const Rect.fromLTRB(-10, -5, 10, 5));
    expect(stroked.localBounds, const Rect.fromLTRB(-12, -12, 12, 12));
  });
}

void _testCorruptedBounds() {
  test('non-invertible box-family hit bounds are empty', () {
    final corruptedBounds = const GeometryPolicy().boundsFor(_singularRect());

    expect(corruptedBounds.hitBoundsWorld, Rect.zero);
  });
}

void _testFamilyHits() {
  test('all family exact-hit paths are executable', () {
    expect(() {
      _expectBoxFamilyHits();
      _expectLineAndStrokeFamilyHits();
      _expectPathFamilyHits();
    }, returnsNormally);
  });
}

void _expectBoxFamilyHits() {
  const policy = HitTestPolicy();
  expect(policy.exactHit(point: Offset.zero, facts: _rect('rect')), isTrue);
  expect(
    policy.exactHit(point: const Offset(9, 0), facts: _rect('rect')),
    isTrue,
  );
  expect(
    policy.exactHit(point: const Offset(0, 9), facts: _rect('rect')),
    isTrue,
  );
  expect(policy.exactHit(point: Offset.zero, facts: _image()), isTrue);
  expect(policy.exactHit(point: Offset.zero, facts: _text()), isTrue);
  expect(
    policy.exactHit(point: Offset.zero, facts: _unmeasuredText()),
    isFalse,
  );
}

void _expectLineAndStrokeFamilyHits() {
  const policy = HitTestPolicy();
  expect(policy.exactHit(point: const Offset(0, 3), facts: _lineHit()), isTrue);
  expect(policy.exactHit(point: const Offset(0, 5), facts: _lineHit()), isTrue);
  expect(
    policy.exactHit(point: const Offset(0, 100), facts: _anisotropicLine()),
    isTrue,
  );
  expect(
    policy.exactHit(point: Offset.zero, facts: _singularVerticalLine()),
    isTrue,
  );
  expect(
    policy.exactHit(point: const Offset(2, 0), facts: _strokeSegment()),
    isTrue,
  );
  expect(
    policy.exactHit(point: const Offset(5, 5), facts: _strokeSegment()),
    isTrue,
  );
  expect(
    policy.exactHit(point: const Offset(1, 1), facts: _strokePoint()),
    isTrue,
  );
}

void _expectPathFamilyHits() {
  const policy = HitTestPolicy();
  expect(policy.exactHit(point: Offset.zero, facts: _pathFill()), isTrue);
  expect(
    policy.exactHit(point: const Offset(0, -6), facts: _pathFill()),
    isTrue,
  );
  expect(
    policy.exactHit(point: const Offset(-4, -6.2), facts: _shearedPathFill()),
    isTrue,
  );
  expect(
    policy.exactHit(point: const Offset(0, -4), facts: _pathStroke()),
    isTrue,
  );
  expect(
    policy.exactHit(point: Offset.zero, facts: _openPathStroke()),
    isFalse,
  );
  expect(
    policy.exactHit(point: const Offset(0, 20), facts: _pathFill()),
    isFalse,
  );
  expect(policy.exactHit(point: Offset.zero, facts: _invalidPath()), isFalse);
  expect(
    const GeometryPolicy().boundsFor(_invalidPath()).localBounds,
    Rect.zero,
  );
}

void _testNearSingularInternalHitInverse() {
  test(
    'near-singular transforms hit-test without public inverse admission',
    () {
      const policy = HitTestPolicy();
      final rect = _rect(
        'near-singular-rect',
        _RectSpec(transform: _nearSingularTranslatedTransform),
      );

      expect(() {
        _expectNearSingularRectHits(policy, rect);
        _expectNearSingularPathHits(policy, _nearSingularPath());
      }, returnsNormally);
    },
  );
}

void _expectNearSingularRectHits(HitTestPolicy policy, FrameElementFacts rect) {
  expect(
    () => policy.exactHit(point: const Offset(2000, 0), facts: rect),
    returnsNormally,
  );
  expect(policy.exactHit(point: const Offset(2000, 0), facts: rect), isTrue);
  expect(
    policy.exactContextHit(point: const Offset(2000, 0), facts: rect),
    isTrue,
  );
  expect(policy.exactHit(point: const Offset(2005, 0), facts: rect), isFalse);
}

void _expectNearSingularPathHits(HitTestPolicy policy, FrameElementFacts path) {
  expect(policy.exactHit(point: const Offset(2000, 0), facts: path), isTrue);
  expect(
    policy.exactContextHit(point: const Offset(2007, 0), facts: path),
    isFalse,
  );
}

FrameElementFacts _nearSingularPath() {
  return _facts(
    _FactSpec(
      id: 'near-singular-path',
      kind: CanvasElementKind.path,
      svgPathData: 'M 0 0 L 10 0 L 10 10 L 0 10 Z',
      fillColor: const Color(0xff000000),
      fillRule: CanvasPathFillRule.nonZero,
      transform: _nearSingularTranslatedTransform,
    ),
  );
}

void _testTopmostResolution() {
  test('order-token topmost resolution ignores background candidates', () {
    const policy = HitTestPolicy();
    final stack = _hitStack();
    final result = policy.topmostHitResult(
      point: Offset.zero,
      candidates: stack.values.map(_handleFor),
      resolve: (handle) => stack[handle.id],
    );

    expect(
      policy.topmostHit(
        point: Offset.zero,
        candidates: stack.values.map(_handleFor),
        resolve: (handle) => stack[handle.id],
      ),
      CanvasElementId('upper'),
    );
    expect(result?.id, CanvasElementId('upper'));
    expect(result?.orderToken, 2);
  });
}

Map<CanvasElementId, FrameElementFacts> _hitStack() {
  final lower = _rect('lower', const _RectSpec(orderToken: 1));
  final upper = _line(
    'upper',
    const _LineSpec(
      orderToken: 2,
      start: Offset(-5, 0),
      end: Offset(5, 0),
      thickness: 2,
    ),
  );
  final background = _rect(
    'background',
    const _RectSpec(
      orderToken: 3,
      locationKind: FrameElementLocationKind.background,
    ),
  );

  return {
    for (final value in [lower, upper, background]) value.id: value,
  };
}

void _testPaintAdmission() {
  _testVisiblePaintAdmission();
  _testBackgroundPaintAdmission();
  _testPaintEdgeTouchAdmission();
}

void _testVisiblePaintAdmission() {
  test('paint admission uses paint bounds and visibility', () {
    const geometry = GeometryPolicy();
    final invisible = _rect('invisible', const _RectSpec(isVisible: false));
    final selectable = _rect('selectable', const _RectSpec(hitPadding: 2));

    expect(
      geometry.admitsPaintCandidate(
        selectable,
        const Rect.fromLTRB(4, 4, 20, 20),
      ),
      isTrue,
    );
    expect(
      geometry.admitsPaintCandidate(
        invisible,
        const Rect.fromLTRB(-10, -10, 10, 10),
      ),
      isFalse,
    );
  });
}

void _testBackgroundPaintAdmission() {
  test('paint admission includes background elements', () {
    const geometry = GeometryPolicy();
    final background = _rect(
      'painted-background',
      const _RectSpec(locationKind: FrameElementLocationKind.background),
    );

    expect(
      geometry.admitsPaintCandidate(
        background,
        const Rect.fromLTRB(4, 4, 20, 20),
      ),
      isTrue,
    );
  });
}

void _testPaintEdgeTouchAdmission() {
  test('paint admission rejects edge-touch query rectangles', () {
    const geometry = GeometryPolicy();
    final selectable = _rect('selectable');

    expect(
      geometry.admitsPaintCandidate(
        selectable,
        const Rect.fromLTRB(10, -5, 20, 5),
      ),
      isFalse,
    );
    expect(
      geometry.admitsPaintCandidate(
        selectable,
        const Rect.fromLTRB(-5, 5, 5, 10),
      ),
      isFalse,
    );
    expect(
      geometry.admitsPaintCandidate(
        selectable,
        const Rect.fromLTRB(-20, -5, -10, 5),
      ),
      isFalse,
    );
    expect(
      geometry.admitsPaintCandidate(
        selectable,
        const Rect.fromLTRB(-5, -10, 5, -5),
      ),
      isFalse,
    );
  });
}

void _testMarqueeExactInclusion() {
  _testMarqueeBoxSelection();
  _testMarqueeLineMisses();
  _testMarqueePathMiss();
}

void _testMarqueeBoxSelection() {
  test('marquee includes selectable content and excludes background', () {
    const hit = HitTestPolicy();
    final selectable = _rect('selectable', const _RectSpec(hitPadding: 2));
    final background = _rect(
      'marquee-background',
      const _RectSpec(locationKind: FrameElementLocationKind.background),
    );

    expect(
      hit.exactMarquee(
        marquee: const Rect.fromLTRB(4, 0, 20, 20),
        facts: selectable,
      ),
      isTrue,
    );
    expect(
      hit.exactMarquee(
        marquee: const Rect.fromLTRB(-1, -1, 1, 1),
        facts: background,
      ),
      isFalse,
    );
    expect(
      hit.exactMarquee(
        marquee: const Rect.fromLTRB(5, 5, 6, 6),
        facts: _rotatedRect(),
      ),
      isFalse,
    );
  });
}

void _testMarqueeLineMisses() {
  test('marquee rejects line and stroke misses after coarse overlap', () {
    const hit = HitTestPolicy();

    expect(
      hit.exactMarquee(marquee: _missRect, facts: _diagonalLine()),
      isFalse,
    );
    expect(
      hit.exactMarquee(marquee: _farCollinearRect, facts: _farCollinearLine()),
      isFalse,
    );
    expect(
      hit.exactMarquee(
        marquee: _verticalCollinearExtensionRect,
        facts: _verticalCollinearLine(),
      ),
      isFalse,
    );
    expect(
      hit.exactMarquee(
        marquee: _cornerDistanceRect,
        facts: _cornerStrokePoint(),
      ),
      isFalse,
    );
  });
}

void _testMarqueePathMiss() {
  test('marquee rejects sparse path misses after coarse overlap', () {
    const hit = HitTestPolicy();

    expect(
      hit.exactMarquee(
        marquee: _sparsePathMissRect,
        facts: _openCornerPathStroke(),
      ),
      isFalse,
    );
    expect(
      hit.exactMarquee(
        marquee: const Rect.fromLTRB(9, 9, 10, 10),
        facts: _rotatedPathFill(),
      ),
      isFalse,
    );
    expect(
      hit.exactMarquee(
        marquee: _cornerDistanceRect,
        facts: _cornerPathStroke(),
      ),
      isFalse,
    );
  });
}

const _missRect = Rect.fromLTRB(13, -5, 15, -3);
const _sparsePathMissRect = Rect.fromLTRB(-40, 20, -30, 30);
const _farCollinearRect = Rect.fromLTRB(20, 0, 21, 1);
const _verticalCollinearExtensionRect = Rect.fromLTRB(-1, -1, 1, 1);
const _cornerDistanceRect = Rect.fromLTRB(0, 0, 10, 10);

void _testCorruptedRowsMissWithoutMutation() {
  test('non-hit-eligible and unresolved rows miss without mutation', () {
    const policy = HitTestPolicy();
    final facts = _rect('rect', const _RectSpec(isSelectable: false));
    final singular = _rect(
      'singular',
      _RectSpec(
        transform: CanvasTransform(a: 1, b: 0, c: 0, d: 0, tx: 0, ty: 0),
      ),
    );
    var resolveCount = 0;

    expect(policy.exactHit(point: Offset.zero, facts: facts), isFalse);
    expect(policy.exactHit(point: Offset.zero, facts: singular), isFalse);
    expect(
      policy.topmostHit(
        point: Offset.zero,
        candidates: [_handleFor(facts)],
        resolve: (_) {
          resolveCount += 1;

          return null;
        },
      ),
      isNull,
    );
    expect(resolveCount, 1);
  });
}

void _testCorruptedLineStrokeRowsMiss() {
  test('non-finite line and stroke rows miss without mutation', () {
    const policy = HitTestPolicy();

    expect(
      policy.exactHit(point: Offset.zero, facts: _nonFiniteLine()),
      isFalse,
    );
    expect(
      const GeometryPolicy().boundsFor(_nonFiniteLine()).hitBoundsWorld,
      Rect.zero,
    );
    expect(
      policy.exactHit(point: Offset.zero, facts: _nonFiniteStroke()),
      isFalse,
    );
    expect(
      const GeometryPolicy().boundsFor(_nonFiniteStroke()).hitBoundsWorld,
      Rect.zero,
    );
  });
}

FrameElementFacts _image() {
  return _facts(
    const _FactSpec(
      id: 'image',
      kind: CanvasElementKind.image,
      size: Size(10, 10),
    ),
  );
}

FrameElementFacts _text() {
  return _facts(
    const _FactSpec(
      id: 'text',
      kind: CanvasElementKind.text,
      text: 'text',
      fontSize: 10,
      measuredText: true,
    ),
  );
}

FrameElementFacts _unmeasuredText() {
  return _facts(
    const _FactSpec(
      id: 'unmeasured-text',
      kind: CanvasElementKind.text,
      text: 'text',
      fontSize: 10,
    ),
  );
}

FrameElementFacts _lineHit() {
  return _line(
    'line',
    const _LineSpec(start: Offset.zero, end: Offset.zero, thickness: 2),
  );
}

FrameElementFacts _diagonalLine() {
  return _line(
    'diagonal',
    const _LineSpec(start: Offset.zero, end: Offset(10, 10), thickness: 2),
  );
}

FrameElementFacts _anisotropicLine() {
  return _line(
    'anisotropic',
    _LineSpec(
      start: const Offset(-1, 0),
      end: const Offset(1, 0),
      thickness: 2,
      transform: CanvasTransform.scale(100, 1),
    ),
  );
}

FrameElementFacts _farCollinearLine() {
  return _line(
    'far-collinear',
    const _LineSpec(start: Offset.zero, end: Offset(10, 0), thickness: 2),
  );
}

FrameElementFacts _verticalCollinearLine() {
  return _line(
    'vertical-collinear',
    const _LineSpec(start: Offset(0, 10), end: Offset(0, 20), thickness: 0),
  );
}

FrameElementFacts _nonFiniteLine() {
  return _line(
    'non-finite-line',
    const _LineSpec(
      start: Offset(double.nan, 0),
      end: Offset(10, 0),
      thickness: 2,
    ),
  );
}

FrameElementFacts _singularVerticalLine() {
  return _line(
    'singular-line',
    _LineSpec(
      start: const Offset(0, -5),
      end: const Offset(0, 5),
      thickness: 2,
      transform: CanvasTransform(a: 0, b: 0, c: 0, d: 1, tx: 0, ty: 0),
    ),
  );
}

FrameElementFacts _strokeSegment() {
  return _facts(
    const _FactSpec(
      id: 'stroke-segment',
      kind: CanvasElementKind.stroke,
      points: [Offset(0, 0), Offset(10, 0)],
      thickness: 2,
    ),
  );
}

FrameElementFacts _strokePoint() {
  return _facts(
    const _FactSpec(
      id: 'stroke-point',
      kind: CanvasElementKind.stroke,
      points: [Offset.zero],
      thickness: 2,
    ),
  );
}

FrameElementFacts _cornerStrokePoint() {
  return _facts(
    const _FactSpec(
      id: 'corner-stroke-point',
      kind: CanvasElementKind.stroke,
      points: [Offset(13, 13)],
      thickness: 0,
    ),
  );
}

FrameElementFacts _nonFiniteStroke() {
  return _facts(
    const _FactSpec(
      id: 'non-finite-stroke',
      kind: CanvasElementKind.stroke,
      points: [Offset.zero, Offset(double.nan, 1)],
      thickness: 2,
    ),
  );
}

FrameElementFacts _pathFill() {
  return _facts(
    const _FactSpec(
      id: 'path-fill',
      kind: CanvasElementKind.path,
      svgPathData: 'M 0 0 L 10 0 L 10 10 L 0 10 Z',
      fillColor: Color(0xff000000),
      fillRule: CanvasPathFillRule.nonZero,
      hitPadding: 2,
    ),
  );
}

FrameElementFacts _pathStroke() {
  return _facts(
    const _FactSpec(
      id: 'path-stroke',
      kind: CanvasElementKind.path,
      svgPathData: 'M 0 0 L 10 0',
      strokeColor: Color(0xff000000),
      strokeWidth: 2,
    ),
  );
}

FrameElementFacts _shearedPathFill() {
  return _facts(
    _FactSpec(
      id: 'sheared-path-fill',
      kind: CanvasElementKind.path,
      svgPathData: 'M 0 0 L 10 0 L 10 10 L 0 10 Z',
      fillColor: const Color(0xff000000),
      fillRule: CanvasPathFillRule.nonZero,
      hitPadding: 1,
      transform: CanvasTransform(a: 1, b: 0, c: 2, d: 1, tx: 0, ty: 0),
    ),
  );
}

FrameElementFacts _openPathStroke() {
  return _facts(
    const _FactSpec(
      id: 'open-path-stroke',
      kind: CanvasElementKind.path,
      svgPathData: 'M 0 0 L 10 0 L 10 10',
      strokeColor: Color(0xff000000),
      strokeWidth: 0.5,
    ),
  );
}

FrameElementFacts _openCornerPathStroke() {
  return _facts(
    const _FactSpec(
      id: 'open-corner-path-stroke',
      kind: CanvasElementKind.path,
      svgPathData: 'M 0 0 L 100 0 L 100 100',
      strokeColor: Color(0xff000000),
      strokeWidth: 1,
    ),
  );
}

FrameElementFacts _cornerPathStroke() {
  return _facts(
    _FactSpec(
      id: 'corner-path-stroke',
      kind: CanvasElementKind.path,
      svgPathData: 'M 13 13 L 14 13',
      strokeColor: const Color(0xff000000),
      strokeWidth: 0.1,
      transform: CanvasTransform.translation(const Offset(13.5, 13)),
    ),
  );
}

FrameElementFacts _invalidPath() {
  return _facts(
    const _FactSpec(
      id: 'invalid-path',
      kind: CanvasElementKind.path,
      svgPathData: 'M',
      fillColor: Color(0xff000000),
      fillRule: CanvasPathFillRule.nonZero,
    ),
  );
}

FrameElementFacts _rotatedPathFill() {
  return _facts(
    _FactSpec(
      id: 'rotated-path-fill',
      kind: CanvasElementKind.path,
      svgPathData: 'M 0 0 L 10 0 L 10 10 L 0 10 Z',
      fillColor: const Color(0xff000000),
      fillRule: CanvasPathFillRule.nonZero,
      transform: CanvasTransform.rotationDegrees(45),
    ),
  );
}

FrameElementFacts _rect(String id, [_RectSpec spec = const _RectSpec()]) {
  return _facts(
    _FactSpec(
      id: id,
      kind: CanvasElementKind.rect,
      orderToken: spec.orderToken,
      locationKind: spec.locationKind,
      size: spec.size,
      hitPadding: spec.hitPadding,
      isVisible: spec.isVisible,
      isSelectable: spec.isSelectable,
      transform: spec.transform,
    ),
  );
}

FrameElementFacts _rotatedRect() {
  return _rect(
    'rotated',
    _RectSpec(
      size: const Size(10, 10),
      transform: CanvasTransform.rotationDegrees(45),
    ),
  );
}

FrameElementFacts _strokedRect() {
  return _facts(
    const _FactSpec(
      id: 'stroked-rect',
      kind: CanvasElementKind.rect,
      size: Size(20, 20),
      strokeColor: Color(0xff000000),
      strokeWidth: 4,
    ),
  );
}

FrameElementFacts _singularRect() {
  return _rect(
    'corrupted',
    _RectSpec(transform: CanvasTransform(a: 1, b: 0, c: 0, d: 0, tx: 0, ty: 0)),
  );
}

FrameElementFacts _line(String id, _LineSpec spec) {
  return _facts(
    _FactSpec(
      id: id,
      kind: CanvasElementKind.line,
      orderToken: spec.orderToken,
      start: spec.start,
      end: spec.end,
      thickness: spec.thickness,
      transform: spec.transform,
    ),
  );
}

FrameElementFacts _facts(_FactSpec spec) {
  return FrameElementFacts(
    id: CanvasElementId(spec.id),
    kind: spec.kind,
    revision: 0,
    generation: 0,
    orderToken: spec.orderToken,
    locationKind: spec.locationKind,
    transform: spec.transform,
    opacity: 1,
    hitPadding: spec.hitPadding,
    isVisible: spec.isVisible,
    isSelectable: spec.isSelectable,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    size: spec.size,
    start: spec.start,
    end: spec.end,
    thickness: spec.thickness,
    text: spec.text,
    fontSize: spec.fontSize,
    measuredTextLayout: _measuredTextLayout(spec),
    svgPathData: spec.svgPathData,
    fillColor: spec.fillColor,
    strokeColor: spec.strokeColor,
    strokeWidth: spec.strokeWidth,
    fillRule: spec.fillRule,
    points: spec.points,
  );
}

final class _RectSpec {
  const _RectSpec({
    this.orderToken = 0,
    this.size = const Size(10, 10),
    this.hitPadding = 0,
    this.isVisible = true,
    this.isSelectable = true,
    this.locationKind = FrameElementLocationKind.content,
    this.transform = CanvasTransform.identity,
  });

  final int orderToken;
  final Size size;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final FrameElementLocationKind locationKind;
  final CanvasTransform transform;
}

final _nearSingularTranslatedTransform = CanvasTransform(
  a: 1e-4,
  b: 0,
  c: 0,
  d: 1e-4,
  tx: 2000,
  ty: 0,
);

final class _LineSpec {
  const _LineSpec({
    required this.start,
    required this.end,
    required this.thickness,
    this.orderToken = 0,
    this.transform = CanvasTransform.identity,
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final int orderToken;
  final CanvasTransform transform;
}

final class _FactSpec {
  const _FactSpec({
    required this.id,
    required this.kind,
    this.orderToken = 0,
    this.locationKind = FrameElementLocationKind.content,
    this.size,
    this.hitPadding = 0,
    this.isVisible = true,
    this.isSelectable = true,
    this.transform = CanvasTransform.identity,
    this.start,
    this.end,
    this.thickness,
    this.points = const [],
    this.text,
    this.fontSize,
    this.measuredText = false,
    this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth,
    this.fillRule,
  });

  final String id;
  final CanvasElementKind kind;
  final int orderToken;
  final FrameElementLocationKind locationKind;
  final Size? size;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final CanvasTransform transform;
  final Offset? start;
  final Offset? end;
  final double? thickness;
  final List<Offset> points;
  final String? text;
  final double? fontSize;
  final bool measuredText;
  final String? svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double? strokeWidth;
  final CanvasPathFillRule? fillRule;
}

MeasuredTextLayout? _measuredTextLayout(_FactSpec spec) {
  final text = spec.text;
  if (!spec.measuredText || text == null) {
    return null;
  }
  final result = FrameTextLayoutMeasurer().measureTextLayout(
    MeasuredTextLayoutInput(
      text: text,
      fontSize: spec.fontSize ?? 24,
      color: const Color(0xFF000000),
      align: TextAlign.left,
      direction: TextDirection.ltr,
      isBold: false,
      isItalic: false,
      isUnderline: false,
      fontFamily: null,
      maxWidth: null,
      lineHeight: null,
    ),
  );

  return switch (result) {
    MeasuredTextLayoutReady(:final layout) => layout,
    MeasuredTextLayoutFailed() => null,
  };
}

FrameElementHandle _handleFor(FrameElementFacts facts) {
  return FrameElementHandle(
    id: facts.id,
    structuralRevision: 0,
    generation: facts.generation,
    orderToken: facts.orderToken,
  );
}

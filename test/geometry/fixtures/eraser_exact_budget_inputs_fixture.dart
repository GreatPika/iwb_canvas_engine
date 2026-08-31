import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_element.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_metadata.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/hit_test_policy.dart';

void main() {
  _testCorridorEnvelope();
  _testEmptyCorridorEnvelope();
  _testExactEraserInputs();
  _testBudgetInputShapes();
}

void _testCorridorEnvelope() {
  test(
    'corridor envelope includes eraser radius, hit padding, and hit slop',
    () {
      final corridor = const GeometryPolicy().corridorEnvelope(
        points: const [Offset(0, 0), Offset(10, 0)],
        eraserThickness: 6,
        hitPadding: 2,
      );

      expect(corridor.points, const [Offset(0, 0), Offset(10, 0)]);
      expect(corridor.radiusWorld, 9);
      expect(corridor.exactRadiusWorld, 3);
      expect(corridor.envelopeWorld, const Rect.fromLTRB(-9, -9, 19, 9));
    },
  );
}

void _testEmptyCorridorEnvelope() {
  test('empty and non-finite corridors do not create origin envelopes', () {
    const geometry = GeometryPolicy();
    final empty = geometry.corridorEnvelope(
      points: const [],
      eraserThickness: 6,
      hitPadding: 2,
    );
    final nonFinite = geometry.corridorEnvelope(
      points: const [Offset(double.nan, 0), Offset(1, double.infinity)],
      eraserThickness: 6,
      hitPadding: 2,
    );
    final mixed = geometry.corridorEnvelope(
      points: const [Offset(0, 0), Offset(double.nan, 1), Offset(10, 0)],
      eraserThickness: 6,
      hitPadding: 2,
    );

    expect(empty.points, isEmpty);
    expect(empty.envelopeWorld, Rect.zero);
    expect(nonFinite.points, isEmpty);
    expect(nonFinite.envelopeWorld, Rect.zero);
    expect(mixed.points, isEmpty);
    expect(mixed.envelopeWorld, Rect.zero);
  });
}

void _testExactEraserInputs() {
  test('exact eraser input checks are family-owned and bounded', () {
    const hit = HitTestPolicy();
    final corridor = _corridor();

    expect(hit.exactEraserHit(corridor: corridor, facts: _rect()), isTrue);
    expect(
      hit.exactEraserHit(corridor: _parallelCorridor(), facts: _rect()),
      isTrue,
    );
    expect(
      hit.exactEraserHit(corridor: _pointCorridor(), facts: _wideRect()),
      isTrue,
    );
    expect(
      hit.exactEraserHit(
        corridor: _edgeTouchingEnvelopeCorridor(),
        facts: _wideRect(),
      ),
      isFalse,
    );
    expect(hit.exactEraserHit(corridor: corridor, facts: _line()), isTrue);
    expect(hit.exactEraserHit(corridor: corridor, facts: _path()), isTrue);
    expect(
      hit.exactEraserHit(corridor: corridor, facts: _backgroundRect()),
      isFalse,
    );
    expect(
      hit.exactEraserHit(corridor: corridor, facts: _lockedDeleteRect()),
      isFalse,
    );
    expect(
      hit.exactEraserHit(corridor: corridor, facts: _invalidPath()),
      isFalse,
    );
  });
}

void _testBudgetInputShapes() {
  test('terminal exact-check budget input shape is no-partial', () {
    final geometry = const GeometryPolicy();
    final terminal = geometry.eraserTerminalBudgetInputs();

    expect(terminal.candidateLimit, 4096);
    expect(terminal.exactCheckLimit, 32768);
  });
}

EraserCorridor _corridor() {
  return const GeometryPolicy().corridorEnvelope(
    points: const [Offset(-10, 0), Offset(10, 0)],
    eraserThickness: 2,
    hitPadding: 0,
  );
}

EraserCorridor _edgeTouchingEnvelopeCorridor() {
  return const GeometryPolicy().corridorEnvelope(
    points: const [Offset(0, 11)],
    eraserThickness: 4,
    hitPadding: 0,
  );
}

EraserCorridor _pointCorridor() {
  return const GeometryPolicy().corridorEnvelope(
    points: const [Offset(0, 7)],
    eraserThickness: 4,
    hitPadding: 0,
  );
}

EraserCorridor _parallelCorridor() {
  return const GeometryPolicy().corridorEnvelope(
    points: const [Offset(-4, 7), Offset(4, 7)],
    eraserThickness: 4,
    hitPadding: 0,
  );
}

FrameElementFacts _wideRect() {
  return _facts(_FactSpec(CanvasElementKind.rect)..size = const Size(100, 10));
}

FrameElementFacts _rect({
  FrameElementLocationKind locationKind = FrameElementLocationKind.content,
  bool isDeletable = true,
}) {
  return _facts(
    _FactSpec(CanvasElementKind.rect)
      ..size = const Size(10, 10)
      ..locationKind = locationKind
      ..isDeletable = isDeletable,
  );
}

FrameElementFacts _backgroundRect() {
  return _rect(locationKind: FrameElementLocationKind.background);
}

FrameElementFacts _lockedDeleteRect() {
  return _rect(isDeletable: false);
}

FrameElementFacts _line() {
  return _facts(
    _FactSpec(CanvasElementKind.line)
      ..start = const Offset(-5, 0)
      ..end = const Offset(5, 0)
      ..thickness = 1,
  );
}

FrameElementFacts _path() {
  return _facts(
    _FactSpec(CanvasElementKind.path)
      ..svgPathData = 'M 0 0 L 10 0 L 10 10 L 0 10 Z'
      ..fillColor = const Color(0xff000000)
      ..fillRule = CanvasPathFillRule.nonZero,
  );
}

FrameElementFacts _invalidPath() {
  return _facts(
    _FactSpec(CanvasElementKind.path)
      ..svgPathData = 'M'
      ..fillColor = const Color(0xff000000)
      ..fillRule = CanvasPathFillRule.nonZero,
  );
}

FrameElementFacts _facts(_FactSpec spec) {
  return FrameElementFacts(
    id: CanvasElementId(spec.kind.name),
    kind: spec.kind,
    revision: 0,
    generation: 0,
    orderToken: 0,
    locationKind: spec.locationKind,
    transform: CanvasTransform.identity,
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: spec.isDeletable,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    size: spec.size,
    start: spec.start,
    end: spec.end,
    thickness: spec.thickness,
    svgPathData: spec.svgPathData,
    fillColor: spec.fillColor,
    fillRule: spec.fillRule,
  );
}

final class _FactSpec {
  _FactSpec(this.kind);

  final CanvasElementKind kind;
  Size? size;
  Offset? start;
  Offset? end;
  double? thickness;
  String? svgPathData;
  Color? fillColor;
  CanvasPathFillRule? fillRule;
  FrameElementLocationKind locationKind = FrameElementLocationKind.content;
  bool isDeletable = true;
}

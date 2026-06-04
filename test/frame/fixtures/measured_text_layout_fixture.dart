import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/measured_text_layout.dart';
import 'package:iwb_canvas_engine/src/frame/frame_text_layout_measurer.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_entry.dart';

void main() {
  _testTextCacheEntryMetrics();
  _testTextAlignmentAnchors();
  _testBoundedMeasurementFailure();
  _testGeometryAndRenderRecords();
  _testSpatialMemberships();
  _testLiveMultilineMeasurement();
  _testUnmeasuredTextFailure();
  _testMeasurementOwnerBoundary();
}

void _testTextCacheEntryMetrics() {
  test(
    'text cache entry exposes the same measured local bounds as painter',
    () {
      final measurer = FrameTextLayoutMeasurer();
      final input = _input(const _TextInputSpec(text: 'Measured text'));

      final entry = measurer.bindTextLayout(input, debugLabel: 'text-a');
      final bounds = entry.layout.paintBoundsLocal;

      expect(entry.painter.width, closeTo(bounds.width, 0.001));
      expect(entry.painter.height, closeTo(bounds.height, 0.001));
      expect(bounds.center, Offset.zero);
      expect(entry.layout.hitBoundsLocal, bounds);
      expect(entry.layout.selectionBoundsLocal, bounds);
      expect(entry.layout.editBoundsLocal, bounds);
      expect(entry.layout.lines, isNotEmpty);
    },
  );
}

void _testTextAlignmentAnchors() {
  test('text measured bounds stay stable across horizontal alignment', () {
    final measurer = FrameTextLayoutMeasurer();
    final left = _readyLayoutWith(
      measurer,
      _input(const _TextInputSpec(text: 'anchor', align: TextAlign.left)),
    );
    final right = _readyLayoutWith(
      measurer,
      _input(const _TextInputSpec(text: 'anchor', align: TextAlign.right)),
    );
    final center = _readyLayoutWith(
      measurer,
      _input(const _TextInputSpec(text: 'anchor', align: TextAlign.center)),
    );

    expect(right.paintBoundsLocal, left.paintBoundsLocal);
    expect(center.paintBoundsLocal, left.paintBoundsLocal);
  });
}

void _testBoundedMeasurementFailure() {
  test(
    'invalid text measurement input returns an explicit bounded failure',
    () {
      final result = FrameTextLayoutMeasurer().measureTextLayout(
        const MeasuredTextLayoutInput(
          text: 'invalid',
          fontSize: double.nan,
          color: Color(0xFF111111),
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

      expect(result, isA<MeasuredTextLayoutFailed>());
    },
  );
}

void _testGeometryAndRenderRecords() {
  test('geometry and render records consume measured text bounds', () {
    final measured = _readyLayout(const _TextInputSpec(text: 'Measured text'));
    final layout = _layoutWithHitBounds(
      measured,
      measured.paintBoundsLocal.inflate(2),
    );
    final facts = _textFacts(
      layout: layout,
      overrides: _TextFactsOverrides(
        transform: CanvasTransform.translation(const Offset(10, 20)),
        hitPadding: 3,
      ),
    );
    final bounds = const GeometryPolicy().boundsFor(facts);
    final record = RenderElementRecord.fromFacts(facts);

    _expectMeasuredLocalBounds(bounds, layout);
    _expectMeasuredWorldBounds(bounds, layout, facts.transform);
    expect(record.paintBoundsWorld, bounds.paintBoundsWorld);
    expect(record.hitBoundsWorld, bounds.hitBoundsWorld);
  });
}

void _expectMeasuredLocalBounds(
  GeometryBounds bounds,
  MeasuredTextLayout layout,
) {
  expect(bounds.localBounds, layout.paintBoundsLocal);
  expect(bounds.hitBoundsLocal, layout.hitBoundsLocal);
  expect(bounds.selectionBoundsLocal, layout.selectionBoundsLocal);
  expect(bounds.editBoundsLocal, layout.editBoundsLocal);
}

void _expectMeasuredWorldBounds(
  GeometryBounds bounds,
  MeasuredTextLayout layout,
  CanvasTransform transform,
) {
  expect(bounds.paintBoundsWorld, transform.applyToRect(bounds.localBounds));
  expect(bounds.selectionBoundsWorld, bounds.paintBoundsWorld);
  expect(bounds.editBoundsWorld, bounds.paintBoundsWorld);
  expect(
    bounds.hitBoundsWorld,
    transform.applyToRect(layout.hitBoundsLocal).inflate(7),
  );
}

void _testSpatialMemberships() {
  test('spatial paint hit and context memberships share measured geometry', () {
    final measured = _readyLayout(
      const _TextInputSpec(text: 'Spatial text', fontSize: 16),
    );
    final layout = _layoutWithHitBounds(
      measured,
      measured.paintBoundsLocal.inflate(1),
    );
    final facts = _textFacts(
      layout: layout,
      overrides: const _TextFactsOverrides(hitPadding: 2),
    );
    final frame = _SingleElementFrameFacts(facts);
    final entry = spatialEntryFor(
      frame: frame,
      handle: _handleFor(facts),
      geometryPolicy: const GeometryPolicy(),
    );
    final bounds = const GeometryPolicy().boundsFor(facts);

    expect(entry, isNotNull);
    if (entry == null) {
      fail('Expected measured text spatial entry.');
    }
    expect(entry.paintMembership.boundsWorld, bounds.paintBoundsWorld);
    expect(entry.hitMembership.boundsWorld, bounds.hitBoundsWorld);
    expect(entry.contextMembership.boundsWorld, bounds.hitBoundsWorld);
  });
}

void _testLiveMultilineMeasurement() {
  test('multiline and style-sensitive live measurements use the same port', () {
    final measurer = FrameTextLayoutMeasurer();
    final single = _readyLayoutWith(
      measurer,
      _input(const _TextInputSpec(text: 'one line', fontSize: 14)),
    );
    final multilineInput = _input(
      const _TextInputSpec(
        text: 'one line\nsecond line',
        fontSize: 14,
        maxWidth: 80,
        lineHeight: 1.4,
        align: TextAlign.center,
        direction: TextDirection.rtl,
      ),
    );
    final multiline = _readyLayoutWith(measurer, multilineInput);
    final key = textLayoutCacheKeyFor(multilineInput);

    expect(
      multiline.editBoundsLocal.height,
      greaterThan(single.editBoundsLocal.height),
    );
    expect(multiline.lines.length, greaterThanOrEqualTo(2));
    expect(key.alignName, TextAlign.center.name);
    expect(key.directionName, TextDirection.rtl.name);
    expect(measurer.cache.probe.entries, 2);
  });
}

void _testUnmeasuredTextFailure() {
  test('unmeasured text has no formula fallback', () {
    final facts = _textFacts(
      layout: null,
      overrides: const _TextFactsOverrides(text: 'wide text', fontSize: 40),
    );
    final bounds = const GeometryPolicy().boundsFor(facts);

    expect(bounds.localBounds, Rect.zero);
    expect(bounds.paintBoundsWorld, Rect.zero);
    expect(bounds.hitBoundsWorld, Rect.zero);
    expect(bounds.selectionBoundsWorld, Rect.zero);
    expect(bounds.editBoundsWorld, Rect.zero);
  });
}

void _testMeasurementOwnerBoundary() {
  test('text measurement implementation stays out of geometry and runtime', () {
    final forbiddenOwners = [
      Directory('lib/src/geometry'),
      Directory('lib/src/runtime'),
    ];
    for (final owner in forbiddenOwners) {
      for (final file in owner.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) {
          continue;
        }
        final content = file.readAsStringSync();
        expect(content, isNot(contains('TextPainter')));
        expect(content, isNot(contains('text.length * fontSize')));
      }
    }
  });
}

MeasuredTextLayoutInput _input(_TextInputSpec spec) {
  return MeasuredTextLayoutInput(
    text: spec.text,
    fontSize: spec.fontSize,
    color: const Color(0xFF111111),
    align: spec.align,
    direction: spec.direction,
    isBold: false,
    isItalic: false,
    isUnderline: false,
    fontFamily: null,
    maxWidth: spec.maxWidth,
    lineHeight: spec.lineHeight,
  );
}

MeasuredTextLayout _readyLayout(_TextInputSpec spec) {
  return _readyLayoutWith(FrameTextLayoutMeasurer(), _input(spec));
}

MeasuredTextLayout _readyLayoutWith(
  FrameTextLayoutMeasurer measurer,
  MeasuredTextLayoutInput input,
) {
  final result = measurer.measureTextLayout(input);

  return switch (result) {
    MeasuredTextLayoutReady(:final layout) => layout,
    MeasuredTextLayoutFailed(:final reason) => throw StateError(reason),
  };
}

MeasuredTextLayout _layoutWithHitBounds(
  MeasuredTextLayout source,
  Rect hitBoundsLocal,
) {
  return MeasuredTextLayout(
    paintBoundsLocal: source.paintBoundsLocal,
    hitBoundsLocal: hitBoundsLocal,
    selectionBoundsLocal: source.selectionBoundsLocal,
    editBoundsLocal: source.editBoundsLocal,
    lines: source.lines,
  );
}

FrameElementFacts _textFacts({
  required MeasuredTextLayout? layout,
  _TextFactsOverrides overrides = const _TextFactsOverrides(),
}) {
  return FrameElementFacts(
    id: CanvasElementId('text-a'),
    kind: CanvasElementKind.text,
    revision: 1,
    generation: 1,
    orderToken: 1,
    locationKind: FrameElementLocationKind.content,
    transform: overrides.transform,
    opacity: 1,
    hitPadding: overrides.hitPadding,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    text: overrides.text,
    fontSize: overrides.fontSize,
    textColor: const Color(0xFF111111),
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
    measuredTextLayout: layout,
  );
}

final class _TextInputSpec {
  const _TextInputSpec({
    required this.text,
    this.fontSize = 18,
    this.maxWidth,
    this.lineHeight,
    this.align = TextAlign.left,
    this.direction = TextDirection.ltr,
  });

  final String text;
  final double fontSize;
  final double? maxWidth;
  final double? lineHeight;
  final TextAlign align;
  final TextDirection direction;
}

final class _TextFactsOverrides {
  const _TextFactsOverrides({
    this.text = 'text',
    this.fontSize = 18,
    this.transform = CanvasTransform.identity,
    this.hitPadding = 0,
  });

  final String text;
  final double fontSize;
  final CanvasTransform transform;
  final double hitPadding;
}

FrameElementHandle _handleFor(FrameElementFacts facts) {
  return FrameElementHandle(
    id: facts.id,
    structuralRevision: 1,
    generation: facts.generation,
    orderToken: facts.orderToken,
  );
}

final class _SingleElementFrameFacts implements FrameFactsPort {
  const _SingleElementFrameFacts(this.facts);

  final FrameElementFacts facts;

  @override
  FrameRevisionFacts get frameRevisions {
    return const FrameRevisionFacts(
      documentRevision: 1,
      structuralRevision: 1,
      boundsRevision: 1,
      elementVisualRevision: 1,
      backgroundRevision: 1,
      gridRevision: 1,
      resourceRevision: 1,
    );
  }

  @override
  CanvasBackground get background => const CanvasBackground();

  @override
  int elementCount(int structuralRevision) => structuralRevision == 1 ? 1 : 0;

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    return structuralRevision == 1 ? [_handleFor(facts)] : const [];
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    return structuralRevision == 1 && id == facts.id ? _handleFor(facts) : null;
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    return handle.id == facts.id &&
            handle.generation == facts.generation &&
            handle.orderToken == facts.orderToken
        ? facts
        : null;
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) => null;
}

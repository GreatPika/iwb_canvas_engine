import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/measured_text_layout.dart';
import 'package:iwb_canvas_engine/src/frame/frame_text_layout_measurer.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_record_painter.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_entry.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../support/accept_commit.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  _testTextCacheEntryMetrics();
  _testLoadedFontStyleMetrics();
  _testRuntimeDefaultFontReachesMeasuredAndPaintedFrame();
  _testTextAlignmentAnchors();
  _testBoundedMeasurementFailure();
  _testGeometryAndRenderRecords();
  _testSpatialMemberships();
  _testLiveMultilineMeasurement();
  _testUnmeasuredTextFailure();
  _testMeasurementOwnerBoundary();
}

// This crosses the Store-to-frame projection, measured cache and record painter
// so a surface-only fallback or a suppressed empty paint cannot appear correct.
// ignore: halstead-volume, source-lines-of-code
void _testRuntimeDefaultFontReachesMeasuredAndPaintedFrame() {
  testWidgets(
    'runtime default family matches stored family through geometry, cache, and pixels',
    (tester) async {
      await tester.runAsync(_loadRobotoForStyleMetrics);
      final inherited = _runtimeWithFontFamily(
        storedFontFamily: null,
        defaultFontFamily: _unit3RobotoFamily,
      );
      final explicit = _runtimeWithFontFamily(
        storedFontFamily: _unit3RobotoFamily,
        defaultFontFamily: null,
      );
      final fallback = _runtimeWithFontFamily(
        storedFontFamily: null,
        defaultFontFamily: null,
      );
      try {
        final inheritedFacts = _runtimeTextFacts(inherited);
        final explicitFacts = _runtimeTextFacts(explicit);
        final fallbackFacts = _runtimeTextFacts(fallback);
        final inheritedRow = _runtimeTextRow(inherited);
        final explicitRow = _runtimeTextRow(explicit);
        final fallbackRow = _runtimeTextRow(fallback);

        expect(inheritedFacts.fontFamily, _unit3RobotoFamily);
        expect(explicitFacts.fontFamily, _unit3RobotoFamily);
        expect(fallbackFacts.fontFamily, isNull);
        final inheritedLayout = inheritedFacts.measuredTextLayout;
        final explicitLayout = explicitFacts.measuredTextLayout;
        expect(inheritedLayout, isNotNull);
        expect(explicitLayout, isNotNull);
        expect(
          inheritedLayout?.paintBoundsLocal,
          explicitLayout?.paintBoundsLocal,
        );
        expect(inheritedRow.layoutInput.fontFamily, _unit3RobotoFamily);
        expect(inheritedRow.layoutCacheKey.fontFamily, _unit3RobotoFamily);
        expect(inheritedRow.layoutCacheKey, explicitRow.layoutCacheKey);
        expect(fallbackRow.layoutCacheKey.fontFamily, isNull);

        final pixels = await tester.runAsync(
          () async => (
            inherited: await _paintRuntimeTextPixels(inherited),
            explicit: await _paintRuntimeTextPixels(explicit),
            fallback: await _paintRuntimeTextPixels(fallback),
          ),
        );
        if (pixels == null) {
          throw StateError('Text paint did not complete.');
        }
        final inheritedPixels = pixels.inherited;
        final explicitPixels = pixels.explicit;
        final fallbackPixels = pixels.fallback;
        expect(_nonTransparentPixels(inheritedPixels), greaterThan(0));
        expect(inheritedPixels, orderedEquals(explicitPixels));
        expect(fallbackPixels, isNot(orderedEquals(inheritedPixels)));
      } finally {
        inherited.dispose();
        explicit.dispose();
        fallback.dispose();
      }
    },
  );
}

RuntimeRoot _runtimeWithFontFamily({
  required String? storedFontFamily,
  required String? defaultFontFamily,
}) {
  return runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('font-layer'),
          elements: [
            CanvasTextElement(
              id: CanvasElementId('font-text'),
              text: 'WMWMWM',
              fontSize: 48,
              color: const Color(0xFF111111),
              textDirection: TextDirection.ltr,
              fontFamily: storedFontFamily,
              transform: CanvasTransform.translation(const Offset(100, 60)),
            ),
          ],
        ),
      ],
    ),
    config: CanvasRuntimeConfig(
      commitResolver: acceptCommit,
      defaultFontFamily: defaultFontFamily,
    ),
  );
}

FrameElementFacts _runtimeTextFacts(RuntimeRoot root) {
  final frame = root.frameFactsPort;
  final handle = frame
      .elementHandles(frame.frameRevisions.structuralRevision)
      .single;
  final facts = frame.resolveElement(handle);
  if (facts == null) {
    throw StateError('Expected current runtime text frame facts.');
  }

  return facts;
}

TextRenderRow _runtimeTextRow(RuntimeRoot root) {
  final output = _runtimeTextFrame(root);
  final record = output.ordinaryPlan.ordinaryRecords.single;
  final row = record.row;
  if (row is! TextRenderRow) {
    throw StateError('Expected a text render row.');
  }

  return row;
}

Future<Uint8List> _paintRuntimeTextPixels(RuntimeRoot root) async {
  final output = _runtimeTextFrame(root);
  final record = output.ordinaryPlan.ordinaryRecords.single;
  final recorder = ui.PictureRecorder();
  paintMainFrameRecord(
    ui.Canvas(recorder),
    record,
    output.assetBindings.assets,
    output.renderPrimitiveSnapshot,
  );
  final image = await recorder.endRecording().toImage(200, 120);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) {
    throw StateError('Text paint did not produce pixel data.');
  }

  return Uint8List.fromList(data.buffer.asUint8List());
}

int _nonTransparentPixels(Uint8List pixels) {
  return [
    for (var offset = 3; offset < pixels.length; offset += 4) pixels[offset],
  ].where((alpha) => alpha > 0).length;
}

MainFramePaintOutput _runtimeTextFrame(RuntimeRoot root) {
  return root.buildResourceFreeMainFrame(
    viewportWorldBounds: const Rect.fromLTWH(0, 0, 200, 120),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
  );
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

void _testLoadedFontStyleMetrics() {
  testWidgets('frame measures distinct bold and italic metrics from Roboto', (
    tester,
  ) async {
    await tester.runAsync(_loadRobotoForStyleMetrics);
    final measurer = FrameTextLayoutMeasurer();
    final normal = _readyLayoutWith(
      measurer,
      _input(
        const _TextInputSpec(text: 'WMWMWM', fontFamily: _unit3RobotoFamily),
      ),
    );
    final bold = _readyLayoutWith(
      measurer,
      _input(
        const _TextInputSpec(
          text: 'WMWMWM',
          fontFamily: _unit3RobotoFamily,
          isBold: true,
        ),
      ),
    );
    final italic = _readyLayoutWith(
      measurer,
      _input(
        const _TextInputSpec(
          text: 'WMWMWM',
          fontFamily: _unit3RobotoFamily,
          isItalic: true,
        ),
      ),
    );

    expect(bold.paintBoundsLocal.width, isNot(normal.paintBoundsLocal.width));
    expect(italic.paintBoundsLocal.width, isNot(normal.paintBoundsLocal.width));
  });
}

const _unit3RobotoFamily = 'Unit3Roboto';

Future<void> _loadRobotoForStyleMetrics() async {
  final fontDirectory = _materialFontDirectoryForTestRuntime();
  final fontFiles = [
    File('${fontDirectory.path}/Roboto-Regular.ttf'),
    File('${fontDirectory.path}/Roboto-Bold.ttf'),
    File('${fontDirectory.path}/Roboto-Italic.ttf'),
  ];
  for (final fontFile in fontFiles) {
    expect(fontFile.existsSync(), isTrue, reason: fontFile.path);
  }
  final loader = FontLoader(_unit3RobotoFamily);
  for (final fontFile in fontFiles) {
    loader.addFont(fontFile.readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Directory _materialFontDirectoryForTestRuntime() {
  var candidate = File(Platform.resolvedExecutable).parent;
  while (candidate.parent.path != candidate.path) {
    final fontDirectory = Directory.fromUri(
      candidate.uri.resolve('bin/cache/artifacts/material_fonts/'),
    );
    if (fontDirectory.existsSync()) {
      return fontDirectory;
    }
    candidate = candidate.parent;
  }
  fail('Flutter SDK material fonts were not found from the test executable.');
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
    isBold: spec.isBold,
    isItalic: spec.isItalic,
    isUnderline: false,
    fontFamily: spec.fontFamily,
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
    this.isBold = false,
    this.isItalic = false,
    this.fontFamily,
  });

  final String text;
  final double fontSize;
  final double? maxWidth;
  final double? lineHeight;
  final TextAlign align;
  final TextDirection direction;
  final bool isBold;
  final bool isItalic;
  final String? fontFamily;
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

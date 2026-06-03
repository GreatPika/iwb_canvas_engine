import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';

void main() {
  _registerPainterBoundaryTests();
  _registerOverlayPainterBoundaryTests();
  _registerPaintOrderTests();
}

void _registerPainterBoundaryTests() {
  test('surface painters import only immutable frame paint outputs', () {
    expect(File('lib/src/surface/main_painter.dart').existsSync(), isTrue);
    _expectPainterBoundary('lib/src/surface/main_painter.dart');
    _expectPainterBoundary('lib/src/surface/overlay_painter.dart');
  });
}

void _registerOverlayPainterBoundaryTests() {
  test('overlay painter consumes primitive paint data', () {
    final overlayPainterSource = File(
      'lib/src/surface/overlay_painter.dart',
    ).readAsStringSync();
    expect(
      overlayPainterSource,
      contains('case final PendingLineStartOverlayPrimitive primitive'),
    );
    expect(overlayPainterSource, contains('Paint()..color = primitive.color'));
    expect(overlayPainterSource, isNot(contains('BlendMode.clear')));
    expect(overlayPainterSource, contains('_paintEraserOverlay'));
  });

  test('main painter consumes derived frame plans', () {
    final mainPainterSource = File(
      'lib/src/surface/main_painter.dart',
    ).readAsStringSync();

    expect(mainPainterSource, contains('staticBackgroundPlan'));
    expect(mainPainterSource, contains('drawPicture'));
    expect(mainPainterSource, isNot(contains('StaticBackgroundPrimitive')));
    expect(mainPainterSource, contains('selectionDecorationPlan'));
    expect(
      mainPainterSource,
      contains('paintMainFrameRecordsAndSelectionDecorations(canvas, output)'),
    );
    expect(
      mainPainterSource,
      isNot(contains('void _paintSelectionDecorations(')),
    );
    expect(mainPainterSource, isNot(contains('.sort(')));
    expect(mainPainterSource, isNot(contains('saveLayer')));
    expect(mainPainterSource, isNot(contains('ordinaryPaintRecordCache')));
  });
}

void _registerPaintOrderTests() {
  test('main painter consumes records bottom-to-top', () {
    final bottom = RenderElementRecord.fromFacts(
      rectFacts('bottom', orderToken: 1),
    );
    final top = RenderElementRecord.fromFacts(rectFacts('top', orderToken: 2));

    expect(
      mainFrameRecordsInPaintOrder([top, bottom]).map((record) => record.id),
      [bottom.id, top.id],
    );
    expect(
      mainFrameRecordsInPaintOrder([bottom, top]).map((record) => record.id),
      [bottom.id, top.id],
    );
  });
}

void _expectPainterBoundary(String path) {
  final source = File(path).readAsStringSync();

  expect(source, contains('FramePaintOutput'));
  _expectNoLivePaintInputs(source);
}

void _expectNoLivePaintInputs(String source) {
  for (final forbidden in [
    'RuntimeRoot',
    'DocumentStoreKernel',
    'CanvasRuntime',
    'SurfaceResourceSession',
    'CanvasResourceResolver',
    'readDocument',
    'resolveImage',
  ]) {
    expect(source, isNot(contains(forbidden)));
  }
}

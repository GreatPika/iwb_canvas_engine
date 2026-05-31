import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_painter.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  _registerPainterBoundaryTests();
  _registerPaintOrderTests();
}

void _registerPainterBoundaryTests() {
  test('painters import only immutable frame paint outputs', () {
    expect(File('lib/src/frame/main_frame_painter.dart').existsSync(), isTrue);
    _expectPainterBoundary('lib/src/frame/main_frame_painter.dart');
    _expectRecordPainterBoundary(
      'lib/src/frame/main_frame_record_painter.dart',
    );
    _expectPainterBoundary('lib/src/frame/overlay_frame_painter.dart');
    final recordPainterSource = File(
      'lib/src/frame/main_frame_record_painter.dart',
    ).readAsStringSync();
    expect(
      recordPainterSource,
      contains('record.transform.toCanvasTransform()'),
    );
    expect(recordPainterSource, contains('_paintPathRecord'));
    expect(recordPainterSource, contains('_paintTextRecord'));
    expect(recordPainterSource, contains('_paintStrokeRecord'));
    expect(recordPainterSource, contains('_paintLineRecord'));
    expect(recordPainterSource, contains('_withElementOpacity'));
    expect(recordPainterSource, contains('ColorFilter.mode'));
    expect(recordPainterSource, isNot(contains('PathRenderRow() ||')));
  });

  test('main painter consumes derived frame plans', () {
    final mainPainterSource = File(
      'lib/src/frame/main_frame_painter.dart',
    ).readAsStringSync();

    expect(mainPainterSource, contains('staticBackgroundPlan'));
    expect(mainPainterSource, contains('selectionDecorationPlan'));
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

void _expectRecordPainterBoundary(String path) {
  final source = File(path).readAsStringSync();

  expect(source, contains('RenderElementRecord'));
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

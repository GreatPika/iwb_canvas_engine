import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_painter.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('painters import only immutable frame paint outputs', () {
    expect(File('lib/src/frame/main_frame_painter.dart').existsSync(), isTrue);
    _expectPainterBoundary('lib/src/frame/main_frame_painter.dart');
    _expectPainterBoundary('lib/src/frame/overlay_frame_painter.dart');
  });

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

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('frame record painter consumes row-specific paint data', () {
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
    expect(recordPainterSource, contains('RenderPrimitiveCacheSnapshot'));
    expect(recordPainterSource, isNot(contains('parseSvgPathData')));
    expect(recordPainterSource, isNot(contains('TextPainter(')));
    expect(recordPainterSource, isNot(contains('PathRenderRow() ||')));
    _expectNoLivePaintInputs(recordPainterSource);
  });
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

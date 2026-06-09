import 'dart:io';
import 'dart:ui';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_cache.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_record_painter.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/frame/render_primitive_cache_snapshot.dart';
import 'package:test/test.dart';

void main() {
  _testRecordPainterConsumesRowData();
  _testFallbackStrokeBoundsTransformedOnce();
}

void _testRecordPainterConsumesRowData() {
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
    expect(recordPainterSource, contains('record.paintBoundsLocal'));
    _expectNoLivePaintInputs(recordPainterSource);
  });
}

void _testFallbackStrokeBoundsTransformedOnce() {
  test('fallback stroke bounds are transformed once', () async {
    final image = await _paintRecord(_fallbackStrokeRecord());

    expect(await _alphaAt(image, 12, 5), greaterThan(0));
    expect(await _alphaAt(image, 22, 5), 0);
  });
}

RenderElementRecord _fallbackStrokeRecord() {
  return RenderElementRecord(
    id: CanvasElementId('stroke-a'),
    family: RenderElementFamily.stroke,
    generation: 0,
    orderToken: 0,
    transform: CanvasTransform.translation(const Offset(10, 0)),
    opacity: 1,
    primitiveAlpha: 255,
    paintBoundsLocal: const Rect.fromLTWH(0, 0, 10, 10),
    paintBoundsWorld: const Rect.fromLTWH(10, 0, 10, 10),
    hitBoundsWorld: const Rect.fromLTWH(10, 0, 10, 10),
    resourceId: null,
    row: const StrokeRenderRow(
      pointsKey: '',
      strokeCacheKey: StrokePathCacheKey(
        pointsKey: '',
        thickness: 1,
        transformScaleKey: '1,0,0,1',
      ),
      points: [Offset.zero, Offset(1, 1)],
      thickness: 1,
      color: Color(0xFF000000),
    ),
  );
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

Future<Image> _paintRecord(RenderElementRecord record) {
  final recorder = PictureRecorder();
  paintMainFrameRecord(
    Canvas(recorder),
    record,
    const {},
    RenderPrimitiveCacheSnapshot.empty,
  );

  return recorder.endRecording().toImage(40, 20);
}

Future<int> _alphaAt(Image image, int x, int y) async {
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('frame record painter test produced no pixel data');
  }

  return bytes.buffer.asUint8List()[(y * image.width + x) * 4 + 3];
}

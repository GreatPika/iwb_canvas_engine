import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/frame/frame_cache.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_record_painter.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/frame/render_primitive_cache_snapshot.dart';

void main() {
  test(
    'main one-point stroke and same-point line produce visible pixels',
    () async {
      expect(await _mainRecordAlphaAt(_onePointStroke(), 8, 8), greaterThan(0));
      expect(await _mainRecordAlphaAt(_samePointLine(), 8, 8), greaterThan(0));
    },
  );

  test('main empty point lists are no-op', () async {
    expect(await _mainRecordAlphaAt(_emptyStroke(), 8, 8), 0);
  });
}

RenderElementRecord _onePointStroke() {
  return _record(
    const StrokeRenderRow(
      pointsKey: 'one-point',
      strokeCacheKey: StrokePathCacheKey(
        pointsKey: 'one-point',
        thickness: 6,
        transformScaleKey: '1',
      ),
      points: [Offset(8, 8)],
      thickness: 6,
      color: Color(0xFFFF0000),
    ),
  );
}

RenderElementRecord _samePointLine() {
  return _record(
    const LineRenderRow(
      start: Offset(8, 8),
      end: Offset(8, 8),
      thickness: 6,
      color: Color(0xFF0000FF),
    ),
  );
}

RenderElementRecord _emptyStroke() {
  return _record(
    const StrokeRenderRow(
      pointsKey: 'empty',
      strokeCacheKey: StrokePathCacheKey(
        pointsKey: 'empty',
        thickness: 6,
        transformScaleKey: '1',
      ),
      points: [],
      thickness: 6,
      color: Color(0xFFFF0000),
    ),
  );
}

Future<int> _mainRecordAlphaAt(RenderElementRecord record, int x, int y) {
  return _alphaAt(
    (canvas) => paintMainFrameRecord(
      canvas,
      record,
      const {},
      RenderPrimitiveCacheSnapshot.empty,
    ),
    x,
    y,
  );
}

Future<int> _alphaAt(void Function(Canvas canvas) paint, int x, int y) async {
  final recorder = PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(32, 32);
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('main drawable policy test produced no pixel data');
  }

  return bytes.buffer.asUint8List()[(y * 32 + x) * 4 + 3];
}

RenderElementRecord _record(RenderElementRow row) {
  return RenderElementRecord(
    id: CanvasElementId('record'),
    family: switch (row) {
      StrokeRenderRow() => RenderElementFamily.stroke,
      LineRenderRow() => RenderElementFamily.line,
      _ => throw StateError('unsupported drawable test row'),
    },
    generation: 1,
    orderToken: 1,
    transform: CanvasTransform.identity,
    opacity: 1,
    primitiveAlpha: 255,
    paintBoundsWorld: const Rect.fromLTWH(0, 0, 32, 32),
    hitBoundsWorld: const Rect.fromLTWH(0, 0, 32, 32),
    resourceId: null,
    row: row,
  );
}

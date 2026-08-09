import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/frame/frame_cache.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_record_painter.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/frame/render_primitive_cache_snapshot.dart';

void main() {
  _registerMainDegenerateDrawableTests();
  _registerMainRoundStrokeTests();
}

void _registerMainDegenerateDrawableTests() {
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

void _registerMainRoundStrokeTests() {
  test('main committed lines paint round caps', () async {
    final record = _horizontalLine();

    expect(await _mainRecordAlphaAt(record, 4, 16), greaterThan(0));
    expect(await _mainRecordAlphaAt(record, 2, 16), 0);
  });

  test('main committed stroke paths paint round joins', () async {
    final record = _turnStroke();
    final primitives = _turnStrokePrimitives(record.row as StrokeRenderRow);

    expect(
      await _mainRecordAlphaAt(record, 16, 5, renderPrimitives: primitives),
      greaterThan(0),
    );
    expect(
      await _mainRecordAlphaAt(record, 16, 1, renderPrimitives: primitives),
      0,
    );
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

RenderElementRecord _horizontalLine() {
  return _record(
    const LineRenderRow(
      start: Offset(8, 16),
      end: Offset(24, 16),
      thickness: 10,
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

RenderElementRecord _turnStroke() {
  return _record(
    const StrokeRenderRow(
      pointsKey: 'turn',
      strokeCacheKey: StrokePathCacheKey(
        pointsKey: 'turn',
        thickness: 10,
        transformScaleKey: '1',
      ),
      points: [Offset(8, 24), Offset(16, 8), Offset(24, 24)],
      thickness: 10,
      color: Color(0xFF00FF00),
    ),
  );
}

RenderPrimitiveCacheSnapshot _turnStrokePrimitives(StrokeRenderRow row) {
  return RenderPrimitiveCacheSnapshot(
    textLayouts: const {},
    paths: const {},
    strokes: {
      row.strokeCacheKey: StrokePathCacheEntry(
        debugLabel: row.pointsKey,
        path: Path()
          ..moveTo(8, 24)
          ..lineTo(16, 8)
          ..lineTo(24, 24),
      ),
    },
  );
}

Future<int> _mainRecordAlphaAt(
  RenderElementRecord record,
  int x,
  int y, {
  RenderPrimitiveCacheSnapshot? renderPrimitives,
}) {
  return _alphaAt(
    (canvas) => paintMainFrameRecord(
      canvas,
      record,
      const {},
      renderPrimitives ?? RenderPrimitiveCacheSnapshot.empty,
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
    generation: 1,
    orderToken: 1,
    transform: CanvasTransform.identity,
    opacity: 1,
    primitiveAlpha: 255,
    paintBoundsLocal: const Rect.fromLTWH(0, 0, 32, 32),
    paintBoundsWorld: const Rect.fromLTWH(0, 0, 32, 32),
    hitBoundsWorld: const Rect.fromLTWH(0, 0, 32, 32),
    resourceId: null,
    row: row,
  );
}

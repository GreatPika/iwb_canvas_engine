import 'dart:ui';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_cache.dart';
import 'package:iwb_canvas_engine/src/frame/main_frame_record_painter.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/frame/render_primitive_cache_snapshot.dart';
import 'package:iwb_canvas_engine/src/frame/paint_asset_binding_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../preparation/fixtures/vector_preparation_fixture.dart';

void main() {
  _testFallbackStrokeBoundsTransformedOnce();
  _testVectorRecordDrawsPreparedPictureDirectly();
  _testVectorRecordUsesBoundedPictureCommands();
  _testVectorPartialOpacityUsesRecordLocalEffect();
  _testZeroOpacityVectorPaintsNothing();
  _testFullOpacityVectorUsesNoLayer();
  _testVectorOpacityLayersRemainPerRecord();
  _testVectorPictureScalesAcrossTargetSizes();
}

// Two target sizes must share one Picture and recording canvas so the pixels
// prove anisotropic scaling rather than two unrelated drawable outcomes.
// ignore: halstead-volume
void _testVectorPictureScalesAcrossTargetSizes() {
  test('prepared Picture remains drawable at distinct target sizes', () async {
    final prepared = await prepareVector(basicVectorBytes());
    final firstId = CanvasResourceId('vector-first');
    final secondId = CanvasResourceId('vector-second');
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    paintMainFrameRecord(
      canvas,
      _vectorPaintRecord(
        resourceId: firstId,
        size: const Size(20, 10),
        translation: const Offset(10, 5),
      ),
      {firstId: FrameVectorAssetBinding(prepared)},
      RenderPrimitiveCacheSnapshot.empty,
    );
    paintMainFrameRecord(
      canvas,
      _vectorPaintRecord(
        resourceId: secondId,
        size: const Size(8, 16),
        translation: const Offset(32, 8),
      ),
      {secondId: FrameVectorAssetBinding(prepared)},
      RenderPrimitiveCacheSnapshot.empty,
    );
    final image = await recorder.endRecording().toImage(48, 24);

    expect(await _alphaAt(image, 10, 5), greaterThan(0));
    expect(await _alphaAt(image, 2, 2), greaterThan(0));
    expect(await _alphaAt(image, 18, 8), greaterThan(0));
    expect(await _alphaAt(image, 32, 8), greaterThan(0));
    expect(await _alphaAt(image, 29, 1), greaterThan(0));
    expect(await _alphaAt(image, 35, 15), greaterThan(0));
    expect(await _alphaAt(image, 24, 8), 0);
    image.dispose();
    prepared.dispose();
  });
}

RenderElementRecord _vectorPaintRecord({
  required CanvasResourceId resourceId,
  required Size size,
  required Offset translation,
  double opacity = 1,
}) {
  final bounds = Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );
  return RenderElementRecord(
    id: CanvasElementId(resourceId.value),
    generation: 0,
    orderToken: 0,
    transform: CanvasTransform.translation(translation),
    opacity: opacity,
    primitiveAlpha: (opacity * 255).round(),
    paintBoundsLocal: bounds,
    paintBoundsWorld: bounds.shift(translation),
    hitBoundsWorld: bounds.shift(translation),
    resourceId: resourceId,
    row: VectorRenderRow(resourceId: resourceId, size: size, naturalSize: null),
  );
}

// One recording-canvas witness must keep clip, transform, direct Picture,
// and image-conversion exclusions adjacent, or it would hide their ordering.
// ignore: halstead-volume
void _testVectorRecordUsesBoundedPictureCommands() {
  test('vector painter records only bounded Picture commands', () async {
    final prepared = await prepareVector(basicVectorBytes());
    final resourceId = CanvasResourceId('vector-commands');
    final canvas = TestRecordingCanvas();
    paintMainFrameRecord(
      canvas,
      _vectorPaintRecord(
        resourceId: resourceId,
        size: const Size(20, 10),
        translation: const Offset(10, 5),
      ),
      {resourceId: FrameVectorAssetBinding(prepared)},
      RenderPrimitiveCacheSnapshot.empty,
    );

    expect(_recordedArguments(canvas, #clipRect).single, [
      const Rect.fromLTRB(-10, -5, 10, 5),
    ]);
    expect(_recordedArguments(canvas, #translate).single, [-10.0, -5.0]);
    expect(_recordedArguments(canvas, #scale).single, [2.0, 0.5]);
    expect(_recordedArguments(canvas, #drawPicture), hasLength(1));
    expect(_recordedArguments(canvas, #drawImage), isEmpty);
    expect(_recordedArguments(canvas, #drawImageRect), isEmpty);
    prepared.dispose();
  });
}

// The record, bound prepared value, and resulting pixels form one direct-paint
// witness; splitting them would obscure the required draw boundary.
// ignore: halstead-volume
void _testVectorRecordDrawsPreparedPictureDirectly() {
  test(
    'vector painter draws the prepared Picture into its target bounds',
    () async {
      final prepared = await prepareVector(basicVectorBytes());
      final resourceId = CanvasResourceId('vector-a');
      final record = RenderElementRecord(
        id: CanvasElementId('vector-a'),
        generation: 0,
        orderToken: 0,
        transform: CanvasTransform.translation(const Offset(10, 5)),
        opacity: 1,
        primitiveAlpha: 255,
        paintBoundsLocal: const Rect.fromLTRB(-10, -5, 10, 5),
        paintBoundsWorld: const Rect.fromLTRB(0, 0, 20, 10),
        hitBoundsWorld: const Rect.fromLTRB(0, 0, 20, 10),
        resourceId: resourceId,
        row: VectorRenderRow(
          resourceId: resourceId,
          size: const Size(20, 10),
          naturalSize: null,
        ),
      );
      final recorder = PictureRecorder();
      paintMainFrameRecord(Canvas(recorder), record, {
        resourceId: FrameVectorAssetBinding(prepared),
      }, RenderPrimitiveCacheSnapshot.empty);
      final image = await recorder.endRecording().toImage(40, 20);

      expect(await _alphaAt(image, 10, 5), greaterThan(0));
      expect(await _alphaAt(image, 25, 5), 0);
      image.dispose();
      prepared.dispose();
    },
  );
}

// One record, its opacity effect, and the rendered alpha are inseparable for
// the record-local compositing guarantee.
// ignore: halstead-volume
void _testVectorPartialOpacityUsesRecordLocalEffect() {
  test(
    'partial vector opacity composites only the record-local Picture',
    () async {
      final prepared = await prepareVector(basicVectorBytes());
      final resourceId = CanvasResourceId('vector-opacity');
      final record = _vectorPaintRecord(
        resourceId: resourceId,
        size: const Size(20, 10),
        translation: const Offset(10, 5),
        opacity: 0.5,
      );
      final commands = TestRecordingCanvas();
      paintMainFrameRecord(commands, record, {
        resourceId: FrameVectorAssetBinding(prepared),
      }, RenderPrimitiveCacheSnapshot.empty);
      expect(_recordedArguments(commands, #saveLayer), hasLength(1));
      expect(
        _recordedArguments(commands, #saveLayer).single.first,
        const Rect.fromLTRB(-10, -5, 10, 5),
      );
      final recorder = PictureRecorder();
      paintMainFrameRecord(Canvas(recorder), record, {
        resourceId: FrameVectorAssetBinding(prepared),
      }, RenderPrimitiveCacheSnapshot.empty);
      final image = await recorder.endRecording().toImage(40, 20);

      expect(await _alphaAt(image, 10, 5), inInclusiveRange(100, 155));
      image.dispose();
      prepared.dispose();
    },
  );
}

void _testFullOpacityVectorUsesNoLayer() {
  test('full-opacity vector draws without a compositing layer', () async {
    final prepared = await prepareVector(basicVectorBytes());
    final resourceId = CanvasResourceId('vector-full-opacity');
    final commands = TestRecordingCanvas();
    paintMainFrameRecord(
      commands,
      _vectorPaintRecord(
        resourceId: resourceId,
        size: const Size(20, 10),
        translation: const Offset(10, 5),
      ),
      {resourceId: FrameVectorAssetBinding(prepared)},
      RenderPrimitiveCacheSnapshot.empty,
    );

    expect(_recordedArguments(commands, #saveLayer), isEmpty);
    expect(_recordedArguments(commands, #drawPicture), hasLength(1));
    prepared.dispose();
  });
}

void _testZeroOpacityVectorPaintsNothing() {
  test(
    'zero-opacity vector uses no layer and does not draw its Picture',
    () async {
      final prepared = await prepareVector(basicVectorBytes());
      final resourceId = CanvasResourceId('vector-zero-opacity');
      final commands = TestRecordingCanvas();
      paintMainFrameRecord(
        commands,
        _vectorPaintRecord(
          resourceId: resourceId,
          size: const Size(20, 10),
          translation: const Offset(10, 5),
          opacity: 0,
        ),
        {resourceId: FrameVectorAssetBinding(prepared)},
        RenderPrimitiveCacheSnapshot.empty,
      );

      expect(_recordedArguments(commands, #saveLayer), isEmpty);
      expect(_recordedArguments(commands, #drawPicture), isEmpty);
      prepared.dispose();
    },
  );
}

// The two records, layer count, and overlap pixels are one compositing
// outcome; splitting them would sever the per-record-opacity evidence.
// ignore: halstead-volume, source-lines-of-code
void _testVectorOpacityLayersRemainPerRecord() {
  test(
    'overlapping partial vectors compose through independent record layers',
    () async {
      final prepared = await prepareVector(basicVectorBytes());
      final firstId = CanvasResourceId('vector-first-opacity');
      final secondId = CanvasResourceId('vector-second-opacity');
      final records = [
        _vectorPaintRecord(
          resourceId: firstId,
          size: const Size(20, 10),
          translation: const Offset(10, 5),
          opacity: 0.5,
        ),
        _vectorPaintRecord(
          resourceId: secondId,
          size: const Size(20, 10),
          translation: const Offset(20, 5),
          opacity: 0.5,
        ),
      ];
      final assets = {
        firstId: FrameVectorAssetBinding(prepared),
        secondId: FrameVectorAssetBinding(prepared),
      };
      final commands = TestRecordingCanvas();
      for (final record in records) {
        paintMainFrameRecord(
          commands,
          record,
          assets,
          RenderPrimitiveCacheSnapshot.empty,
        );
      }
      expect(_recordedArguments(commands, #saveLayer), hasLength(2));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      for (final record in records) {
        paintMainFrameRecord(
          canvas,
          record,
          assets,
          RenderPrimitiveCacheSnapshot.empty,
        );
      }
      final image = await recorder.endRecording().toImage(40, 20);
      expect(await _alphaAt(image, 5, 5), inInclusiveRange(100, 155));
      expect(await _alphaAt(image, 15, 5), inInclusiveRange(175, 220));
      expect(await _alphaAt(image, 25, 5), inInclusiveRange(100, 155));
      image.dispose();
      prepared.dispose();
    },
  );
}

List<List<Object?>> _recordedArguments(
  TestRecordingCanvas canvas,
  Symbol memberName,
) {
  return [
    for (final recorded in canvas.invocations)
      if (recorded.invocation.memberName == memberName)
        List<Object?>.from(recorded.invocation.positionalArguments),
  ];
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

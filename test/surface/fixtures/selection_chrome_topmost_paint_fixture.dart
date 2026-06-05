import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';

void main() {
  _registerSelectionChromePaintBoundaryTests();
  _registerTopmostChromeTest();
  _registerPaintOrderTests();
  _registerOutsideBoxChromeTests();
  _registerOutlineChromeTest();
}

void _registerSelectionChromePaintBoundaryTests() {
  test('main painter consumes topmost selection chrome frame plans', () {
    final mainPainterSource = File(
      'lib/src/surface/main_painter.dart',
    ).readAsStringSync();

    expect(mainPainterSource, contains('selectionDecorationPlan'));
    expect(
      mainPainterSource,
      contains('paintMainFrameRecordsAndSelectionDecorations(canvas, output)'),
    );
    expect(mainPainterSource, isNot(contains('paintOrderToken')));
    expect(mainPainterSource, isNot(contains('nextDecorationIndex')));
    expect(mainPainterSource, isNot(contains('.sort(')));
    expect(mainPainterSource, isNot(contains('SelectedOrderSnapshot')));
    expect(mainPainterSource, isNot(contains('selectedOrderSnapshot')));
    expect(mainPainterSource, isNot(contains('saveLayer')));
    expect(mainPainterSource, isNot(contains('ordinaryPaintRecordCache')));
  });
}

void _registerTopmostChromeTest() {
  testWidgets('selection chrome paints above higher-order records', (
    tester,
  ) async {
    final output = await _selectedFrameOutput(
      tester,
      document: _overlappingDocument(),
      selectedIds: [CanvasElementId('selected')],
    );
    final selectedBounds =
        output.selectionDecorationPlan.primitives.single.boundsWorld;

    expect(
      (await _pixelAt(
        tester,
        output,
        selectedBounds.left.round() - 2,
        selectedBounds.center.dy.round(),
      )).isBlueStroke,
      isTrue,
    );
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

void _registerOutsideBoxChromeTests() {
  testWidgets('box chrome strokes stay outside primitive bounds', (
    tester,
  ) async {
    final rect = await _selectedFrameOutput(
      tester,
      document: _singleRectDocument(),
      selectedIds: [CanvasElementId('selected')],
    );
    final image = await _selectedFrameOutput(
      tester,
      document: _singleImageDocument(),
      selectedIds: [CanvasElementId('image')],
    );
    final group = await _selectedFrameOutput(
      tester,
      document: _multiSelectLineStrokeDocument(),
      selectedIds: [CanvasElementId('line'), CanvasElementId('stroke')],
    );

    final samples = await _sampleOutsideBoxChromePixels(
      tester,
      rect: rect,
      image: image,
      group: group,
    );

    expect(
      samples.outside.map((pixel) => pixel.isBlueStroke),
      everyElement(isTrue),
    );
    expect(
      samples.inside.map((pixel) => pixel.isBlueStroke),
      everyElement(isFalse),
    );
  });
}

Future<({List<_Pixel> outside, List<_Pixel> inside})>
_sampleOutsideBoxChromePixels(
  WidgetTester tester, {
  required MainFramePaintOutput rect,
  required MainFramePaintOutput image,
  required MainFramePaintOutput group,
}) async {
  return (
    outside: await _samplePixels(tester, [
      _PaintSample(rect, 18, 20),
      _PaintSample(image, 18, 20),
      _PaintSample(group, 8, 20),
      _PaintSample(group, 20, 18),
    ]),
    inside: await _samplePixels(tester, [
      _PaintSample(rect, 22, 22),
      _PaintSample(image, 22, 22),
      _PaintSample(group, 20, 20),
    ]),
  );
}

void _registerOutlineChromeTest() {
  testWidgets('non-box outline chrome keeps outline placement', (tester) async {
    final output = await _selectedFrameOutput(
      tester,
      document: _singleLineDocument(),
      selectedIds: [CanvasElementId('line')],
    );

    expect((await _pixelAt(tester, output, 20, 18)).blue, greaterThan(200));
  });
}

Future<MainFramePaintOutput> _selectedFrameOutput(
  WidgetTester tester, {
  required CanvasDocument document,
  required Iterable<CanvasElementId> selectedIds,
}) async {
  final runtime = CanvasRuntime(initialDocument: document);
  addTearDown(runtime.dispose);
  runtime.selection.setSelection(selectedIds);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime));

  return _mainPainter(tester).output;
}

final class _SurfaceHost extends StatelessWidget {
  const _SurfaceHost({required this.runtime});

  final CanvasRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 64,
        height: 64,
        child: CanvasSurface(
          runtime: runtime,
          interactive: false,
          selectionStyle: CanvasSelectionStyle(
            color: const Color(0xFF0000FF),
            strokeWidth: 4,
            haloWidth: 0,
          ),
        ),
      ),
    );
  }
}

MainFramePainter _mainPainter(WidgetTester tester) {
  final host = find.byKey(
    const ValueKey<String>('iwb_canvas_surface.paint_host'),
  );
  final paintHost = tester.widget<CustomPaint>(host);
  final painter = paintHost.painter;

  expect(painter, isA<MainFramePainter>());

  return painter as MainFramePainter;
}

Future<_Pixel> _pixelAt(
  WidgetTester tester,
  MainFramePaintOutput output,
  int x,
  int y,
) async {
  final pixel = await tester.runAsync(() => _recordedPixelAt(output, x, y));
  if (pixel == null) {
    throw StateError('selection chrome topmost paint test produced no pixel');
  }

  return pixel;
}

Future<List<_Pixel>> _samplePixels(
  WidgetTester tester,
  List<_PaintSample> samples,
) async {
  final pixels = <_Pixel>[];
  for (final sample in samples) {
    final pixel = await _pixelAt(tester, sample.output, sample.x, sample.y);
    pixels.add(pixel);
  }

  return pixels;
}

Future<_Pixel> _recordedPixelAt(
  MainFramePaintOutput output,
  int x,
  int y,
) async {
  final recorder = ui.PictureRecorder();
  MainFramePainter(
    output: output,
  ).paint(ui.Canvas(recorder), const Size(64, 64));
  final image = await recorder.endRecording().toImage(64, 64);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('selection chrome topmost paint test produced no pixels');
  }

  return _pixelFrom(bytes.buffer.asUint8List(), x, y);
}

_Pixel _pixelFrom(List<int> rgba, int x, int y) {
  final offset = (y * 64 + x) * 4;

  return _Pixel(
    red: rgba[offset],
    green: rgba[offset + 1],
    blue: rgba[offset + 2],
    alpha: rgba[offset + 3],
  );
}

CanvasDocument _overlappingDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          _rect(
            'selected',
            translation: const Offset(30, 20),
            fillColor: const Color(0xFF00AA00),
          ),
          _rect(
            'cover',
            translation: const Offset(26, 16),
            size: const Size(28, 28),
            fillColor: const Color(0xFFFF0000),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _singleRectDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [_rect('selected', translation: const Offset(30, 20))],
      ),
    ],
  );
}

CanvasDocument _singleImageDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('image-a'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(30, 20)),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _multiSelectLineStrokeDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasLineElement(
            id: CanvasElementId('line'),
            start: const Offset(10, 20),
            end: const Offset(18, 20),
            thickness: 2,
            color: const Color(0x00000000),
          ),
          CanvasStrokeElement(
            id: CanvasElementId('stroke'),
            points: const [Offset(24, 20), Offset(30, 20)],
            thickness: 2,
            color: const Color(0x00000000),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _singleLineDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasLineElement(
            id: CanvasElementId('line'),
            start: const Offset(10, 20),
            end: const Offset(30, 20),
            thickness: 2,
            color: const Color(0x00000000),
          ),
        ],
      ),
    ],
  );
}

CanvasRectElement _rect(
  String id, {
  required Offset translation,
  Size size = const Size(20, 20),
  Color? fillColor,
}) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: size,
    fillColor: fillColor,
    transform: CanvasTransform.translation(translation),
  );
}

final class _PaintSample {
  const _PaintSample(this.output, this.x, this.y);

  final MainFramePaintOutput output;
  final int x;
  final int y;
}

final class _Pixel {
  const _Pixel({
    required this.red,
    required this.green,
    required this.blue,
    required this.alpha,
  });

  final int red;
  final int green;
  final int blue;
  final int alpha;

  List<int> get rgba => [red, green, blue, alpha];
  bool get isBlueStroke =>
      red == 0 && green == 0 && blue == 255 && alpha == 255;

  @override
  String toString() {
    return '_Pixel(red: $red, green: $green, blue: $blue, alpha: $alpha)';
  }
}

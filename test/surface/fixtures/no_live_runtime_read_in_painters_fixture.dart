import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

void main() {
  _registerBehavioralPainterBoundaryTests();
  _registerPainterBoundaryTests();
  _registerOverlayPainterBoundaryTests();
  _registerMainPainterBoundaryTests();
}

void _registerBehavioralPainterBoundaryTests() {
  testWidgets(
    'surface painters do not invoke live resolver paths during paint',
    (tester) async {
      final image = _createImage();
      final resolver = _CountingResolver(image);
      final runtime = CanvasRuntime();
      addTearDown(runtime.dispose);
      addTearDown(image.dispose);
      runtime.edits.loadDocumentFromJson(
        encodeCanvasDocumentToJson(_document()),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 100,
            height: 100,
            child: CanvasSurface(runtime: runtime, resourceResolver: resolver),
          ),
        ),
      );

      final stateBeforePaint = runtime.state.value;
      expect(resolver.calls, 1);
      _paintCurrentOutputs(tester);
      _paintCurrentOutputs(tester);

      expect(resolver.calls, 1);
      expect(runtime.state.value, same(stateBeforePaint));
    },
  );
}

void _registerPainterBoundaryTests() {
  test('surface painters consume immutable output listenables only', () {
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
}

void _registerMainPainterBoundaryTests() {
  test('main painter consumes derived frame plans', () {
    final mainPainterSource = File(
      'lib/src/surface/main_painter.dart',
    ).readAsStringSync();

    expect(mainPainterSource, contains('staticBackgroundPlan'));
    expect(mainPainterSource, contains('drawPicture'));
    expect(mainPainterSource, isNot(contains('StaticBackgroundPrimitive')));
  });
}

void _expectPainterBoundary(String path) {
  final source = File(path).readAsStringSync();

  expect(source, contains('FramePaintOutput'));
  expect(source, contains('outputListenable'));
  expect(source, contains('super(repaint: outputListenable)'));
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
    'buildSurfaceMainFrame',
    'buildSurfaceOverlayFrame',
  ]) {
    expect(source, isNot(contains(forbidden)));
  }
}

void _paintCurrentOutputs(WidgetTester tester) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  _mainPainter(tester).paint(canvas, const Size(100, 100));
  _overlayPainter(tester).paint(canvas, const Size(100, 100));
  recorder.endRecording().dispose();
}

MainFramePainter _mainPainter(WidgetTester tester) {
  final paintHost = tester.widget<CustomPaint>(
    find.byKey(const ValueKey<String>('iwb_canvas_surface.main_paint_host')),
  );
  final painter = paintHost.painter;
  expect(painter, isA<MainFramePainter>());

  return painter as MainFramePainter;
}

OverlayFramePainter _overlayPainter(WidgetTester tester) {
  final paintHost = tester.widget<CustomPaint>(
    find.byKey(const ValueKey<String>('iwb_canvas_surface.overlay_paint_host')),
  );
  final painter = paintHost.painter;
  expect(painter, isA<OverlayFramePainter>());

  return painter as OverlayFramePainter;
}

ui.Image _createImage() {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const Color(0xFFFFFFFF),
  );

  return recorder.endRecording().toImageSync(1, 1);
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(10, 10),
          ),
        ],
      ),
    ],
  );
}

final class _CountingResolver implements CanvasResourceResolver {
  _CountingResolver(this._image);

  final ui.Image _image;
  int calls = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    calls += 1;

    return _image;
  }
}

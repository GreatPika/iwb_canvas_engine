import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  _registerPainterBoundaryTests();
  _registerLayerHostBoundaryTests();
  _registerOverlayPainterBoundaryTests();
  _registerMainPainterBoundaryTests();
}

void _registerPainterBoundaryTests() {
  test('surface painters consume immutable output listenables only', () {
    expect(File('lib/src/surface/main_painter.dart').existsSync(), isTrue);
    _expectPainterBoundary('lib/src/surface/main_painter.dart');
    _expectPainterBoundary('lib/src/surface/overlay_painter.dart');
  });
}

void _registerLayerHostBoundaryTests() {
  test('surface layer host isolates main and overlay repaint boundaries', () {
    final source = File(
      'lib/src/surface/layer_paint_host.dart',
    ).readAsStringSync();

    expect(_tokenCount(source, 'RepaintBoundary('), 2);
    expect(_tokenCount(source, 'CustomPaint('), 2);
    expect(source, contains('iwb_canvas_surface.main_paint_host'));
    expect(source, contains('iwb_canvas_surface.overlay_paint_host'));
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

int _tokenCount(String source, String token) {
  return token.allMatches(source).length;
}

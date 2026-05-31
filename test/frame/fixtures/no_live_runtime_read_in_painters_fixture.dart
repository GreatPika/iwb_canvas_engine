import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('painters import only immutable frame paint outputs', () {
    expect(File('lib/src/frame/main_frame_painter.dart').existsSync(), isTrue);
    _expectPainterBoundary('lib/src/frame/main_frame_painter.dart');
    _expectPainterBoundary('lib/src/frame/overlay_frame_painter.dart');
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

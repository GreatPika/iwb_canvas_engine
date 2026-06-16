import 'dart:ui';

// This clipping fixture crosses public canvas types, frame capture, spatial
// setup, and painter output in one behavior proof.
// ignore_for_file: number-of-imports

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';
import 'painter_clipping_test_support.dart';

void main() {
  test('main painter clips committed paint to the CustomPaint size', () async {
    final output = _mainOutputWithOutsideRecord();

    expect(
      await alphaAt(
        (canvas) => MainFramePainter(
          outputListenable: ValueNotifier(output),
        ).paint(canvas, const Size(32, 32)),
        x: 36,
        y: 12,
      ),
      0,
    );
  });
}

MainFramePaintOutput _mainOutputWithOutsideRecord() {
  final frameFacts = frameFactsPort(
    elements: [
      translatedRectFacts(
        'outside-main',
        orderToken: 1,
        translation: const Offset(28, 8),
      ),
    ],
  );
  final spatialKernel = SpatialKernel()..rebuild(frameFacts);
  final engine = FrameEngine(
    frameFacts: frameFacts,
    selectionFacts: TestSelectionFactsPort.empty(),
    spatialKernel: spatialKernel,
  );

  return engine.buildResourceFreeMainFrame(
    inputs: _captureInputs(),
    viewCameraBucket: 0,
  );
}

FrameCaptureInputs _captureInputs() {
  return const FrameCaptureInputs(
    viewportWorldBounds: Rect.fromLTWH(0, 0, 32, 32),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
    preview: CanvasNoPreview(),
    previewRevision: 1,
  );
}

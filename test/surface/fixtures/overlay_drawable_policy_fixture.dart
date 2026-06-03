import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/frame_repaint_signal.dart';
import 'package:iwb_canvas_engine/src/frame/overlay_preview_planner.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';

void main() {
  _testOverlayOnePointPreviews();
  _testOverlayEmptyPreviews();
}

void _testOverlayOnePointPreviews() {
  test('overlay one-point stroke previews produce visible pixels', () async {
    expect(
      await _overlayAlphaAt(
        CanvasPencilStrokePreview(
          points: const [Offset(5, 5)],
          color: const Color(0xFFFF0000),
          thickness: 6,
          opacity: 1,
        ),
      ),
      greaterThan(0),
    );
    expect(
      await _overlayAlphaAt(
        CanvasMarkerStrokePreview(
          points: const [Offset(5, 5)],
          color: const Color(0xFF00FF00),
          thickness: 6,
          opacity: 0.8,
        ),
      ),
      greaterThan(0),
    );
    expect(
      await _overlayAlphaAt(
        CanvasEraserPreview(corridor: const [Offset(5, 5)], thickness: 6),
      ),
      greaterThan(0),
    );
  });
}

void _testOverlayEmptyPreviews() {
  test('overlay empty point lists are no-op', () async {
    expect(
      await _overlayAlphaAt(
        CanvasPencilStrokePreview(
          points: const [],
          color: const Color(0xFFFF0000),
          thickness: 6,
          opacity: 1,
        ),
      ),
      0,
    );
    expect(
      await _overlayAlphaAt(
        CanvasEraserPreview(corridor: const [], thickness: 6),
      ),
      0,
    );
  });
}

Future<int> _overlayAlphaAt(CanvasPreviewState preview) {
  final frame = capturedOverlayFrameFor(preview);
  final plan = const OverlayPreviewPlanner().build(frame);
  final output = OverlayFramePaintOutput(
    capturedFrame: frame,
    overlayPreviewPlan: plan,
    repaintSignal: const FrameRepaintSignal(
      mainCanvas: false,
      overlayCanvas: true,
      reason: 'test',
    ),
  );

  return _alphaAt(
    (canvas) =>
        OverlayFramePainter(output: output).paint(canvas, const Size(32, 32)),
    5,
    5,
  );
}

Future<int> _alphaAt(void Function(Canvas canvas) paint, int x, int y) async {
  final recorder = PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(32, 32);
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('overlay drawable policy test produced no pixel data');
  }

  return bytes.buffer.asUint8List()[(y * 32 + x) * 4 + 3];
}

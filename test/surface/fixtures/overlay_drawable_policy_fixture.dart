import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/frame_repaint_signal.dart';
import 'package:iwb_canvas_engine/src/frame/overlay_preview_planner.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';

void main() {
  _testOverlayOnePointPreviews();
  _testOverlayStrokePreviewJoins();
  _testOverlayLinePreviewCaps();
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

void _testOverlayStrokePreviewJoins() {
  test('overlay stroke previews paint path joins as solid turns', () async {
    final preview = CanvasMarkerStrokePreview(
      points: const [Offset(8, 24), Offset(16, 8), Offset(24, 24)],
      color: const Color(0xFF00FF00),
      thickness: 10,
      opacity: 0.8,
    );

    expect(await _overlayAlphaAt(preview, x: 16, y: 5), greaterThan(0));
    expect(await _overlayAlphaAt(preview, x: 16, y: 1), 0);
  });
}

void _testOverlayLinePreviewCaps() {
  test('overlay line previews paint round caps', () async {
    const preview = CanvasLinePreview(
      start: Offset(8, 16),
      end: Offset(24, 16),
      color: Color(0xFF0000FF),
      thickness: 10,
    );

    expect(await _overlayAlphaAt(preview, x: 4, y: 16), greaterThan(0));
    expect(await _overlayAlphaAt(preview, x: 2, y: 16), 0);
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

Future<int> _overlayAlphaAt(
  CanvasPreviewState preview, {
  int x = 5,
  int y = 5,
}) {
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
    (canvas) => OverlayFramePainter(
      outputListenable: ValueNotifier(output),
    ).paint(canvas, const Size(32, 32)),
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
    throw StateError('overlay drawable policy test produced no pixel data');
  }

  return bytes.buffer.asUint8List()[(y * 32 + x) * 4 + 3];
}

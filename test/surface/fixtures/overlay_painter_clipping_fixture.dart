import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/frame_repaint_signal.dart';
import 'package:iwb_canvas_engine/src/frame/overlay_preview_planner.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';
import 'painter_clipping_test_support.dart';

void main() {
  test('overlay painter clips preview paint to the CustomPaint size', () async {
    final output = _overlayOutputWithOutsidePreview();

    expect(
      await alphaAt(
        (canvas) => OverlayFramePainter(
          output: output,
        ).paint(canvas, const Size(32, 32)),
        x: 36,
        y: 12,
      ),
      0,
    );
  });
}

OverlayFramePaintOutput _overlayOutputWithOutsidePreview() {
  final frame = capturedOverlayFrameFor(
    const CanvasLinePreview(
      start: Offset(28, 12),
      end: Offset(44, 12),
      color: Color(0xFFFF0000),
      thickness: 8,
    ),
  );
  final plan = const OverlayPreviewPlanner().build(frame);

  return OverlayFramePaintOutput(
    capturedFrame: frame,
    overlayPreviewPlan: plan,
    repaintSignal: const FrameRepaintSignal(
      mainCanvas: false,
      overlayCanvas: true,
      reason: 'test',
    ),
  );
}

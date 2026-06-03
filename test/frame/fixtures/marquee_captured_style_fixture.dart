import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/frame_repaint_signal.dart';
import 'package:iwb_canvas_engine/src/frame/overlay_preview_planner.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('marquee primitive carries captured selection style', () {
    final style = _selectionStyle();
    final frame = capturedOverlayFrameFor(_marquee(), selectionStyle: style);
    final primitive =
        const OverlayPreviewPlanner().build(frame).primitives.single
            as MarqueeOverlayPrimitive;

    expect(primitive.color, style.color);
    expect(primitive.strokeWidth, style.strokeWidth);
    expect(primitive.fillOpacity, style.marqueeFillOpacity);
  });

  test('marquee painter uses captured fill and stroke style', () async {
    final center = await _marqueePixelAt(10, 10);
    final stroke = await _marqueePixelAt(4, 10);

    expect(center.alpha, greaterThan(0));
    expect(center.red, greaterThan(center.blue));
    expect(stroke.alpha, greaterThan(center.alpha));
    expect(stroke.red, greaterThan(stroke.blue));
  });
}

CanvasMarqueePreview _marquee() {
  return const CanvasMarqueePreview(rect: Rect.fromLTWH(4, 4, 16, 16));
}

CanvasSelectionStyle _selectionStyle() {
  return CanvasSelectionStyle(
    color: const Color(0xFFFF3300),
    strokeWidth: 4,
    marqueeFillOpacity: 0.5,
  );
}

Future<_Pixel> _marqueePixelAt(int x, int y) async {
  final image = await _recordMarqueePicture().toImage(32, 32);
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('marquee captured-style test produced no pixel data');
  }

  return _pixelFrom(bytes.buffer.asUint8List(), x, y);
}

Picture _recordMarqueePicture() {
  final frame = capturedOverlayFrameFor(
    _marquee(),
    selectionStyle: _selectionStyle(),
  );
  final output = OverlayFramePaintOutput(
    capturedFrame: frame,
    overlayPreviewPlan: const OverlayPreviewPlanner().build(frame),
    repaintSignal: const FrameRepaintSignal(
      mainCanvas: false,
      overlayCanvas: true,
      reason: 'test',
    ),
  );
  final recorder = PictureRecorder();
  OverlayFramePainter(
    output: output,
  ).paint(Canvas(recorder), const Size(32, 32));

  return recorder.endRecording();
}

_Pixel _pixelFrom(List<int> rgba, int x, int y) {
  final offset = (y * 32 + x) * 4;

  return _Pixel(
    red: rgba[offset],
    blue: rgba[offset + 2],
    alpha: rgba[offset + 3],
  );
}

final class _Pixel {
  const _Pixel({required this.red, required this.blue, required this.alpha});

  final int red;
  final int blue;
  final int alpha;
}

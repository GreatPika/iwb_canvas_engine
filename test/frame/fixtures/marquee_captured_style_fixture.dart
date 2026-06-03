import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/overlay_preview_planner.dart';

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

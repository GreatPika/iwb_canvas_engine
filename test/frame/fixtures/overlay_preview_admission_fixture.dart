import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/overlay_preview_planner.dart';

import 'ordinary_paint_test_support.dart';

// Overlay preview variants are checked in one table so selected-move exclusion
// and every overlay-only primitive remain part of the same admission proof.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test(
    'overlay previews admit immutable primitives and exclude selected move',
    () {
      const planner = OverlayPreviewPlanner();
      final previews = <CanvasPreviewState>[
        const CanvasMarqueePreview(rect: Rect.fromLTWH(0, 0, 1, 1)),
        CanvasPencilStrokePreview(
          points: const [Offset(1, 1)],
          color: const Color(0xFF111111),
          thickness: 1,
          opacity: 0.5,
        ),
        CanvasMarkerStrokePreview(
          points: const [Offset(2, 2)],
          color: const Color(0xFF222222),
          thickness: 2,
          opacity: 0.6,
        ),
        const CanvasPendingLineStartPreview(
          start: Offset(3, 3),
          timestampMs: 4,
          color: Color(0xFF333333),
          thickness: 3,
        ),
        const CanvasLinePreview(
          start: Offset(4, 4),
          end: Offset(5, 5),
          color: Color(0xFF444444),
          thickness: 4,
        ),
        CanvasEraserPreview(corridor: const [Offset(6, 6)], thickness: 5),
      ];

      final kinds = [
        for (final preview in previews)
          planner
              .build(capturedOverlayFrameFor(preview))
              .primitives
              .single
              .kind,
      ];

      expect(kinds, [
        OverlayPreviewPrimitiveKind.marquee,
        OverlayPreviewPrimitiveKind.pencilStroke,
        OverlayPreviewPrimitiveKind.markerStroke,
        OverlayPreviewPrimitiveKind.pendingLineStart,
        OverlayPreviewPrimitiveKind.linePreview,
        OverlayPreviewPrimitiveKind.eraser,
      ]);
      expect(
        planner
            .build(
              capturedOverlayFrameFor(
                const CanvasSelectedMovePreview(delta: Offset(1, 1)),
              ),
            )
            .primitives,
        isEmpty,
      );
    },
  );
}

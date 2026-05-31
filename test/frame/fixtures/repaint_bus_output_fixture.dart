import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';

import 'ordinary_paint_test_support.dart';

// The repaint proof keeps main selected-move and overlay preview outputs in one
// scenario so target routing can be compared without hidden scheduler state.
// ignore: halstead-volume
void main() {
  test(
    'selected move invalidates main and overlay previews invalidate overlay',
    () {
      final frameFacts = frameFactsPort(
        elements: [rectFacts('a', orderToken: 1)],
      );
      final spatial = SpatialKernel()..rebuild(frameFacts);
      final engine = FrameEngine(
        frameFacts: frameFacts,
        selectionFacts: TestSelectionFactsPort(
          SelectionFacts(
            selectedElementIds: [CanvasElementId('a')],
            selectionRevision: 1,
          ),
        ),
        spatialKernel: spatial,
      );

      final main = engine.buildResourceFreeMainFrame(
        inputs: _inputs(const CanvasSelectedMovePreview(delta: Offset(1, 0))),
        viewCameraBucket: 0,
      );
      final overlay = engine.buildResourceFreeOverlayFrame(
        inputs: _inputs(
          const CanvasLinePreview(
            start: Offset.zero,
            end: Offset(1, 1),
            color: Color(0xFF000000),
            thickness: 1,
          ),
        ),
      );

      expect(main.repaintSignal.mainCanvas, isTrue);
      expect(main.repaintSignal.overlayCanvas, isFalse);
      expect(main.repaintSignal.reason, 'selected_move_preview');
      expect(overlay.repaintSignal.mainCanvas, isFalse);
      expect(overlay.repaintSignal.overlayCanvas, isTrue);
    },
  );
}

FrameCaptureInputs _inputs(CanvasPreviewState preview) {
  return FrameCaptureInputs(
    viewportWorldBounds: const Rect.fromLTWH(0, 0, 10, 10),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
    preview: preview,
    previewRevision: 1,
  );
}

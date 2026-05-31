import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';

import 'ordinary_paint_test_support.dart';

// The repaint proof keeps main selected-move and overlay preview outputs in one
// scenario so target routing can be compared without hidden scheduler state.
// ignore: halstead-volume
void main() {
  _testSelectedMoveAndOverlayRouting();
}

void _testSelectedMoveAndOverlayRouting() {
  test(
    'selected move invalidates main and overlay previews invalidate overlay',
    () {
      final (:main, :overlay) = _selectedMoveAndOverlayOutputs();

      expect(main.repaintSignal.reason, 'selected_move_preview');
      expect(main.repaintSignal.mainCanvas, isTrue);
      expect(main.repaintSignal.overlayCanvas, isFalse);
      expect(
        main
            .selectedMoveSupplementPlan
            .probe
            .ordinaryCacheWritesDuringSupplement,
        0,
      );
      expect(overlay.repaintSignal.mainCanvas, isFalse);
      expect(overlay.repaintSignal.overlayCanvas, isTrue);
    },
  );
}

({MainFramePaintOutput main, OverlayFramePaintOutput overlay})
_selectedMoveAndOverlayOutputs() {
  final row = rectFacts('a', orderToken: 1);
  final frameFacts = frameFactsPort(elements: [row]);
  final spatial = SpatialKernel()..rebuild(frameFacts);
  final engine = FrameEngine(
    frameFacts: frameFacts,
    selectionFacts: TestSelectionFactsPort(
      SelectionFacts(selectedElementIds: [row.id], selectionRevision: 1),
    ),
    spatialKernel: spatial,
  );

  return (
    main: engine.buildResourceFreeMainFrame(
      inputs: _inputs(const CanvasSelectedMovePreview(delta: Offset(1, 0))),
      viewCameraBucket: 0,
    ),
    overlay: engine.buildResourceFreeOverlayFrame(
      inputs: _inputs(
        const CanvasLinePreview(
          start: Offset.zero,
          end: Offset(1, 1),
          color: Color(0xFF000000),
          thickness: 1,
        ),
      ),
    ),
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

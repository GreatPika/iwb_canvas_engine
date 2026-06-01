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
      final (
        :selectedMoveMain,
        :selectedMoveOverlay,
        :marqueeMain,
        :marqueeOverlay,
      ) = _selectedMoveAndOverlayOutputs();

      expect(selectedMoveMain.repaintSignal.reason, 'selected_move_preview');
      expect(selectedMoveMain.repaintSignal.mainCanvas, isTrue);
      expect(selectedMoveMain.repaintSignal.overlayCanvas, isFalse);
      expect(
        selectedMoveMain
            .selectedMoveSupplementPlan
            .probe
            .ordinaryCacheWritesDuringSupplement,
        0,
      );
      expect(selectedMoveOverlay.overlayPreviewPlan.primitives, isEmpty);
      expect(selectedMoveOverlay.repaintSignal.mainCanvas, isFalse);
      expect(selectedMoveOverlay.repaintSignal.overlayCanvas, isFalse);
      expect(marqueeMain.capturedFrame.selectedMovePreview, isNull);
      expect(marqueeMain.selectedMoveSupplementPlan.probe.supplementCount, 0);
      expect(marqueeMain.repaintSignal.reason, 'main_frame');
      expect(marqueeMain.repaintSignal.mainCanvas, isTrue);
      expect(marqueeMain.repaintSignal.overlayCanvas, isFalse);
      expect(marqueeOverlay.repaintSignal.mainCanvas, isFalse);
      expect(marqueeOverlay.repaintSignal.overlayCanvas, isTrue);
    },
  );
}

({
  MainFramePaintOutput selectedMoveMain,
  OverlayFramePaintOutput selectedMoveOverlay,
  MainFramePaintOutput marqueeMain,
  OverlayFramePaintOutput marqueeOverlay,
})
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
    selectedMoveMain: engine.buildResourceFreeMainFrame(
      inputs: _inputs(const CanvasSelectedMovePreview(delta: Offset(1, 0))),
      viewCameraBucket: 0,
    ),
    selectedMoveOverlay: engine.buildResourceFreeOverlayFrame(
      inputs: _inputs(const CanvasSelectedMovePreview(delta: Offset(1, 0))),
    ),
    marqueeMain: engine.buildResourceFreeMainFrame(
      inputs: _inputs(
        const CanvasMarqueePreview(rect: Rect.fromLTWH(0, 0, 1, 1)),
      ),
      viewCameraBucket: 0,
    ),
    marqueeOverlay: engine.buildResourceFreeOverlayFrame(
      inputs: _inputs(
        const CanvasMarqueePreview(rect: Rect.fromLTWH(0, 0, 1, 1)),
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

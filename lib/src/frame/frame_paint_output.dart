import 'captured_frame.dart';
import 'frame_repaint_signal.dart';
import 'overlay_preview_planner.dart';
import 'paint_asset_binding_service.dart';
import 'paint_plan.dart';
import 'render_primitive_cache_snapshot.dart';
import 'selected_move_supplement_planner.dart';
import 'selection_decoration_planner.dart';
import 'static_background_planner.dart';

final class MainFramePaintOutput {
  const MainFramePaintOutput({
    required this.capturedFrame,
    required this.ordinaryPlan,
    required this.staticBackgroundPlan,
    required this.selectionDecorationPlan,
    required this.selectedMoveSupplementPlan,
    required this.renderPrimitiveSnapshot,
    required this.assetBindings,
    required this.repaintSignal,
  });

  final CapturedMainFrame capturedFrame;
  final PaintPlan ordinaryPlan;
  final StaticBackgroundPlan staticBackgroundPlan;
  final SelectionDecorationPlan selectionDecorationPlan;
  final SelectedMoveSupplementPlan selectedMoveSupplementPlan;
  final RenderPrimitiveCacheSnapshot renderPrimitiveSnapshot;
  final FrameAssetBindings assetBindings;
  final FrameRepaintSignal repaintSignal;

  MainFramePaintOutput withAssetBindings(FrameAssetBindings nextBindings) {
    if (identical(nextBindings, assetBindings)) {
      return this;
    }

    return MainFramePaintOutput(
      capturedFrame: capturedFrame,
      ordinaryPlan: ordinaryPlan,
      staticBackgroundPlan: staticBackgroundPlan,
      selectionDecorationPlan: selectionDecorationPlan,
      selectedMoveSupplementPlan: selectedMoveSupplementPlan,
      renderPrimitiveSnapshot: renderPrimitiveSnapshot,
      assetBindings: nextBindings,
      repaintSignal: repaintSignal,
    );
  }
}

final class OverlayFramePaintOutput {
  const OverlayFramePaintOutput({
    required this.capturedFrame,
    required this.overlayPreviewPlan,
    required this.repaintSignal,
  });

  final CapturedOverlayFrame capturedFrame;
  final OverlayPreviewPlan overlayPreviewPlan;
  final FrameRepaintSignal repaintSignal;
}

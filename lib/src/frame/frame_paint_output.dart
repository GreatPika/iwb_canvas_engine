import '../contracts/public/canvas_ids.dart';
import '../resources/resource_resolver_adapter.dart';
import 'captured_frame.dart';
import 'frame_repaint_bus.dart';
import 'overlay_preview_planner.dart';
import 'paint_plan.dart';
import 'selected_move_supplement_planner.dart';
import 'selected_order_cache.dart';
import 'selection_decoration_planner.dart';
import 'static_background_planner.dart';

final class FrameAssetBindings {
  FrameAssetBindings({
    required Map<CanvasResourceId, ResourceImageResolveResult> images,
  }) : images = Map.unmodifiable(images);

  static final empty = FrameAssetBindings(images: const {});

  final Map<CanvasResourceId, ResourceImageResolveResult> images;
}

final class MainFramePaintOutput {
  const MainFramePaintOutput({
    required this.capturedFrame,
    required this.ordinaryPlan,
    required this.staticBackgroundPlan,
    required this.selectionDecorationPlan,
    required this.selectedOrderSnapshot,
    required this.selectedMoveSupplementPlan,
    required this.renderPrimitiveSnapshot,
    required this.assetBindings,
    required this.repaintSignal,
  });

  final CapturedMainFrame capturedFrame;
  final PaintPlan ordinaryPlan;
  final StaticBackgroundPlan staticBackgroundPlan;
  final SelectionDecorationPlan selectionDecorationPlan;
  final SelectedOrderSnapshot selectedOrderSnapshot;
  final SelectedMoveSupplementPlan selectedMoveSupplementPlan;
  final RenderPrimitiveCacheSnapshot renderPrimitiveSnapshot;
  final FrameAssetBindings assetBindings;
  final FrameRepaintSignal repaintSignal;
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

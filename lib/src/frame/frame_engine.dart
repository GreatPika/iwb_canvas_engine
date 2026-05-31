// The frame facade imports the documented collaborators together so capture,
// ordinary planning, selected staging, background, overlay, and repaint output
// order remains explicit.
// ignore_for_file: number-of-imports

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/spatial_kernel.dart';
import 'captured_frame.dart';
import 'frame_capture_service.dart';
import 'frame_paint_output.dart';
import 'frame_repaint_signal.dart';
import 'ordinary_paint_planner.dart';
import 'overlay_preview_planner.dart';
import 'paint_asset_binding_service.dart';
import 'paint_plan.dart';
import 'render_element_record.dart';
import 'selected_move_supplement_planner.dart';
import 'selected_order_cache.dart';
import 'selection_decoration_planner.dart';
import 'static_background_planner.dart';

typedef FrameAssetBindingBuilder =
    FrameAssetBindings Function({
      required CapturedFrameSnapshot frame,
      required Iterable<RenderElementRecord> records,
    });

// The facade intentionally coordinates the frame collaborators instead of
// hiding ownership and cache lifecycle order behind metric-shaped wrappers.
// ignore: coupling-between-object-classes, number-of-methods
final class FrameEngine {
  FrameEngine({
    required FrameFactsPort frameFacts,
    required SelectionFactsPort selectionFacts,
    required SpatialKernel spatialKernel,
  }) : _frameFacts = frameFacts,
       _capture = FrameCaptureService(
         frameFacts: frameFacts,
         selectionFacts: selectionFacts,
         queryPaint: spatialKernel.queryPaint,
       ),
       _selectedMoveSupplementPlanner = SelectedMoveSupplementPlanner(
         frameFacts: frameFacts,
         queryPaint: spatialKernel.queryPaint,
       );

  final FrameFactsPort _frameFacts;
  final FrameCaptureService _capture;
  final OrdinaryPaintPlanner _ordinaryPaintPlanner = OrdinaryPaintPlanner();
  final StaticBackgroundPlanner _staticBackgroundPlanner =
      StaticBackgroundPlanner();
  final SelectionDecorationPlanner _selectionDecorationPlanner =
      SelectionDecorationPlanner();
  final SelectedOrderCache _selectedOrderCache = SelectedOrderCache();
  final OverlayPreviewPlanner _overlayPreviewPlanner =
      const OverlayPreviewPlanner();
  final SelectedMoveSupplementPlanner _selectedMoveSupplementPlanner;

  CapturedMainFrame captureMainFrame(FrameCaptureInputs inputs) {
    return _capture.captureMainFrame(inputs);
  }

  CapturedOverlayFrame captureOverlayFrame(FrameCaptureInputs inputs) {
    return _capture.captureOverlayFrame(inputs);
  }

  MainFramePaintOutput buildResourceFreeMainFrame({
    required FrameCaptureInputs inputs,
    required int viewCameraBucket,
  }) {
    return _buildMainFrame(
      inputs: inputs,
      viewCameraBucket: viewCameraBucket,
      bindAssets: null,
    );
  }

  MainFramePaintOutput buildMainFrameWithAssetBindings({
    required FrameCaptureInputs inputs,
    required int viewCameraBucket,
    required FrameAssetBindingBuilder bindAssets,
  }) {
    return _buildMainFrame(
      inputs: inputs,
      viewCameraBucket: viewCameraBucket,
      bindAssets: bindAssets,
    );
  }

  MainFramePaintOutput _buildMainFrame({
    required FrameCaptureInputs inputs,
    required int viewCameraBucket,
    required FrameAssetBindingBuilder? bindAssets,
  }) {
    final frame = captureMainFrame(inputs);
    final ordinary = _ordinaryPlanFor(frame);
    final selectedMoveSupplement = _selectedMoveSupplementPlanner.build(
      frame: frame,
      ordinaryPlan: ordinary.plan,
    );
    final staticBackgroundPlan = _staticBackgroundPlanner.build(
      frame,
      viewCameraBucket: viewCameraBucket,
    );
    final selectionDecorationPlan = _selectionDecorationPlanner.build(frame);
    final selectedOrderSnapshot = _selectedOrderSnapshot(frame);
    final renderPrimitiveSnapshot = _ordinaryPaintPlanner
        .renderPrimitiveSnapshotFor(selectedMoveSupplement.mergedRecords);
    final assetBindings = bindAssets == null
        ? FrameAssetBindings.empty
        : bindAssets(
            frame: frame.snapshot,
            records: selectedMoveSupplement.mergedRecords,
          );

    return MainFramePaintOutput(
      capturedFrame: frame,
      ordinaryPlan: ordinary.plan,
      staticBackgroundPlan: staticBackgroundPlan,
      selectionDecorationPlan: selectionDecorationPlan,
      selectedOrderSnapshot: selectedOrderSnapshot,
      selectedMoveSupplementPlan: selectedMoveSupplement,
      renderPrimitiveSnapshot: renderPrimitiveSnapshot,
      assetBindings: assetBindings,
      repaintSignal: _mainRepaintSignal(frame),
    );
  }

  _OrdinaryMainPlan _ordinaryPlanFor(CapturedMainFrame frame) {
    final ordinaryResult = _ordinaryPaintPlanner.buildOrdinaryPlan(frame);

    return _OrdinaryMainPlan(
      plan: switch (ordinaryResult) {
        OrdinaryPaintPlanReady(:final plan) => plan,
        OrdinaryPaintPlanRejected() => PaintPlan(
          key: _ordinaryPaintPlanner.paintPlanKeyFor(frame),
          ordinaryRecords: const [],
        ),
      },
    );
  }

  OverlayFramePaintOutput buildResourceFreeOverlayFrame({
    required FrameCaptureInputs inputs,
  }) {
    final frame = captureOverlayFrame(inputs);
    final plan = _overlayPreviewPlanner.build(frame);

    return OverlayFramePaintOutput(
      capturedFrame: frame,
      overlayPreviewPlan: plan,
      repaintSignal: FrameRepaintSignal(
        mainCanvas: false,
        overlayCanvas: plan.primitives.isNotEmpty,
        reason: plan.primitives.isEmpty ? 'overlay_empty' : 'overlay_preview',
      ),
    );
  }

  void dispose() {
    _staticBackgroundPlanner.dispose();
  }

  SelectedOrderSnapshot _selectedOrderSnapshot(CapturedMainFrame frame) {
    final selectedIds = frame.snapshot.selection.selectedElementIds;
    final structuralRevision = frame.snapshot.revisions.structuralRevision;

    return _selectedOrderCache.readOrBuild(
      key: SelectedOrderKey(
        selectionRevision: frame.snapshot.selection.selectionRevision,
        structuralRevision: structuralRevision,
      ),
      orderedSelectedIds: _selectedIdsInDocumentOrder(
        selectedIds,
        structuralRevision,
        _frameFacts,
      ),
    );
  }

  FrameRepaintSignal _mainRepaintSignal(CapturedMainFrame frame) {
    return FrameRepaintSignal(
      mainCanvas: true,
      overlayCanvas: false,
      reason: frame.selectedMovePreview == null
          ? 'main_frame'
          : 'selected_move_preview',
    );
  }
}

final class _OrdinaryMainPlan {
  const _OrdinaryMainPlan({required this.plan});

  final PaintPlan plan;
}

Iterable<CanvasElementId> _selectedIdsInDocumentOrder(
  Iterable<CanvasElementId> selectedIds,
  int structuralRevision,
  FrameFactsPort frameFacts,
) {
  final ordered = <FrameElementHandle>[];
  for (final id in selectedIds) {
    final handle = frameFacts.elementHandleForId(structuralRevision, id);
    if (handle != null) {
      _insertSelectedHandle(ordered, handle);
    }
  }

  return [for (final handle in ordered) handle.id];
}

void _insertSelectedHandle(
  List<FrameElementHandle> ordered,
  FrameElementHandle handle,
) {
  for (var index = 0; index < ordered.length; index += 1) {
    if (handle.orderToken < ordered[index].orderToken) {
      ordered.insert(index, handle);

      return;
    }
  }
  ordered.add(handle);
}

// The P9 frame facade imports the documented collaborators together so capture,
// ordinary planning, selected staging, background, overlay, and repaint output
// order remains explicit.
// ignore_for_file: number-of-imports

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../geometry/spatial_kernel.dart';
import 'captured_frame.dart';
import 'frame_capture_service.dart';
import 'frame_paint_output.dart';
import 'frame_repaint_bus.dart';
import 'ordinary_paint_planner.dart';
import 'overlay_preview_planner.dart';
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

// The facade intentionally coordinates the P9 frame collaborators instead of
// hiding ownership order behind metric-shaped wrapper layers.
// ignore: coupling-between-object-classes
final class FrameEngine {
  FrameEngine({
    required FrameFactsPort frameFacts,
    required SelectionFactsPort selectionFacts,
    required SpatialKernel spatialKernel,
  }) : _capture = FrameCaptureService(
         frameFacts: frameFacts,
         selectionFacts: selectionFacts,
         queryPaint: spatialKernel.queryPaint,
       ),
       _selectedMoveSupplementPlanner = SelectedMoveSupplementPlanner(
         frameFacts: frameFacts,
         queryPaint: spatialKernel.queryPaint,
       );

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
      ordinaryCacheWritesBefore: ordinary.cacheWritesBefore,
      ordinaryCacheWritesAfter: ordinary.cacheWritesAfter,
    );
    final assetBindings = bindAssets == null
        ? FrameAssetBindings.empty
        : bindAssets(
            frame: frame.snapshot,
            records: selectedMoveSupplement.mergedRecords,
          );

    return MainFramePaintOutput(
      capturedFrame: frame,
      ordinaryPlan: ordinary.plan,
      staticBackgroundPlan: _staticBackgroundPlanner.build(
        frame,
        viewCameraBucket: viewCameraBucket,
      ),
      selectionDecorationPlan: _selectionDecorationPlanner.build(frame),
      selectedOrderSnapshot: _selectedOrderSnapshot(frame),
      selectedMoveSupplementPlan: selectedMoveSupplement,
      assetBindings: assetBindings,
      repaintSignal: _mainRepaintSignal(frame),
    );
  }

  _OrdinaryMainPlan _ordinaryPlanFor(CapturedMainFrame frame) {
    final writesBefore = _ordinaryPaintPlanner.paintPlanCache.probe.writes;
    final ordinaryResult = _ordinaryPaintPlanner.buildOrdinaryPlan(frame);
    final writesAfter = _ordinaryPaintPlanner.paintPlanCache.probe.writes;

    return _OrdinaryMainPlan(
      plan: switch (ordinaryResult) {
        OrdinaryPaintPlanReady(:final plan) => plan,
        OrdinaryPaintPlanRejected() => PaintPlan(
          key: _ordinaryPaintPlanner.paintPlanKeyFor(frame),
          ordinaryRecords: const [],
        ),
      },
      cacheWritesBefore: writesBefore,
      cacheWritesAfter: writesAfter,
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

  SelectedOrderSnapshot _selectedOrderSnapshot(CapturedMainFrame frame) {
    final selectedIds = frame.snapshot.selection.selectedElementIds;

    return _selectedOrderCache.readOrBuild(
      key: SelectedOrderKey(
        selectionRevision: frame.snapshot.selection.selectionRevision,
        structuralRevision: frame.snapshot.revisions.structuralRevision,
      ),
      orderedSelectedIds: [
        for (final handle in frame.snapshot.spatialPaintCandidates)
          if (selectedIds.contains(handle.id)) handle.id,
      ],
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
  const _OrdinaryMainPlan({
    required this.plan,
    required this.cacheWritesBefore,
    required this.cacheWritesAfter,
  });

  final PaintPlan plan;
  final int cacheWritesBefore;
  final int cacheWritesAfter;
}

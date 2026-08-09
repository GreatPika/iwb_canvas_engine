import 'package:flutter/foundation.dart';

import '../contracts/internal/surface_frame_signal.dart';
import '../contracts/public/canvas_ids.dart';
import '../frame/frame_paint_output.dart';
import 'surface_frame_output_cache.dart';

typedef LayerFrameOutputBuilder = Object Function();

// Target and all-resource release stay beside the retained main output so the
// surface can preserve unrelated output without taking over cache mechanics.
// ignore: number-of-methods
final class LayerFrameOutputCache {
  final SurfaceFrameOutputCache<MainFramePaintOutput, OverlayFramePaintOutput>
  _inner = SurfaceFrameOutputCache();
  CanvasRuntimeSurfaceFrame? _pendingRuntimeFrame;

  ValueListenable<MainFramePaintOutput?> get mainOutput => _inner.mainOutput;
  ValueListenable<OverlayFramePaintOutput?> get overlayOutput {
    return _inner.overlayOutput;
  }

  void applyRuntimeFrame(
    CanvasRuntimeSurfaceFrame frame, {
    required LayerFrameOutputBuilder buildMain,
    required LayerFrameOutputBuilder buildOverlay,
  }) {
    _inner.applyRuntimeFrame(
      frame,
      buildMain: () => buildMain() as MainFramePaintOutput,
      buildOverlay: () => buildOverlay() as OverlayFramePaintOutput,
    );
  }

  void queueRuntimeFrame(CanvasRuntimeSurfaceFrame frame) {
    _pendingRuntimeFrame = _mergePendingRuntimeFrame(
      _pendingRuntimeFrame,
      frame,
    );
  }

  void applyPendingRuntimeFrame({
    required LayerFrameOutputBuilder buildMain,
    required LayerFrameOutputBuilder buildOverlay,
  }) {
    final pendingRuntimeFrame = _pendingRuntimeFrame;
    if (pendingRuntimeFrame == null) {
      return;
    }
    applyRuntimeFrame(
      pendingRuntimeFrame,
      buildMain: buildMain,
      buildOverlay: buildOverlay,
    );
    _pendingRuntimeFrame = null;
  }

  void updateLocalInputs(
    SurfaceFrameLocalInputKey key, {
    required LayerFrameOutputBuilder buildMain,
    required LayerFrameOutputBuilder buildOverlay,
  }) {
    _inner.updateLocalInputs(
      key,
      buildMain: () => buildMain() as MainFramePaintOutput,
      buildOverlay: () => buildOverlay() as OverlayFramePaintOutput,
    );
  }

  void applyLocalRepaintRequest(
    SurfaceFrameLocalRepaintRequest request, {
    required LayerFrameOutputBuilder buildMain,
  }) {
    _inner.applyLocalRepaintRequest(
      request,
      buildMain: () => buildMain() as MainFramePaintOutput,
    );
  }

  void releaseResources(Set<CanvasResourceId> ids) {
    if (ids.isEmpty) {
      return;
    }
    _inner.transformMainOutput(
      (output) =>
          output.withAssetBindings(output.assetBindings.withoutResources(ids)),
    );
  }

  void releaseAllResources() {
    _inner.transformMainOutput(
      (output) =>
          output.withAssetBindings(output.assetBindings.withoutAllResources()),
    );
  }

  void clear() {
    _pendingRuntimeFrame = null;
    _inner.clear();
  }

  void dispose() {
    _inner.dispose();
  }
}

CanvasRuntimeSurfaceFrame _mergePendingRuntimeFrame(
  CanvasRuntimeSurfaceFrame? previous,
  CanvasRuntimeSurfaceFrame next,
) {
  if (previous == null) {
    return next;
  }

  return CanvasRuntimeSurfaceFrame(
    state: next.state,
    generation: next.generation,
    repaintTarget: CanvasSurfaceRepaintTarget(
      mainCanvas:
          previous.repaintTarget.mainCanvas || next.repaintTarget.mainCanvas,
      overlayCanvas:
          previous.repaintTarget.overlayCanvas ||
          next.repaintTarget.overlayCanvas,
      reason: _mergeRepaintReasons(
        previous.repaintTarget.reason,
        next.repaintTarget.reason,
      ),
    ),
  );
}

String _mergeRepaintReasons(String previous, String next) {
  if (previous == next) {
    return next;
  }

  return '$previous+$next';
}

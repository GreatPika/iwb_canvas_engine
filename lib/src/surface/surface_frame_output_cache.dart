import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../api/canvas_runtime_surface_bridge.dart';
import '../contracts/public/canvas_surface_styles.dart';

typedef SurfaceFrameOutputBuilder<Output extends Object> = Output Function();

final class SurfaceFrameLocalInputKey {
  const SurfaceFrameLocalInputKey({
    required this.runtimeKey,
    required this.viewportWorldBounds,
    required this.devicePixelRatio,
    required this.selectionStyle,
    required this.gridStyle,
    required this.resolverGeneration,
  });

  final Object runtimeKey;
  final Rect viewportWorldBounds;
  final double devicePixelRatio;
  final CanvasSelectionStyle selectionStyle;
  final CanvasGridStyle gridStyle;
  final int resolverGeneration;
}

enum SurfaceFrameLocalRepaintRequest { resourceBudgetFollowUp }

final class SurfaceFrameOutputCache<
  MainOutput extends Object,
  OverlayOutput extends Object
> {
  SurfaceFrameOutputCache()
    : mainOutput = ValueNotifier<MainOutput?>(null),
      overlayOutput = ValueNotifier<OverlayOutput?>(null);

  final ValueNotifier<MainOutput?> mainOutput;
  final ValueNotifier<OverlayOutput?> overlayOutput;
  SurfaceFrameLocalInputKey? _localInputKey;

  void applyRuntimeFrame(
    CanvasRuntimeSurfaceFrame frame, {
    required SurfaceFrameOutputBuilder<MainOutput> buildMain,
    required SurfaceFrameOutputBuilder<OverlayOutput> buildOverlay,
  }) {
    _applyLayerTarget(
      mainCanvas: frame.repaintTarget.mainCanvas,
      overlayCanvas: frame.repaintTarget.overlayCanvas,
      buildMain: buildMain,
      buildOverlay: buildOverlay,
    );
  }

  void updateLocalInputs(
    SurfaceFrameLocalInputKey key, {
    required SurfaceFrameOutputBuilder<MainOutput> buildMain,
    required SurfaceFrameOutputBuilder<OverlayOutput> buildOverlay,
  }) {
    final target = _targetForLocalInputChange(_localInputKey, key);
    if (target == null) {
      return;
    }
    _applyLayerTarget(
      mainCanvas: target.mainCanvas,
      overlayCanvas: target.overlayCanvas,
      buildMain: buildMain,
      buildOverlay: buildOverlay,
    );
    _localInputKey = key;
  }

  void applyLocalRepaintRequest(
    SurfaceFrameLocalRepaintRequest request, {
    required SurfaceFrameOutputBuilder<MainOutput> buildMain,
  }) {
    switch (request) {
      case SurfaceFrameLocalRepaintRequest.resourceBudgetFollowUp:
        mainOutput.value = buildMain();
    }
  }

  void clear() {
    _localInputKey = null;
    mainOutput.value = null;
    overlayOutput.value = null;
  }

  void dispose() {
    mainOutput.dispose();
    overlayOutput.dispose();
  }

  void _applyLayerTarget({
    required bool mainCanvas,
    required bool overlayCanvas,
    required SurfaceFrameOutputBuilder<MainOutput> buildMain,
    required SurfaceFrameOutputBuilder<OverlayOutput> buildOverlay,
  }) {
    if (mainCanvas && overlayCanvas) {
      _replaceBoth(buildMain: buildMain, buildOverlay: buildOverlay);

      return;
    }
    if (mainCanvas) {
      mainOutput.value = buildMain();
    }
    if (overlayCanvas) {
      overlayOutput.value = buildOverlay();
    }
  }

  void _replaceBoth({
    required SurfaceFrameOutputBuilder<MainOutput> buildMain,
    required SurfaceFrameOutputBuilder<OverlayOutput> buildOverlay,
  }) {
    final nextMain = buildMain();
    final nextOverlay = buildOverlay();
    mainOutput.value = nextMain;
    overlayOutput.value = nextOverlay;
  }

  ({bool mainCanvas, bool overlayCanvas})? _targetForLocalInputChange(
    SurfaceFrameLocalInputKey? previous,
    SurfaceFrameLocalInputKey next,
  ) {
    if (previous == null ||
        !identical(previous.runtimeKey, next.runtimeKey) ||
        previous.viewportWorldBounds != next.viewportWorldBounds ||
        previous.devicePixelRatio != next.devicePixelRatio ||
        previous.selectionStyle != next.selectionStyle) {
      return (mainCanvas: true, overlayCanvas: true);
    }
    if (previous.gridStyle != next.gridStyle ||
        previous.resolverGeneration != next.resolverGeneration) {
      return (mainCanvas: true, overlayCanvas: false);
    }

    return null;
  }
}

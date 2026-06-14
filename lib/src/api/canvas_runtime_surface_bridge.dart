import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/internal/surface_frame_signal.dart';
import '../contracts/internal/surface_resource_session_lifecycle.dart';
import '../contracts/public/canvas_pointer.dart';
import '../contracts/public/canvas_surface_styles.dart';
import '../frame/frame_engine.dart';
import '../frame/frame_paint_output.dart';
import '../runtime/runtime_root.dart';

final Expando<CanvasRuntimeSurfacePort> _canvasRuntimeSurfacePorts =
    Expando<CanvasRuntimeSurfacePort>('iwb_canvas_runtime_surface_ports');

void attachCanvasRuntimeSurfacePort(Object runtime, RuntimeRoot root) {
  _canvasRuntimeSurfacePorts[runtime] = CanvasRuntimeSurfacePort._(root);
}

void detachCanvasRuntimeSurfacePort(Object runtime) {
  _canvasRuntimeSurfacePorts[runtime] = null;
}

CanvasRuntimeSurfacePort? canvasRuntimeSurfacePortFor(Object runtime) {
  return _canvasRuntimeSurfacePorts[runtime];
}

// The surface port is the single active-surface bridge; keeping attach,
// listener, resource, pointer, and frame methods together preserves the audited
// runtime/surface handoff instead of scattering one bridge across fragments.
// ignore: coupling-between-object-classes, number-of-methods
final class CanvasRuntimeSurfacePort {
  CanvasRuntimeSurfacePort._(this._root)
    : _surfaceFrame = ValueNotifier<CanvasRuntimeSurfaceFrame?>(
        _surfaceFrameFromRoot(_root.surfaceFrameSignal.value),
      ) {
    _root.surfaceFrameSignal.addListener(_publishSurfaceFrame);
  }

  final RuntimeRoot _root;
  final ValueNotifier<CanvasRuntimeSurfaceFrame?> _surfaceFrame;

  ValueListenable<CanvasRuntimeSurfaceFrame?> get surfaceFrame => _surfaceFrame;

  ResolverMutationGuard get resolverMutationGuard => _root;

  void _publishSurfaceFrame() {
    _surfaceFrame.value = _surfaceFrameFromRoot(_root.surfaceFrameSignal.value);
  }

  void attachSurface(Object token) {
    _root.attachSurface(token);
  }

  void installSurfaceResourceSession(
    Object token,
    SurfaceResourceSessionLifecycle session,
  ) {
    _root.installSurfaceResourceSession(token, session);
  }

  bool detachSurface(Object token) {
    return _root.detachSurface(token);
  }

  void handleSurfaceInteractiveDisabled(Object token) {
    if (!_root.isActiveSurface(token)) {
      return;
    }
    _root.handleSurfaceInteractiveDisabled();
  }

  void handlePointer(Object token, CanvasPointerInput input) {
    if (!_root.isActiveSurface(token)) {
      return;
    }
    _root.handlePointer(input);
  }

  // The surface port keeps the viewport/style/binding inputs explicit so the
  // Flutter adapter cannot smuggle frame or resource ownership through a bag.
  // ignore: number-of-parameters
  MainFramePaintOutput buildSurfaceMainFrame(
    Object token, {
    required Rect viewportWorldBounds,
    required double devicePixelRatio,
    required CanvasSelectionStyle selectionStyle,
    required CanvasGridStyle gridStyle,
    required FrameAssetBindingBuilder bindAssets,
  }) {
    if (!_root.isActiveSurface(token)) {
      throw StateError('CanvasSurface is not active for this CanvasRuntime.');
    }
    bindAssets;

    return _root.buildMainFrameWithAssetBindings(
      viewportWorldBounds: viewportWorldBounds,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: selectionStyle,
      gridStyle: gridStyle,
      bindAssets: bindAssets,
    );
  }

  // The overlay path deliberately mirrors the main frame inputs while staying
  // resource-free; grouping them would hide the surface/runtime handoff shape.
  // ignore: number-of-parameters
  OverlayFramePaintOutput buildSurfaceOverlayFrame(
    Object token, {
    required Rect viewportWorldBounds,
    required double devicePixelRatio,
    required CanvasSelectionStyle selectionStyle,
    required CanvasGridStyle gridStyle,
  }) {
    if (!_root.isActiveSurface(token)) {
      throw StateError('CanvasSurface is not active for this CanvasRuntime.');
    }

    return _root.buildResourceFreeOverlayFrame(
      viewportWorldBounds: viewportWorldBounds,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: selectionStyle,
      gridStyle: gridStyle,
    );
  }
}

CanvasRuntimeSurfaceFrame? _surfaceFrameFromRoot(
  RuntimeSurfaceFrameSignal? frame,
) {
  if (frame == null) {
    return null;
  }

  return CanvasRuntimeSurfaceFrame(
    state: frame.state,
    generation: frame.generation,
    repaintTarget: CanvasSurfaceRepaintTarget(
      mainCanvas: frame.mainCanvas,
      overlayCanvas: frame.overlayCanvas,
      reason: frame.reason,
    ),
  );
}

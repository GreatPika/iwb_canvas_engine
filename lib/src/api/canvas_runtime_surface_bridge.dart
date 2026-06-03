import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/internal/surface_resource_session_lifecycle.dart';
import '../contracts/public/canvas_pointer.dart';
import '../contracts/public/canvas_runtime.dart';
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

final class CanvasRuntimeSurfacePort {
  CanvasRuntimeSurfacePort._(this._root);

  final RuntimeRoot _root;

  ValueListenable<CanvasRuntimeState> get state => _root.state;

  ResolverMutationGuard get resolverMutationGuard => _root;

  void attachSurface(Object token) {
    _root.attachSurface(token);
  }

  void installSurfaceResourceSession(
    Object _,
    SurfaceResourceSessionLifecycle _,
  ) {}

  void detachSurface(Object token) {
    _root.detachSurface(token);
  }

  void handleSurfaceInteractiveDisabled(Object _) {}

  void handlePointer(Object _, CanvasPointerSample _) {}

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

    return _root.buildResourceFreeMainFrame(
      viewportWorldBounds: viewportWorldBounds,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: selectionStyle,
      gridStyle: gridStyle,
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

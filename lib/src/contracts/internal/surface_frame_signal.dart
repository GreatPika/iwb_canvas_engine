import '../public/canvas_runtime.dart';

final class CanvasSurfaceRepaintTarget {
  const CanvasSurfaceRepaintTarget({
    required this.mainCanvas,
    required this.overlayCanvas,
    required this.reason,
  });

  final bool mainCanvas;
  final bool overlayCanvas;
  final String reason;
}

final class CanvasRuntimeSurfaceFrame {
  const CanvasRuntimeSurfaceFrame({
    required this.state,
    required this.generation,
    required this.repaintTarget,
  });

  final CanvasRuntimeState state;
  final int generation;
  final CanvasSurfaceRepaintTarget repaintTarget;
}

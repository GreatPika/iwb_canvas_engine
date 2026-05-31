import '../runtime/runtime_root.dart';

final Expando<RuntimeRoot> _canvasRuntimeFrameRoots = Expando<RuntimeRoot>(
  'iwb_canvas_runtime_frame_roots',
);

void attachCanvasRuntimeFrameRoot(Object runtime, RuntimeRoot root) {
  _canvasRuntimeFrameRoots[runtime] = root;
}

void detachCanvasRuntimeFrameRoot(Object runtime) {
  _canvasRuntimeFrameRoots[runtime] = null;
}

RuntimeRoot? canvasRuntimeFrameRootForSurface(Object runtime) {
  return _canvasRuntimeFrameRoots[runtime];
}

import 'canvas_pointer_input.dart';
import 'pointer_input.dart';

CanvasPointerPhase canvasPointerPhaseFromPointerPhase(PointerPhase phase) {
  switch (phase) {
    case PointerPhase.down:
      return CanvasPointerPhase.down;
    case PointerPhase.move:
      return CanvasPointerPhase.move;
    case PointerPhase.up:
      return CanvasPointerPhase.up;
    case PointerPhase.cancel:
      return CanvasPointerPhase.cancel;
  }
}

PointerPhase pointerPhaseFromCanvasPointerPhase(CanvasPointerPhase phase) {
  switch (phase) {
    case CanvasPointerPhase.down:
      return PointerPhase.down;
    case CanvasPointerPhase.move:
      return PointerPhase.move;
    case CanvasPointerPhase.up:
      return PointerPhase.up;
    case CanvasPointerPhase.cancel:
      return PointerPhase.cancel;
  }
}

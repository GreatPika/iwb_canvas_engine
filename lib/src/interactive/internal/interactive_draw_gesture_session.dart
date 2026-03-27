import 'dart:ui';

class InteractiveDrawGestureSession {
  Offset? _downScene;
  bool _moved = false;

  Offset? get downScene => _downScene;
  bool get moved => _moved;

  void start(Offset scenePoint) {
    _downScene = scenePoint;
    _moved = false;
  }

  void markMoved(bool moved) {
    _moved = moved;
  }

  void clear() {
    _downScene = null;
    _moved = false;
  }
}

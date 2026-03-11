enum InteractiveGestureFamily { move, draw }

class InteractiveGestureMachine {
  int? _activePointerId;
  InteractiveGestureFamily? _activeFamily;
  double? _activeDragStartSlop;

  bool get hasActiveGesture => _activePointerId != null;
  InteractiveGestureFamily? get activeFamily => _activeFamily;
  double? get activeDragStartSlop => _activeDragStartSlop;
  bool get isActiveDrawGesture =>
      _activeFamily == InteractiveGestureFamily.draw;

  bool ownsPointer(int pointerId) => _activePointerId == pointerId;

  bool tryBegin({
    required int pointerId,
    required InteractiveGestureFamily family,
    required double dragStartSlop,
  }) {
    if (hasActiveGesture) {
      return false;
    }
    _activePointerId = pointerId;
    _activeFamily = family;
    _activeDragStartSlop = dragStartSlop;
    return true;
  }

  InteractiveGestureFamily? reset() {
    final family = _activeFamily;
    _activePointerId = null;
    _activeFamily = null;
    _activeDragStartSlop = null;
    return family;
  }
}

enum InteractiveGestureFamily { move, draw }

final class InteractiveActiveGesture {
  const InteractiveActiveGesture({
    required this.pointerId,
    required this.family,
    required this.dragStartSlop,
  });

  final int pointerId;
  final InteractiveGestureFamily family;
  final double dragStartSlop;
}

class InteractiveGestureMachine {
  InteractiveActiveGesture? _activeGesture;

  bool get hasActiveGesture => _activeGesture != null;
  InteractiveActiveGesture? get activeGesture => _activeGesture;
  InteractiveGestureFamily? get activeFamily => _activeGesture?.family;
  double? get activeDragStartSlop => _activeGesture?.dragStartSlop;
  bool get isActiveDrawGesture =>
      _activeGesture?.family == InteractiveGestureFamily.draw;

  bool ownsPointer(int pointerId) => _activeGesture?.pointerId == pointerId;

  InteractiveActiveGesture? activeGestureForPointer(int pointerId) {
    final activeGesture = _activeGesture;
    if (activeGesture == null || activeGesture.pointerId != pointerId) {
      return null;
    }
    return activeGesture;
  }

  InteractiveActiveGesture? begin({
    required int pointerId,
    required InteractiveGestureFamily family,
    required double dragStartSlop,
  }) {
    if (hasActiveGesture) {
      return null;
    }
    final activeGesture = InteractiveActiveGesture(
      pointerId: pointerId,
      family: family,
      dragStartSlop: dragStartSlop,
    );
    _activeGesture = activeGesture;
    return activeGesture;
  }

  InteractiveGestureFamily? reset() {
    final family = _activeGesture?.family;
    _activeGesture = null;
    return family;
  }
}

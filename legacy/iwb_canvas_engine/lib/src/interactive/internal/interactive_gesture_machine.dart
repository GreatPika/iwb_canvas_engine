import 'pointer_session_token.dart';

enum InteractiveGestureFamily { move, draw }

final class InteractiveActiveGesture {
  const InteractiveActiveGesture({
    required this.pointerId,
    required this.sessionToken,
    required this.family,
    required this.dragStartSlop,
  });

  final int pointerId;
  final PointerSessionToken? sessionToken;
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

  bool ownsPointer(int pointerId, {PointerSessionToken? sessionToken}) {
    final activeGesture = _activeGesture;
    return activeGesture?.pointerId == pointerId &&
        activeGesture?.sessionToken == sessionToken;
  }

  InteractiveActiveGesture? activeGestureForPointer(
    int pointerId, {
    PointerSessionToken? sessionToken,
  }) {
    final activeGesture = _activeGesture;
    if (activeGesture == null ||
        activeGesture.pointerId != pointerId ||
        activeGesture.sessionToken != sessionToken) {
      return null;
    }
    return activeGesture;
  }

  InteractiveActiveGesture? begin({
    required int pointerId,
    PointerSessionToken? sessionToken,
    required InteractiveGestureFamily family,
    required double dragStartSlop,
  }) {
    if (hasActiveGesture) {
      return null;
    }
    final activeGesture = InteractiveActiveGesture(
      pointerId: pointerId,
      sessionToken: sessionToken,
      family: family,
      dragStartSlop: dragStartSlop,
    );
    _activeGesture = activeGesture;
    return activeGesture;
  }

  InteractiveGestureFamily? interruptActiveGesture() {
    final family = _activeGesture?.family;
    _activeGesture = null;
    return family;
  }

  InteractiveGestureFamily? detachSession(PointerSessionToken token) {
    final activeGesture = _activeGesture;
    if (activeGesture == null || activeGesture.sessionToken != token) {
      return null;
    }
    return interruptActiveGesture();
  }
}

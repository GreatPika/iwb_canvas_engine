import 'dart:ui';

import 'interactive_draw_style.dart';
import 'pointer_session_token.dart';

class InteractiveDrawGestureSession {
  Offset? _downScene;
  bool _moved = false;
  InteractiveDrawStyle? _capturedStyle;
  PointerSessionToken? _sessionToken;

  Offset? get downScene => _downScene;
  bool get moved => _moved;
  InteractiveDrawStyle? get capturedStyle => _capturedStyle;
  PointerSessionToken? get sessionToken => _sessionToken;

  void start(
    Offset scenePoint, {
    required InteractiveDrawStyle capturedStyle,
    required PointerSessionToken? sessionToken,
  }) {
    _downScene = scenePoint;
    _moved = false;
    _capturedStyle = capturedStyle;
    _sessionToken = sessionToken;
  }

  void markMoved(bool moved) {
    _moved = moved;
  }

  void clear() {
    _downScene = null;
    _moved = false;
    _capturedStyle = null;
    _sessionToken = null;
  }
}

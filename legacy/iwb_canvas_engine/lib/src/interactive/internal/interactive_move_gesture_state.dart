import 'dart:ui';

import '../../core/input_sampling.dart';

enum InteractiveMoveDragTarget { none, move, marquee }

final class InteractiveMoveGestureState {
  Rect? _selectionRect;
  Offset? _pointerDownScene;
  Offset? _lastScene;
  InteractiveMoveDragTarget _target = InteractiveMoveDragTarget.none;
  bool _dragStarted = false;
  bool _pendingClearSelection = false;

  Rect? get selectionRect => _selectionRect;
  Offset? get pointerDownScene => _pointerDownScene;
  Offset? get lastScene => _lastScene;
  InteractiveMoveDragTarget get target => _target;
  bool get dragStarted => _dragStarted;
  bool get pendingClearSelection => _pendingClearSelection;

  bool setSelectionRect(Rect? value) {
    if (_selectionRect == value) {
      return false;
    }
    _selectionRect = value;
    return true;
  }

  void begin(Offset scenePoint) {
    _pointerDownScene = scenePoint;
    _lastScene = scenePoint;
    _target = InteractiveMoveDragTarget.none;
    _dragStarted = false;
    _pendingClearSelection = false;
    _selectionRect = null;
  }

  void reset() {
    _selectionRect = null;
    _pointerDownScene = null;
    _lastScene = null;
    _target = InteractiveMoveDragTarget.none;
    _dragStarted = false;
    _pendingClearSelection = false;
  }

  void setTarget(InteractiveMoveDragTarget value) {
    _target = value;
  }

  void setPendingClearSelection(bool value) {
    _pendingClearSelection = value;
  }

  bool tryStartDrag(Offset scenePoint, {required double dragStartSlop}) {
    final pointerDownScene = _pointerDownScene;
    if (_dragStarted || pointerDownScene == null) {
      return _dragStarted;
    }
    if (!isDistanceGreaterThan(pointerDownScene, scenePoint, dragStartSlop)) {
      return false;
    }
    _dragStarted = true;
    return true;
  }

  void setLastScene(Offset scenePoint) {
    _lastScene = scenePoint;
  }
}

import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contract/canvas_pointer_input.dart';
import '../contract/pointer_input.dart';
import '../contract/snapshot.dart';
import '../core/interaction_types.dart';
import 'internal/scene_controller_interaction_access.dart';
import 'internal/scene_controller_interaction_config.dart';
import 'internal/scene_controller_interaction_runtime.dart';

typedef MoveCommitDeltaResolver =
    Offset Function({
      required SceneSnapshot snapshot,
      required List<NodeSnapshot> movedNodes,
      required Offset proposedDelta,
    });

class SceneControllerInteraction implements Listenable {
  SceneControllerInteraction(this._access);

  final SceneControllerInteractionAccess _access;

  @override
  void addListener(VoidCallback listener) {
    _access.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _access.removeListener(listener);
  }

  Rect? get selectionRect => _access.runtime.selectionRect;
  Offset? get pendingLineStart => _access.runtime.pendingLineStart;
  int? get pendingLineTimestampMs => _access.runtime.pendingLineTimestampMs;
  bool get hasPendingLineStart => _access.runtime.hasPendingLineStart;
  bool get hasActiveStrokePreview =>
      _access.runtime.isActiveDrawGesture &&
      (_access.config.drawTool == DrawTool.pen ||
          _access.config.drawTool == DrawTool.highlighter) &&
      _access.runtime.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      _access.runtime.activeStrokePreviewPoints;
  double get activeStrokePreviewThickness =>
      _access.config.drawTool == DrawTool.highlighter
      ? _access.config.highlighterThickness
      : _access.config.penThickness;
  Color get activeStrokePreviewColor => _access.config.drawColor;
  double get activeStrokePreviewOpacity =>
      _access.config.drawTool == DrawTool.highlighter
      ? _access.config.highlighterOpacity
      : 1;
  bool get hasActiveLinePreview =>
      _access.runtime.isActiveDrawGesture &&
      _access.config.drawTool == DrawTool.line &&
      _access.runtime.activeLinePreviewStart != null &&
      _access.runtime.activeLinePreviewEnd != null;
  Offset? get activeLinePreviewStart => _access.runtime.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _access.runtime.activeLinePreviewEnd;
  double get activeLinePreviewThickness => _access.config.lineThickness;
  Color get activeLinePreviewColor => _access.config.drawColor;
  CanvasMode get mode => _access.config.mode;
  DrawTool get drawTool => _access.config.drawTool;
  Color get drawColor => _access.config.drawColor;
  double get penThickness => _access.config.penThickness;
  double get highlighterThickness => _access.config.highlighterThickness;
  double get lineThickness => _access.config.lineThickness;
  double get eraserThickness => _access.config.eraserThickness;
  double get highlighterOpacity => _access.config.highlighterOpacity;
  double get dragStartSlop => _access.config.dragStartSlop();
  PointerInputSettings get pointerSettings => _access.config.pointerSettings;

  void handlePointer(CanvasPointerInput input) {
    _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
    _access.runtime.handlePointer(input);
  }

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    _access.runtime.ensurePublicSideEffectAllowed('handleDoubleTap');
    _access.runtime.handleDoubleTap(
      position: position,
      timestampMs: timestampMs,
    );
  }

  void setMode(CanvasMode value) {
    _access.runtime.ensurePublicSideEffectAllowed('setMode');
    if (mode == value) return;

    _access.runtime.resetInteractiveState();
    _access.config.mode = value;

    if (value == CanvasMode.draw &&
        _access.clearSelectionOnDrawModeEnter &&
        _access.hasSelection) {
      _access.clearSelectionState();
    }

    _access.runtime.scheduleNotify();
  }

  void setDrawTool(DrawTool value) {
    _access.runtime.ensurePublicSideEffectAllowed('setDrawTool');
    if (drawTool == value) return;
    _access.runtime.resetInteractiveState();
    _access.config.drawTool = value;
    _access.runtime.scheduleNotify();
  }

  void setDrawColor(Color value) {
    _access.runtime.ensurePublicSideEffectAllowed('setDrawColor');
    if (drawColor == value) return;
    _access.config.drawColor = value;
    _access.runtime.scheduleNotify();
  }

  set penThickness(double value) {
    _access.runtime.ensurePublicSideEffectAllowed('penThickness');
    _access.config.penThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'penThickness',
        );
    _access.runtime.scheduleNotify();
  }

  set highlighterThickness(double value) {
    _access.runtime.ensurePublicSideEffectAllowed('highlighterThickness');
    _access.config.highlighterThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'highlighterThickness',
        );
    _access.runtime.scheduleNotify();
  }

  set lineThickness(double value) {
    _access.runtime.ensurePublicSideEffectAllowed('lineThickness');
    _access.config.lineThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'lineThickness',
        );
    _access.runtime.scheduleNotify();
  }

  set eraserThickness(double value) {
    _access.runtime.ensurePublicSideEffectAllowed('eraserThickness');
    _access.config.eraserThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'eraserThickness',
        );
    _access.runtime.scheduleNotify();
  }

  set highlighterOpacity(double value) {
    _access.runtime.ensurePublicSideEffectAllowed('highlighterOpacity');
    _access.config.highlighterOpacity =
        SceneControllerInteractionConfig.requireFiniteInUnitInterval(
          value,
          name: 'highlighterOpacity',
        );
    _access.runtime.scheduleNotify();
  }

  void setPointerSettings(PointerInputSettings value) {
    _access.runtime.ensurePublicSideEffectAllowed('setPointerSettings');
    validatePointerInputSettings(value);
    _access.config.pointerSettings = value;
    _access.runtime.scheduleNotify();
  }

  void setDragStartSlop(double? value) {
    _access.runtime.ensurePublicSideEffectAllowed('setDragStartSlop');
    final resolved = value == null
        ? null
        : SceneControllerInteractionConfig.requireFiniteNonNegative(
            value,
            name: 'dragStartSlop',
          );
    if (_access.config.dragStartSlopOverride == resolved) return;
    _access.config.dragStartSlopOverride = resolved;
    _access.runtime.scheduleNotify();
  }
}

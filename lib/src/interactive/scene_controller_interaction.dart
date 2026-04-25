import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contract/canvas_pointer_input.dart';
import '../contract/pointer_input.dart';
import '../contract/snapshot.dart';
import '../core/immutable_collections.dart';
import '../core/interaction_types.dart';
import 'internal/interactive_draw_style.dart';
import 'internal/scene_controller_interaction_config.dart';
import 'internal/scene_controller_interaction_runtime.dart';

@immutable
final class MoveCommitDeltaRequest {
  factory MoveCommitDeltaRequest({
    required SceneSnapshot snapshot,
    required Iterable<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  }) {
    return MoveCommitDeltaRequest._(
      snapshot: snapshot,
      movedNodes: freezeList<NodeSnapshot>(movedNodes),
      proposedDelta: proposedDelta,
    );
  }

  const MoveCommitDeltaRequest._({
    required this.snapshot,
    required List<NodeSnapshot> movedNodes,
    required this.proposedDelta,
  }) : _movedNodes = movedNodes;

  final SceneSnapshot snapshot;
  final List<NodeSnapshot> _movedNodes;
  final Offset proposedDelta;

  Iterable<NodeSnapshot> get movedNodes => _movedNodes;
}

typedef MoveCommitDeltaResolver =
    Offset Function(MoveCommitDeltaRequest request);

abstract interface class SceneControllerInteraction implements Listenable {
  Rect? get selectionRect;
  Offset? get pendingLineStart;
  int? get pendingLineTimestampMs;
  bool get hasPendingLineStart;
  Color? get pendingLineColor;
  double? get pendingLineThickness;
  bool get hasActiveStrokePreview;
  List<Offset> get activeStrokePreviewPoints;
  double get activeStrokePreviewThickness;
  Color get activeStrokePreviewColor;
  double get activeStrokePreviewOpacity;
  bool get hasActiveLinePreview;
  Offset? get activeLinePreviewStart;
  Offset? get activeLinePreviewEnd;
  double get activeLinePreviewThickness;
  Color get activeLinePreviewColor;
  CanvasMode get mode;
  DrawTool get drawTool;
  Color get drawColor;
  double get penThickness;
  double get highlighterThickness;
  double get lineThickness;
  double get eraserThickness;
  double get highlighterOpacity;
  double get dragStartSlop;
  PointerInputSettings get pointerSettings;

  void handlePointer(CanvasPointerInput input);
  void handleDoubleTap({required Offset position, int? timestampMs});
  void setMode(CanvasMode value);
  void setDrawTool(DrawTool value);
  void setDrawColor(Color value);
  set penThickness(double value);
  set highlighterThickness(double value);
  set lineThickness(double value);
  set eraserThickness(double value);
  set highlighterOpacity(double value);
  void setPointerSettings(PointerInputSettings value);
  void setDragStartSlop(double? value);
}

class SceneControllerInteractionOwner implements SceneControllerInteraction {
  SceneControllerInteractionOwner({
    required Listenable ownerListenable,
    required SceneControllerInteractionConfig config,
    required SceneControllerInteractionRuntime runtime,
    required bool clearSelectionOnDrawModeEnter,
    required bool Function() hasSelection,
    required VoidCallback clearSelectionState,
  }) : _ownerListenable = ownerListenable,
       _config = config,
       _runtime = runtime,
       _clearSelectionOnDrawModeEnter = clearSelectionOnDrawModeEnter,
       _hasSelection = hasSelection,
       _clearSelectionState = clearSelectionState;

  final Listenable _ownerListenable;
  final SceneControllerInteractionConfig _config;
  final SceneControllerInteractionRuntime _runtime;
  final bool _clearSelectionOnDrawModeEnter;
  final bool Function() _hasSelection;
  final VoidCallback _clearSelectionState;

  @override
  void addListener(VoidCallback listener) {
    _ownerListenable.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _ownerListenable.removeListener(listener);
  }

  @override
  Rect? get selectionRect => _runtime.selectionRect;
  @override
  Offset? get pendingLineStart => _runtime.pendingLineStart;
  @override
  int? get pendingLineTimestampMs => _runtime.pendingLineTimestampMs;
  @override
  bool get hasPendingLineStart => _runtime.hasPendingLineStart;
  @override
  Color? get pendingLineColor => _runtime.pendingLineStyle?.drawColor;
  @override
  double? get pendingLineThickness => _runtime.pendingLineStyle?.lineThickness;
  InteractiveDrawStyle? get _activeDrawStyle => _runtime.activeDrawStyle;
  @override
  bool get hasActiveStrokePreview =>
      _runtime.isActiveDrawGesture &&
      ((_activeDrawStyle?.drawTool == DrawTool.pen) ||
          (_activeDrawStyle?.drawTool == DrawTool.highlighter)) &&
      _runtime.hasActiveStrokePoints;
  @override
  List<Offset> get activeStrokePreviewPoints =>
      _runtime.activeStrokePreviewPoints;
  @override
  double get activeStrokePreviewThickness =>
      (_activeDrawStyle?.drawTool ?? _config.drawTool) == DrawTool.highlighter
      ? _activeDrawStyle?.highlighterThickness ?? _config.highlighterThickness
      : _activeDrawStyle?.penThickness ?? _config.penThickness;
  @override
  Color get activeStrokePreviewColor =>
      _activeDrawStyle?.drawColor ?? _config.drawColor;
  @override
  double get activeStrokePreviewOpacity =>
      (_activeDrawStyle?.drawTool ?? _config.drawTool) == DrawTool.highlighter
      ? _activeDrawStyle?.highlighterOpacity ?? _config.highlighterOpacity
      : 1;
  @override
  bool get hasActiveLinePreview =>
      _runtime.isActiveDrawGesture &&
      _activeDrawStyle?.drawTool == DrawTool.line &&
      _runtime.activeLinePreviewStart != null &&
      _runtime.activeLinePreviewEnd != null;
  @override
  Offset? get activeLinePreviewStart => _runtime.activeLinePreviewStart;
  @override
  Offset? get activeLinePreviewEnd => _runtime.activeLinePreviewEnd;
  @override
  double get activeLinePreviewThickness =>
      _activeDrawStyle?.lineThickness ?? _config.lineThickness;
  @override
  Color get activeLinePreviewColor =>
      _activeDrawStyle?.drawColor ?? _config.drawColor;
  @override
  CanvasMode get mode => _config.mode;
  @override
  DrawTool get drawTool => _config.drawTool;
  @override
  Color get drawColor => _config.drawColor;
  @override
  double get penThickness => _config.penThickness;
  @override
  double get highlighterThickness => _config.highlighterThickness;
  @override
  double get lineThickness => _config.lineThickness;
  @override
  double get eraserThickness => _config.eraserThickness;
  @override
  double get highlighterOpacity => _config.highlighterOpacity;
  @override
  double get dragStartSlop => _config.dragStartSlop();
  @override
  PointerInputSettings get pointerSettings => _config.pointerSettings;

  @override
  void handlePointer(CanvasPointerInput input) {
    _runtime.ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePublicPointer(input);
  }

  @override
  void handleDoubleTap({required Offset position, int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handlePublicDoubleTap(
      position: position,
      timestampMs: timestampMs,
    );
  }

  @override
  void setMode(CanvasMode value) {
    _runtime.ensurePublicSideEffectAllowed('setMode');
    if (mode == value) return;

    _runtime.interruptForInteractionConfigChange();
    _config.mode = value;

    if (value == CanvasMode.draw &&
        _clearSelectionOnDrawModeEnter &&
        _hasSelection()) {
      _clearSelectionState();
    }

    _runtime.scheduleNotify();
  }

  @override
  void setDrawTool(DrawTool value) {
    _runtime.ensurePublicSideEffectAllowed('setDrawTool');
    if (drawTool == value) return;
    _runtime.interruptForInteractionConfigChange();
    _config.drawTool = value;
    _runtime.scheduleNotify();
  }

  @override
  void setDrawColor(Color value) {
    _runtime.ensurePublicSideEffectAllowed('setDrawColor');
    if (drawColor == value) return;
    _config.drawColor = value;
    _runtime.scheduleNotify();
  }

  @override
  set penThickness(double value) {
    _runtime.ensurePublicSideEffectAllowed('penThickness');
    _config.penThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'penThickness',
        );
    _runtime.scheduleNotify();
  }

  @override
  set highlighterThickness(double value) {
    _runtime.ensurePublicSideEffectAllowed('highlighterThickness');
    _config.highlighterThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'highlighterThickness',
        );
    _runtime.scheduleNotify();
  }

  @override
  set lineThickness(double value) {
    _runtime.ensurePublicSideEffectAllowed('lineThickness');
    _config.lineThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'lineThickness',
        );
    _runtime.scheduleNotify();
  }

  @override
  set eraserThickness(double value) {
    _runtime.ensurePublicSideEffectAllowed('eraserThickness');
    _config.eraserThickness =
        SceneControllerInteractionConfig.requireFinitePositive(
          value,
          name: 'eraserThickness',
        );
    _runtime.scheduleNotify();
  }

  @override
  set highlighterOpacity(double value) {
    _runtime.ensurePublicSideEffectAllowed('highlighterOpacity');
    _config.highlighterOpacity =
        SceneControllerInteractionConfig.requireFiniteInUnitInterval(
          value,
          name: 'highlighterOpacity',
        );
    _runtime.scheduleNotify();
  }

  @override
  void setPointerSettings(PointerInputSettings value) {
    _runtime.ensurePublicSideEffectAllowed('setPointerSettings');
    validatePointerInputSettings(value);
    _config.pointerSettings = value;
    _runtime.scheduleNotify();
  }

  @override
  void setDragStartSlop(double? value) {
    _runtime.ensurePublicSideEffectAllowed('setDragStartSlop');
    final resolved = value == null
        ? null
        : SceneControllerInteractionConfig.requireFiniteNonNegative(
            value,
            name: 'dragStartSlop',
          );
    if (_config.dragStartSlopOverride == resolved) return;
    _config.dragStartSlopOverride = resolved;
    _runtime.scheduleNotify();
  }
}

import 'dart:ui' show Offset;

import '../../../core/scene.dart';
import '../../internal/contracts.dart';
import '../../pointer_input.dart';
import '../../types.dart';
import 'tools/eraser_tool.dart';
import 'tools/line_tool.dart';
import 'tools/stroke_tool.dart';

class DrawModeEngine {
  DrawModeEngine(this._contracts)
    : _strokeTool = StrokeTool(
        _contracts,
        ensureAnnotationLayer: () => _ensureAnnotationLayer(_contracts.scene),
      ),
      _lineTool = LineTool(
        _contracts,
        ensureAnnotationLayer: () => _ensureAnnotationLayer(_contracts.scene),
      ),
      _eraserTool = EraserTool(_contracts);

  final InputSliceContracts _contracts;
  final StrokeTool _strokeTool;
  final LineTool _lineTool;
  final EraserTool _eraserTool;

  int? _activePointerId;
  Offset? _pointerDownScene;
  Offset? _lastScenePoint;

  Offset? get pendingLineStart => _lineTool.pendingLineStart;
  int? get pendingLineTimestampMs => _lineTool.pendingLineTimestampMs;
  bool get hasPendingLineStart => _lineTool.hasPendingLineStart;
  bool get hasActivePointer => _activePointerId != null;

  void handlePointer(PointerSample sample) {
    if (_activePointerId != null && _activePointerId != sample.pointerId) {
      return;
    }

    _lineTool.expirePendingLine(sample.timestampMs);
    final scenePoint = _contracts.toScenePoint(sample.position);

    switch (sample.phase) {
      case PointerPhase.down:
        _handleDown(sample, scenePoint);
        break;
      case PointerPhase.move:
        _handleMove(sample, scenePoint);
        break;
      case PointerPhase.up:
        _handleUp(sample, scenePoint);
        break;
      case PointerPhase.cancel:
        _handleCancel();
        break;
    }
  }

  void reset() {
    _strokeTool.reset();
    _lineTool.reset();
    _eraserTool.reset();
    _resetPointer();
  }

  void _handleDown(PointerSample sample, Offset scenePoint) {
    _activePointerId = sample.pointerId;
    _pointerDownScene = scenePoint;
    _lastScenePoint = scenePoint;

    switch (_contracts.drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeTool.handleDown(scenePoint);
        break;
      case DrawTool.line:
        _lineTool.handleDown(scenePoint);
        break;
      case DrawTool.eraser:
        _eraserTool.handleDown(scenePoint);
        break;
    }
  }

  void _handleMove(PointerSample sample, Offset scenePoint) {
    if (_activePointerId != sample.pointerId) return;
    if (_pointerDownScene == null || _lastScenePoint == null) return;

    switch (_contracts.drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeTool.handleMove(scenePoint);
        break;
      case DrawTool.line:
        _lineTool.handleMove(scenePoint);
        break;
      case DrawTool.eraser:
        _eraserTool.handleMove(scenePoint);
        break;
    }

    _lastScenePoint = scenePoint;
  }

  void _handleUp(PointerSample sample, Offset scenePoint) {
    if (_activePointerId != sample.pointerId) return;

    switch (_contracts.drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeTool.handleUp(sample.timestampMs, scenePoint);
        break;
      case DrawTool.line:
        _lineTool.handleUp(sample.timestampMs, scenePoint);
        break;
      case DrawTool.eraser:
        _eraserTool.handleUp(sample.timestampMs, scenePoint);
        break;
    }

    _resetPointer();
    _contracts.notifyNowIfNeeded();
  }

  void _handleCancel() {
    reset();
    _contracts.notifyNowIfNeeded();
  }

  void _resetPointer() {
    _activePointerId = null;
    _pointerDownScene = null;
    _lastScenePoint = null;
  }

  static Layer _ensureAnnotationLayer(Scene scene) {
    for (var i = scene.layers.length - 1; i >= 0; i--) {
      final layer = scene.layers[i];
      if (!layer.isBackground) {
        return layer;
      }
    }
    final layer = Layer();
    scene.layers.add(layer);
    return layer;
  }
}

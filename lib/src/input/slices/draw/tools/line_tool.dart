import 'dart:async';
import 'dart:ui' show Offset;

import '../../../../core/nodes.dart';
import '../../../../core/scene.dart';
import '../../../action_events.dart';
import '../../../internal/contracts.dart';

class LineTool {
  LineTool(this._contracts, {required Layer Function() ensureAnnotationLayer})
    : _ensureAnnotationLayer = ensureAnnotationLayer;

  static const Duration _pendingLineTimeout = Duration(seconds: 10);

  final InputSliceContracts _contracts;
  final Layer Function() _ensureAnnotationLayer;

  LineNode? _activeLine;
  Layer? _activeDrawLayer;

  Offset? _drawDownScene;
  bool _drawMoved = false;

  Offset? _pendingLineStart;
  int? _pendingLineTimestampMs;
  Timer? _pendingLineTimer;

  Offset? get pendingLineStart => _pendingLineStart;
  int? get pendingLineTimestampMs => _pendingLineTimestampMs;
  bool get hasPendingLineStart => _pendingLineStart != null;

  void handleDown(Offset scenePoint) {
    _activeLine = null;
    _drawMoved = false;
    _drawDownScene = scenePoint;
  }

  void handleMove(Offset scenePoint) {
    if (_drawDownScene == null) return;
    final totalDelta = scenePoint - _drawDownScene!;
    final dragStartSlop = _contracts.dragStartSlop;
    final dragStartSlopSquared = dragStartSlop * dragStartSlop;
    final totalDeltaSquared =
        totalDelta.dx * totalDelta.dx + totalDelta.dy * totalDelta.dy;
    if (!_drawMoved && totalDeltaSquared <= dragStartSlopSquared) {
      return;
    }

    if (_pendingLineStart != null) {
      _clearPendingLine();
    }

    _drawMoved = true;

    if (_activeLine == null) {
      final drawColor = _contracts.drawColor;
      final line = LineNode(
        id: _contracts.newNodeId(),
        start: _drawDownScene!,
        end: scenePoint,
        thickness: _contracts.lineThickness,
        color: drawColor,
      );
      _activeLine = line;
      _activeDrawLayer = _ensureAnnotationLayer();
      _activeDrawLayer!.nodes.add(line);
      _contracts.registerNodeId(line.id);
      _contracts.markSceneStructuralChanged();
    } else {
      _activeLine!.end = scenePoint;
    }
    _contracts.requestRepaintOncePerFrame();
  }

  void handleUp(int timestampMs, Offset scenePoint) {
    if (_activeLine != null) {
      final line = _activeLine!;
      if (line.end != scenePoint) {
        line.end = scenePoint;
      }
      try {
        line.normalizeToLocalCenter();
      } catch (_) {
        _abortActiveLineCommit();
        return;
      }
      _contracts.markSceneGeometryChanged();
      _activeLine = null;
      _activeDrawLayer = null;
      final drawTool = _contracts.drawTool;
      final drawColor = _contracts.drawColor;
      _contracts.emitAction(
        ActionType.drawLine,
        [line.id],
        timestampMs,
        payload: <String, Object?>{
          'tool': drawTool.name,
          'color': drawColor.toARGB32(),
          'thickness': line.thickness,
        },
      );
      _drawDownScene = null;
      _drawMoved = false;
      return;
    }

    if (_drawDownScene == null) return;

    final delta = scenePoint - _drawDownScene!;
    final deltaSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    final dragStartSlop = _contracts.dragStartSlop;
    final isTap = deltaSquared <= dragStartSlop * dragStartSlop;
    _drawDownScene = null;
    _drawMoved = false;
    if (!isTap) return;

    if (_pendingLineStart == null) {
      _setPendingLineStart(scenePoint, timestampMs);
      return;
    }

    final start = _pendingLineStart!;
    final line = LineNode.fromWorldSegment(
      id: _contracts.newNodeId(),
      start: start,
      end: scenePoint,
      thickness: _contracts.lineThickness,
      color: _contracts.drawColor,
    );
    _setPendingLineStart(null, null);
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(line);
    _contracts.registerNodeId(line.id);
    _activeDrawLayer = null;
    _contracts.markSceneStructuralChanged();
    final drawTool = _contracts.drawTool;
    final drawColor = _contracts.drawColor;
    _contracts.emitAction(
      ActionType.drawLine,
      [line.id],
      timestampMs,
      payload: <String, Object?>{
        'tool': drawTool.name,
        'color': drawColor.toARGB32(),
        'thickness': line.thickness,
      },
    );
  }

  void reset() {
    if (_activeLine != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeLine);
      _contracts.unregisterNodeId(_activeLine!.id);
      _contracts.markSceneStructuralChanged();
    }
    _activeLine = null;
    _activeDrawLayer = null;
    _drawDownScene = null;
    _drawMoved = false;
    _clearPendingLine();
  }

  void _setPendingLineStart(Offset? start, int? timestampMs) {
    if (_pendingLineStart == start && _pendingLineTimestampMs == timestampMs) {
      return;
    }
    _pendingLineTimer?.cancel();
    _pendingLineTimer = null;
    _pendingLineStart = start;
    _pendingLineTimestampMs = timestampMs;
    if (_pendingLineStart != null) {
      _pendingLineTimer = Timer(_pendingLineTimeout, _clearPendingLine);
    }
    _contracts.requestRepaintOncePerFrame();
  }

  void _clearPendingLine() {
    _setPendingLineStart(null, null);
  }

  void _abortActiveLineCommit() {
    if (_activeLine != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeLine);
      _contracts.unregisterNodeId(_activeLine!.id);
      _contracts.markSceneStructuralChanged();
    }
    _activeLine = null;
    _activeDrawLayer = null;
    _drawDownScene = null;
    _drawMoved = false;
  }
}

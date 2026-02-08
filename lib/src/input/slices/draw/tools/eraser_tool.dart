import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../../../core/geometry.dart';
import '../../../../core/nodes.dart';
import '../../../action_events.dart';
import '../../../internal/contracts.dart';

class EraserTool {
  EraserTool(this._contracts);

  final InputSliceContracts _contracts;
  final List<Offset> _eraserPoints = <Offset>[];

  void handleDown(Offset scenePoint) {
    _eraserPoints
      ..clear()
      ..add(scenePoint);
  }

  void handleMove(Offset scenePoint) {
    _eraserPoints.add(scenePoint);
    _contracts.requestRepaintOncePerFrame();
  }

  /// Commits erasing only on pointer up.
  ///
  /// During move, eraser keeps trajectory for visual feedback but does not
  /// mutate scene structure yet. This keeps cancel/mode-switch paths
  /// transactional (no partial deletions left behind).
  void handleUp(int timestampMs, Offset scenePoint) {
    if (_eraserPoints.isNotEmpty &&
        (_eraserPoints.last - scenePoint).distance > 0) {
      _eraserPoints.add(scenePoint);
    }

    final deletedNodeIds = _eraseAnnotations(_eraserPoints);
    _eraserPoints.clear();
    if (deletedNodeIds.isEmpty) {
      return;
    }
    final deletedIdSet = deletedNodeIds.toSet();
    _contracts.setSelection(
      _contracts.selectedNodeIds.where((id) => !deletedIdSet.contains(id)),
      notify: false,
    );
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.erase,
      deletedNodeIds,
      timestampMs,
      payload: <String, Object?>{'eraserThickness': _contracts.eraserThickness},
    );
  }

  void reset() {
    _eraserPoints.clear();
  }

  static double _maxSingularValue2x2(double a, double b, double c, double d) {
    final t = a * a + b * b + c * c + d * d;
    final det = a * d - b * c;
    final discSquared = t * t - 4 * det * det;
    final disc = math.sqrt(math.max(0, discSquared));
    final lambdaMax = (t + disc) / 2;
    return math.sqrt(math.max(0, lambdaMax));
  }

  List<NodeId> _eraseAnnotations(List<Offset> eraserPoints) {
    final deleted = <NodeId>[];
    if (eraserPoints.isEmpty) return deleted;

    for (final layer in _contracts.scene.layers) {
      if (layer.isBackground) continue;
      layer.nodes.removeWhere((node) {
        if (node is! StrokeNode && node is! LineNode) return false;
        if (!node.isDeletable) return false;
        final hit = _eraserHitsNode(eraserPoints, node);
        if (hit) {
          deleted.add(node.id);
        }
        return hit;
      });
    }
    return deleted;
  }

  bool _eraserHitsNode(List<Offset> eraserPoints, SceneNode node) {
    if (node is LineNode) {
      return _eraserHitsLine(eraserPoints, node);
    }
    if (node is StrokeNode) {
      return _eraserHitsStroke(eraserPoints, node);
    }
    return false;
  }

  bool _eraserHitsLine(List<Offset> eraserPoints, LineNode line) {
    final inverse = line.transform.invert();
    if (inverse == null) return false;
    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = _maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold =
        line.thickness / 2 + (_contracts.eraserThickness / 2) * sigmaMax;
    if (localEraserPoints.length == 1) {
      final distance = distancePointToSegment(
        localEraserPoints.first,
        line.start,
        line.end,
      );
      return distance <= threshold;
    }
    for (var i = 0; i < localEraserPoints.length - 1; i++) {
      final a = localEraserPoints[i];
      final b = localEraserPoints[i + 1];
      final distance = distanceSegmentToSegment(a, b, line.start, line.end);
      if (distance <= threshold) {
        return true;
      }
    }
    return false;
  }

  bool _eraserHitsStroke(List<Offset> eraserPoints, StrokeNode stroke) {
    final inverse = stroke.transform.invert();
    if (inverse == null) return false;
    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = _maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold =
        stroke.thickness / 2 + (_contracts.eraserThickness / 2) * sigmaMax;
    if (stroke.points.isEmpty) return false;
    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      for (final eraserPoint in localEraserPoints) {
        if ((eraserPoint - point).distance <= threshold) {
          return true;
        }
      }
      return false;
    }

    if (localEraserPoints.length == 1) {
      final eraserPoint = localEraserPoints.first;
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final a = stroke.points[i];
        final b = stroke.points[i + 1];
        final distance = distancePointToSegment(eraserPoint, a, b);
        if (distance <= threshold) {
          return true;
        }
      }
      return false;
    }

    for (var i = 0; i < localEraserPoints.length - 1; i++) {
      final eraserA = localEraserPoints[i];
      final eraserB = localEraserPoints[i + 1];
      for (var j = 0; j < stroke.points.length - 1; j++) {
        final strokeA = stroke.points[j];
        final strokeB = stroke.points[j + 1];
        final distance = distanceSegmentToSegment(
          eraserA,
          eraserB,
          strokeA,
          strokeB,
        );
        if (distance <= threshold) {
          return true;
        }
      }
    }
    return false;
  }
}

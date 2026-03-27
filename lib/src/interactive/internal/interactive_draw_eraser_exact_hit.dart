import 'dart:ui';

import '../../core/geometry.dart';
import '../../core/nodes.dart' show LineNode, SceneNode, StrokeNode;
import '../../contract/transform2d.dart';
import 'interactive_draw_eraser_line_hit.dart';
import 'interactive_draw_eraser_projection.dart';
import 'interactive_draw_eraser_stroke_hit.dart';
import 'interactive_geometry.dart';

class InteractiveDrawEraserExactHitCallbacks {
  const InteractiveDrawEraserExactHitCallbacks({
    required this.onPreciseSegmentCheck,
  });

  final void Function() onPreciseSegmentCheck;
}

class InteractiveDrawEraserExactHit {
  InteractiveDrawEraserExactHit({required this.callbacks})
    : _lineHit = InteractiveDrawEraserLineHit(
        onPreciseSegmentCheck: callbacks.onPreciseSegmentCheck,
      ),
      _strokeHit = InteractiveDrawEraserStrokeHit(
        onPreciseSegmentCheck: callbacks.onPreciseSegmentCheck,
      );

  final InteractiveDrawEraserExactHitCallbacks callbacks;
  final InteractiveDrawEraserLineHit _lineHit;
  final InteractiveDrawEraserStrokeHit _strokeHit;

  bool hitsNode(
    List<Offset> eraserPoints,
    SceneNode node, {
    required double eraserThickness,
  }) {
    if (node is LineNode) {
      return _hitsLine(eraserPoints, node, eraserThickness: eraserThickness);
    }
    if (node is StrokeNode) {
      return _hitsStroke(eraserPoints, node, eraserThickness: eraserThickness);
    }
    return false;
  }

  bool _hitsLine(
    List<Offset> eraserPoints,
    LineNode line, {
    required double eraserThickness,
  }) {
    final projected = _projectEraserToLocal(
      eraserPoints,
      transform: line.transform,
      nodeThickness: line.thickness,
      eraserThickness: eraserThickness,
    );
    if (projected == null) {
      return _fallbackWorldBoundsHit(
        eraserPoints,
        boundsWorld: line.boundsWorld,
        eraserThickness: eraserThickness,
      );
    }
    return _lineHit.hitsProjectedLine(projected, line);
  }

  bool _hitsStroke(
    List<Offset> eraserPoints,
    StrokeNode stroke, {
    required double eraserThickness,
  }) {
    final projected = _projectEraserToLocal(
      eraserPoints,
      transform: stroke.transform,
      nodeThickness: stroke.thickness,
      eraserThickness: eraserThickness,
    );
    if (projected == null) {
      return _fallbackWorldBoundsHit(
        eraserPoints,
        boundsWorld: stroke.boundsWorld,
        eraserThickness: eraserThickness,
      );
    }
    return _strokeHit.hitsProjectedStroke(projected, stroke);
  }

  InteractiveDrawProjectedEraser? _projectEraserToLocal(
    List<Offset> eraserPoints, {
    required Transform2D transform,
    required double nodeThickness,
    required double eraserThickness,
  }) {
    final inverse = transform.invert();
    if (inverse == null) return null;

    final points = eraserPoints
        .map<Offset>(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold = nodeThickness / 2 + (eraserThickness / 2) * sigmaMax;
    return (
      points: points,
      threshold: threshold,
      thresholdSquared: threshold * threshold,
    );
  }

  bool _fallbackWorldBoundsHit(
    List<Offset> eraserPoints, {
    required Rect boundsWorld,
    required double eraserThickness,
  }) {
    return rectsCanBeWithinDistance(
      _eraserBoundsInWorld(eraserPoints),
      boundsWorld,
      eraserThickness / 2,
    );
  }

  Rect _eraserBoundsInWorld(List<Offset> eraserPoints) {
    if (eraserPoints.length == 1) {
      return Rect.fromPoints(eraserPoints.first, eraserPoints.first);
    }
    return segmentRangeBounds(
      eraserPoints,
      segmentStart: 0,
      segmentEndExclusive: eraserPoints.length - 1,
    );
  }
}

import 'dart:ui';

import 'geometry.dart';
import 'nodes.dart';

bool hitTestRect(Offset point, Rect rect) {
  return rect.contains(point);
}

bool hitTestLine(Offset point, Offset start, Offset end, double thickness) {
  final distance = distancePointToSegment(point, start, end);
  return distance <= thickness / 2;
}

bool hitTestStroke(Offset point, List<Offset> points, double thickness) {
  if (points.length < 2) return false;
  for (var i = 0; i < points.length - 1; i++) {
    if (hitTestLine(point, points[i], points[i + 1], thickness)) {
      return true;
    }
  }
  return false;
}

bool hitTestNode(Offset point, SceneNode node) {
  if (!node.isVisible || !node.isSelectable) return false;

  switch (node.type) {
    case NodeType.image:
    case NodeType.text:
    case NodeType.rect:
      return hitTestRect(point, node.aabb);
    case NodeType.line:
      final line = node as LineNode;
      return hitTestLine(point, line.start, line.end, line.thickness);
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      return hitTestStroke(point, stroke.points, stroke.thickness);
  }
}

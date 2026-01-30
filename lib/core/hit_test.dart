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
    case NodeType.path:
      final pathNode = node as PathNode;
      final localPath = pathNode.buildLocalPath();
      if (localPath == null) return false;
      final localPoint = _toLocalPathPoint(point, pathNode);
      return localPath.contains(localPoint);
    case NodeType.line:
      final line = node as LineNode;
      return hitTestLine(point, line.start, line.end, line.thickness);
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      return hitTestStroke(point, stroke.points, stroke.thickness);
  }
}

Offset _toLocalPathPoint(Offset point, PathNode node) {
  var local = point - node.position;
  if (node.rotationDeg != 0) {
    local = rotatePoint(local, Offset.zero, -node.rotationDeg);
  }
  if (node.scaleX != 1 || node.scaleY != 1) {
    final scaleX = node.scaleX == 0 ? 1 : node.scaleX;
    final scaleY = node.scaleY == 0 ? 1 : node.scaleY;
    local = Offset(local.dx / scaleX, local.dy / scaleY);
  }
  return local;
}

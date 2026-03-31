import 'dart:ui';

import '../core/nodes.dart' show SceneNode;
import '../contract/snapshot.dart';
import '../core/geometry.dart';
import '../core/local_bounds_policy.dart';
import '../core/text_layout.dart';

/// Pure interactive preflight policy for runtime snapshot-based admissibility.
bool canSelect(NodeSnapshot node) {
  return _canSelectFlags(
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
  );
}

/// Pure interactive preflight policy for transform eligibility.
bool canTransform(NodeSnapshot node) {
  return _canTransformFlags(
    isTransformable: node.isTransformable,
    isLocked: node.isLocked,
  );
}

/// Pure interactive preflight policy for move-preview eligibility.
bool canPreviewMove(NodeSnapshot node) {
  return canSelect(node) && canTransform(node);
}

/// Pure interactive preflight policy for move-commit eligibility.
bool canCommitMove(NodeSnapshot node) {
  return canPreviewMove(node);
}

/// Pure interactive preflight policy for delete eligibility.
bool canDelete(NodeSnapshot node) {
  return _canDeleteFlag(isDeletable: node.isDeletable);
}

bool canDeleteSceneNode(SceneNode node) {
  return _canDeleteFlag(isDeletable: node.isDeletable);
}

bool canSelectSceneNode(SceneNode node) {
  return _canSelectFlags(
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
  );
}

bool canPreviewMoveSceneNode(SceneNode node) {
  return canSelectSceneNode(node) &&
      _canTransformFlags(
        isTransformable: node.isTransformable,
        isLocked: node.isLocked,
      );
}

List<NodeSnapshot> selectedNodesInSnapshotOrder({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
  required bool Function(NodeSnapshot node) predicate,
}) {
  if (selected.isEmpty) return const <NodeSnapshot>[];

  final nodes = <NodeSnapshot>[];
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (!selected.contains(node.id)) continue;
      if (!predicate(node)) continue;
      nodes.add(node);
    }
  }
  return nodes;
}

List<NodeSnapshot> selectedTransformableNodesInSnapshotOrder({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
}) {
  return selectedNodesInSnapshotOrder(
    snapshot: snapshot,
    selected: selected,
    predicate: canTransform,
  );
}

List<NodeSnapshot> selectedPreviewMovableNodesInSnapshotOrder({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
}) {
  return selectedNodesInSnapshotOrder(
    snapshot: snapshot,
    selected: selected,
    predicate: canPreviewMove,
  );
}

List<NodeSnapshot> selectedCommitMovableNodesInSnapshotOrder({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
}) {
  return selectedNodesInSnapshotOrder(
    snapshot: snapshot,
    selected: selected,
    predicate: canCommitMove,
  );
}

List<NodeId> deletableSelectedNodeIdsInSnapshot({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
}) {
  if (selected.isEmpty) return const <NodeId>[];

  final ids = <NodeId>[];
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (!selected.contains(node.id)) continue;
      if (!canDelete(node)) continue;
      ids.add(node.id);
    }
  }
  return ids;
}

Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> nodes) {
  Rect? bounds;
  for (final nodeSnapshot in nodes) {
    final boundsWorld = _snapshotBoundsWorld(nodeSnapshot);
    bounds = bounds == null ? boundsWorld : bounds.expandToInclude(boundsWorld);
  }
  return bounds?.center ?? Offset.zero;
}

Rect _snapshotBoundsWorld(NodeSnapshot node) {
  final localBounds = switch (node) {
    ImageNodeSnapshot(:final size) => centeredRectLocalBounds(size),
    TextNodeSnapshot() => _textSnapshotLocalBounds(node),
    RectNodeSnapshot(:final size, :final strokeColor, :final strokeWidth) =>
      strokeAwareLocalBounds(
        baseBounds: centeredRectLocalBounds(size),
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      ),
    StrokeNodeSnapshot(:final points, :final thickness) => strokeLocalBounds(
      points: points,
      thickness: thickness,
    ),
    LineNodeSnapshot(:final start, :final end, :final thickness) =>
      lineLocalBounds(start: start, end: end, thickness: thickness),
    PathNodeSnapshot(
      :final svgPathData,
      :final fillRule,
      :final strokeColor,
      :final strokeWidth,
    ) =>
      strokeAwareLocalBounds(
        baseBounds:
            buildCenteredSvgPathGeometry(
              svgPathData,
              fillType: _toPathFillType(fillRule),
            )?.localBounds ??
            Rect.zero,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      ),
  };
  return node.transform.applyToRect(localBounds);
}

Rect _textSnapshotLocalBounds(TextNodeSnapshot node) {
  final measuredSize = TextLayoutRequest(
    text: node.text,
    color: node.color,
    fontSize: node.fontSize,
    isBold: node.isBold,
    isItalic: node.isItalic,
    isUnderline: node.isUnderline,
    textAlign: node.align,
    fontFamily: node.fontFamily,
    lineHeight: node.lineHeight,
    maxWidth: node.maxWidth,
  ).measure();
  return centeredRectLocalBounds(measuredSize);
}

PathFillType _toPathFillType(PathFillRule rule) {
  return rule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}

bool _canSelectFlags({required bool isVisible, required bool isSelectable}) {
  if (!isVisible) return false;
  if (!isSelectable) return false;
  return true;
}

bool _canTransformFlags({
  required bool isTransformable,
  required bool isLocked,
}) {
  if (!isTransformable) return false;
  if (isLocked) return false;
  return true;
}

bool _canDeleteFlag({required bool isDeletable}) {
  return isDeletable;
}

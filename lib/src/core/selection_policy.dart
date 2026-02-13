import 'dart:ui';

import 'nodes.dart';
import 'scene.dart';

/// Returns whether [node] is interactive for selection in content layer.
bool isNodeInteractiveForSelection(
  SceneNode node, {
  required bool onlySelectable,
}) {
  if (!node.isVisible) return false;
  if (onlySelectable && !node.isSelectable) return false;
  return true;
}

/// Returns whether [node] can be deleted from content layer.
bool isNodeDeletableInLayer(SceneNode node) {
  return node.isDeletable;
}

/// Returns selected transformable nodes in scene order (layer order, then node
/// order) for stable commands and queries.
List<SceneNode> selectedTransformableNodesInSceneOrder(
  Scene scene,
  Set<NodeId> selectedNodeIds,
) {
  if (selectedNodeIds.isEmpty) return const <SceneNode>[];

  final nodes = <SceneNode>[];
  for (final layer in scene.layers) {
    for (final node in layer.nodes) {
      if (!selectedNodeIds.contains(node.id)) continue;
      if (!node.isTransformable) continue;
      nodes.add(node);
    }
  }
  return nodes;
}

/// Computes axis-aligned world bounds for [nodes].
Rect? boundsWorldForNodes(Iterable<SceneNode> nodes) {
  Rect? bounds;
  for (final node in nodes) {
    final nodeBounds = node.boundsWorld;
    bounds = bounds == null ? nodeBounds : bounds.expandToInclude(nodeBounds);
  }
  return bounds;
}

/// Returns the center of [boundsWorldForNodes] or [Offset.zero] if empty.
Offset centerWorldForNodes(Iterable<SceneNode> nodes) =>
    boundsWorldForNodes(nodes)?.center ?? Offset.zero;

import 'dart:ui';

import '../../model/document.dart';
import '../../contract/snapshot.dart';

List<NodeSnapshot> selectedTransformableNodesInSnapshotOrder({
  required SceneSnapshot snapshot,
  required Set<NodeId> selected,
}) {
  if (selected.isEmpty) return const <NodeSnapshot>[];

  final nodes = <NodeSnapshot>[];
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (!selected.contains(node.id)) continue;
      if (!node.isTransformable || node.isLocked) continue;
      nodes.add(node);
    }
  }
  return nodes;
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
      if (!node.isDeletable) continue;
      ids.add(node.id);
    }
  }
  return ids;
}

Offset centerWorldForNodeSnapshots(List<NodeSnapshot> nodes) {
  Rect? bounds;
  for (final nodeSnapshot in nodes) {
    final boundsWorld = txnNodeFromSnapshot(nodeSnapshot).boundsWorld;
    bounds = bounds == null ? boundsWorld : bounds.expandToInclude(boundsWorld);
  }
  return bounds?.center ?? Offset.zero;
}

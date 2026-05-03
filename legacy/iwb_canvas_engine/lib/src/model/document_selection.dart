import 'dart:ui';

import '../contract/ids.dart' show LayerId;
import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/scene_node_locator.dart';
import 'document_locator.dart' as locator;

Set<NodeId> txnNormalizeSelection({
  required Set<NodeId> rawSelection,
  required Scene scene,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
  Map<LayerId, int>? layerIndexById,
}) {
  return <NodeId>{
    for (final id in rawSelection)
      if (txnIsSelectionCandidateId(
        scene: scene,
        nodeId: id,
        nodeLocator: nodeLocator,
        layerIndexById: layerIndexById,
      ))
        id,
  };
}

bool txnIsSelectionCandidateId({
  required Scene scene,
  required NodeId nodeId,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
  Map<LayerId, int>? layerIndexById,
}) {
  final found = nodeLocator == null
      ? locator.txnFindNodeById(scene, nodeId)
      : locator.txnFindNodeByLocator(
          scene: scene,
          nodeLocator: nodeLocator,
          layerIndexById:
              layerIndexById ?? locator.txnBuildLayerIndexById(scene),
          nodeId: nodeId,
        );
  if (found == null || found.layerIndex == -1) {
    return false;
  }
  return found.node.isVisible;
}

Set<NodeId> txnTranslateSelection({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Offset delta,
}) {
  if (delta == Offset.zero) {
    return const <NodeId>{};
  }

  final moved = <NodeId>{};
  for (final layer in scene.layers) {
    for (final node in layer.nodes) {
      if (!selectedNodeIds.contains(node.id)) {
        continue;
      }
      if (node.isLocked || !node.isTransformable) {
        continue;
      }
      node.position = node.position + delta;
      moved.add(node.id);
    }
  }
  return moved;
}

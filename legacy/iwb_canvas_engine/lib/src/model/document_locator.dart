import '../contract/ids.dart' show LayerId;
import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/scene_node_locator.dart';

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeById(
  Scene scene,
  NodeId id,
) {
  final backgroundMatch = _txnFindNodeInLayerNodes(
    nodes: scene.backgroundLayer?.nodes,
    id: id,
    layerIndex: -1,
  );
  if (backgroundMatch != null) {
    return backgroundMatch;
  }
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final match = _txnFindNodeInLayerNodes(
      nodes: scene.layers[layerIndex].nodes,
      id: id,
      layerIndex: layerIndex,
    );
    if (match != null) {
      return match;
    }
  }
  return null;
}

Map<NodeId, NodeLocatorEntry> txnBuildNodeLocator(Scene scene) {
  final locator = <NodeId, NodeLocatorEntry>{};
  txnWriteLayerNodeLocations(
    locator: locator,
    nodes: scene.backgroundLayer?.nodes,
    contentLayerId: null,
  );
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    txnWriteLayerNodeLocations(
      locator: locator,
      nodes: scene.layers[layerIndex].nodes,
      contentLayerId: scene.layers[layerIndex].id,
    );
  }
  return locator;
}

Map<LayerId, int> txnBuildLayerIndexById(Scene scene) {
  return <LayerId, int>{
    for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++)
      scene.layers[layerIndex].id: layerIndex,
  };
}

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeByLocator({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  Map<LayerId, int>? layerIndexById,
  required NodeId nodeId,
}) {
  final entry = nodeLocator[nodeId];
  if (entry == null) {
    return null;
  }
  final resolved = txnResolveNodeLocatorEntry(
    scene: scene,
    entry: entry,
    layerIndexById: layerIndexById ?? txnBuildLayerIndexById(scene),
  );
  if (resolved == null) {
    return null;
  }
  final nodes = resolved.nodes;
  if (nodes == null) {
    return null;
  }
  final nodeIndex = entry.nodeIndex;
  if (nodeIndex < 0 || nodeIndex >= nodes.length) {
    return null;
  }
  final node = nodes[nodeIndex];
  if (node.id != nodeId) {
    return null;
  }
  return (node: node, layerIndex: resolved.layerIndex, nodeIndex: nodeIndex);
}

({SceneNode node, int layerIndex, int nodeIndex})? _txnFindNodeInLayerNodes({
  required List<SceneNode>? nodes,
  required NodeId id,
  required int layerIndex,
}) {
  if (nodes == null) {
    return null;
  }
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    final node = nodes[nodeIndex];
    if (node.id == id) {
      return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
    }
  }
  return null;
}

void txnWriteLayerNodeLocations({
  required Map<NodeId, NodeLocatorEntry> locator,
  required List<SceneNode>? nodes,
  required LayerId? contentLayerId,
  int startNodeIndex = 0,
}) {
  if (nodes == null) {
    return;
  }
  for (var nodeIndex = startNodeIndex; nodeIndex < nodes.length; nodeIndex++) {
    locator[nodes[nodeIndex].id] = nodeLocatorEntry(
      contentLayerId: contentLayerId,
      nodeIndex: nodeIndex,
    );
  }
}

({List<SceneNode>? nodes, int layerIndex})? txnResolveNodeLocatorEntry({
  required Scene scene,
  required NodeLocatorEntry entry,
  required Map<LayerId, int> layerIndexById,
}) {
  final contentLayerId = entry.contentLayerId;
  if (contentLayerId == null) {
    return (nodes: scene.backgroundLayer?.nodes, layerIndex: -1);
  }
  final layerIndex = layerIndexById[contentLayerId];
  if (layerIndex == null) {
    return null;
  }
  if (layerIndex < 0 || layerIndex >= scene.layers.length) {
    return null;
  }
  final layer = scene.layers[layerIndex];
  if (layer.id != contentLayerId) {
    return null;
  }
  return (nodes: layer.nodes, layerIndex: layerIndex);
}

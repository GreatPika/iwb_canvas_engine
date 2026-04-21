import '../core/nodes.dart';
import '../core/scene.dart';

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

Map<NodeId, ({int layerIndex, int nodeIndex})> txnBuildNodeLocator(
  Scene scene,
) {
  final locator = <NodeId, ({int layerIndex, int nodeIndex})>{};
  txnWriteLayerNodeLocations(
    locator: locator,
    nodes: scene.backgroundLayer?.nodes,
    layerIndex: -1,
  );
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    txnWriteLayerNodeLocations(
      locator: locator,
      nodes: scene.layers[layerIndex].nodes,
      layerIndex: layerIndex,
    );
  }
  return locator;
}

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeByLocator({
  required Scene scene,
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
  required NodeId nodeId,
}) {
  final entry = nodeLocator[nodeId];
  if (entry == null) {
    return null;
  }
  final nodes = txnResolveLayerNodes(
    scene: scene,
    layerIndex: entry.layerIndex,
  );
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
  return (node: node, layerIndex: entry.layerIndex, nodeIndex: nodeIndex);
}

void txnShiftNodeLocatorLayersFrom({
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
  required int startLayerIndex,
}) {
  for (final entry in nodeLocator.entries.toList(growable: false)) {
    final location = entry.value;
    if (location.layerIndex == -1 || location.layerIndex < startLayerIndex) {
      continue;
    }
    nodeLocator[entry.key] = (
      layerIndex: location.layerIndex + 1,
      nodeIndex: location.nodeIndex,
    );
  }
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
  required Map<NodeId, ({int layerIndex, int nodeIndex})> locator,
  required List<SceneNode>? nodes,
  required int layerIndex,
  int startNodeIndex = 0,
}) {
  if (nodes == null) {
    return;
  }
  for (var nodeIndex = startNodeIndex; nodeIndex < nodes.length; nodeIndex++) {
    locator[nodes[nodeIndex].id] = (
      layerIndex: layerIndex,
      nodeIndex: nodeIndex,
    );
  }
}

List<SceneNode>? txnResolveLayerNodes({
  required Scene scene,
  required int layerIndex,
}) {
  if (layerIndex == -1) {
    return scene.backgroundLayer?.nodes;
  }
  if (layerIndex < 0 || layerIndex >= scene.layers.length) {
    return null;
  }
  return scene.layers[layerIndex].nodes;
}

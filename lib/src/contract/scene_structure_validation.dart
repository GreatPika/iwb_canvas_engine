import 'ids.dart';
import 'internal/snapshot_backing.dart';
import 'scene_contract_limits.dart';
import 'scene_data_exception.dart';

void sceneRequireContentLayerLimit(int layerCount) {
  if (layerCount <= kMaxContentLayersPerScene) {
    return;
  }
  throw SceneDataException.maxItems(
    path: 'layers',
    maxItems: kMaxContentLayersPerScene,
    source: layerCount,
  );
}

int sceneConsumeNodeBudget({
  required int totalNodeCount,
  required String path,
}) {
  final nextTotalNodeCount = totalNodeCount + 1;
  if (nextTotalNodeCount <= kMaxNodesPerScene) {
    return nextTotalNodeCount;
  }
  throw SceneDataException.maxNodes(
    path: path,
    maxNodes: kMaxNodesPerScene,
    source: nextTotalNodeCount,
  );
}

void sceneValidateSceneStructure<TLayer, TNode>({
  required List<TLayer> layers,
  required List<TNode> backgroundNodes,
  required LayerId Function(TLayer layer) layerIdOf,
  required List<TNode> Function(TLayer layer) nodesOf,
  required NodeId Function(TNode node) nodeIdOf,
}) {
  final seenNodeIds = <NodeId>{};
  final seenLayerIds = <LayerId>{};
  var totalNodeCount = 0;

  sceneRequireContentLayerLimit(layers.length);
  totalNodeCount = _validateLayerNodes(
    backgroundNodes,
    nodesPath: 'backgroundLayer.nodes',
    totalNodeCount: totalNodeCount,
    seenNodeIds: seenNodeIds,
    nodeIdOf: nodeIdOf,
  );
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    final layerId = layerIdOf(layer);
    if (!seenLayerIds.add(layerId)) {
      throw SceneDataException.duplicateLayerId(
        path: 'layers[$layerIndex].id',
        layerId: layerId,
      );
    }
    totalNodeCount = _validateLayerNodes(
      nodesOf(layer),
      nodesPath: 'layers[$layerIndex].nodes',
      totalNodeCount: totalNodeCount,
      seenNodeIds: seenNodeIds,
      nodeIdOf: nodeIdOf,
    );
  }
}

void sceneValidateSceneSnapshotBackingStructure(SceneSnapshotBacking backing) {
  sceneValidateSceneStructure<ContentLayerSnapshotBacking, NodeSnapshotBacking>(
    layers: backing.layers,
    backgroundNodes: backing.backgroundLayer.nodes,
    layerIdOf: (layer) => layer.id,
    nodesOf: (layer) => layer.nodes,
    nodeIdOf: (node) => node.id,
  );
}

int _validateLayerNodes<TNode>(
  List<TNode> nodes, {
  required String nodesPath,
  required int totalNodeCount,
  required Set<NodeId> seenNodeIds,
  required NodeId Function(TNode node) nodeIdOf,
}) {
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    totalNodeCount = sceneConsumeNodeBudget(
      totalNodeCount: totalNodeCount,
      path: nodesPath,
    );
    final nodeId = nodeIdOf(nodes[nodeIndex]);
    if (!seenNodeIds.add(nodeId)) {
      throw SceneDataException.duplicateNodeId(
        path: '$nodesPath[$nodeIndex].id',
        nodeId: nodeId,
      );
    }
  }
  return totalNodeCount;
}
